import XCTest
@testable import JackpotNetworking

final class RemoteApiClientTests: XCTestCase {

    private func client(_ http: MockHTTPClient,
                        interceptors: [any RequestInterceptor] = []) -> RemoteApiClient {
        RemoteApiClient(environment: .test, httpClient: http, interceptors: interceptors)
    }

    // MARK: Success

    func testDecodesA200() async throws {
        let http = MockHTTPClient(.ok(#"{"id":42,"name":"Sprocket"}"#))
        let widget: Widget = try await client(http).request(WidgetRequest())
        XCTAssertEqual(widget, Widget(id: 42, name: "Sprocket"))
        await http.assertRequests(1)
    }

    func testEmptyBodyRequestIgnoresThePayload() async throws {
        let http = MockHTTPClient(.status(204))
        try await client(http).request(WidgetRequest())
        await http.assertRequests(1)
    }

    // MARK: The documented contract — 200, 400, 401, 500

    func test400CarriesTheServersMessage() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":1042,"message":"Mobile number already registered"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            guard case .badRequest(let problem) = error as? APIError else {
                return XCTFail("expected .badRequest, got \(error)")
            }
            XCTAssertEqual(problem, APIProblem(code: 1042, message: "Mobile number already registered"))
            XCTAssertEqual((error as? APIError)?.serverMessage, "Mobile number already registered")
        }
    }

    /// `{"code": 0, ...}` is the shape the API actually sends. An earlier `code: String?`
    /// meant this decoded to nil and every error message came back empty — silently,
    /// because problem decoding is `try?` by design.
    func testNumericZeroCodeDecodes() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":0,"message":"Error message"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual((error as? APIError)?.problem, APIProblem(code: 0, message: "Error message"))
        }
    }

    func testStringCodeAlsoDecodes() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":"7","message":"x"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual((error as? APIError)?.problem?.code, 7)
        }
    }

    /// A gateway returning HTML must not throw a decoding error on the way to reporting
    /// the status.
    func testNonJSONErrorBodyStillReportsTheStatus() async {
        let http = MockHTTPClient(.status(400, json: "<html>502 Bad Gateway</html>"))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .badRequest(nil))
            XCTAssertNil((error as? APIError)?.serverMessage)
        }
    }

    func test500CarriesTheProblemAfterRetrying() async {
        let http = MockHTTPClient([.status(500), .status(500, json: #"{"code":9,"message":"Down"}"#)])
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .server(APIProblem(code: 9, message: "Down")))
        }
        await http.assertRequests(2)
    }

    func test500DoesNotRetryANonIdempotentRequest() async {
        let http = MockHTTPClient([.status(500), .ok(#"{"id":1,"name":"x"}"#)])
        await AssertThrows(try await client(http).request(CreateWidgetRequest(name: "x")) as Widget) { error in
            XCTAssertEqual(error as? APIError, .server(nil))
        }
        await http.assertRequests(1)
    }

    // MARK: Outside the contract — infrastructure, not the API

    func test404IsReportedAsUnexpectedRatherThanFlattenedIntoServer() async {
        let http = MockHTTPClient(.status(404))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(404, nil))
        }
        await http.assertRequests(1)   // a 404 is not retried
    }

    func testGatewayErrorsRetryOnceThenReportTheirRealStatus() async {
        let http = MockHTTPClient([.status(503), .status(503)])
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(503, nil))
        }
        await http.assertRequests(2)
    }

    // MARK: Transport and decoding

    func testMalformedJSONSurfacesAsDecodingWithTheTypeName() async {
        let http = MockHTTPClient(.ok(#"{"id":"not-an-int"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            guard case .decoding(let message) = error as? APIError else {
                return XCTFail("expected .decoding, got \(error)")
            }
            // DecodingError.localizedDescription is "The data couldn't be read" — useless.
            XCTAssertTrue(message.contains("Widget"), message)
        }
    }

    func testOfflineMapsToTransportAndIsFlaggedOffline() async {
        let http = MockHTTPClient(.failure(URLError(.notConnectedToInternet)))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .transport(.notConnectedToInternet))
            XCTAssertTrue((error as? APIError)?.isOffline == true)
        }
    }

    /// URLSession throws `URLError.cancelled`, not `CancellationError`, when a task is
    /// cancelled mid-flight. Miss this and cancelled loads surface to users as failures.
    func testURLErrorCancelledMapsToCancelled() async {
        let http = MockHTTPClient(.failure(URLError(.cancelled)))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .cancelled)
        }
    }

    // MARK: Auth retry

    func test401RetriesOnceWithTheRefreshedToken() async throws {
        let http = MockHTTPClient([.status(401), .ok(#"{"id":1,"name":"ok"}"#)])
        let interceptor = StubAuthInterceptor(refreshedToken: "new-token")
        let widget: Widget = try await client(http, interceptors: [interceptor]).request(WidgetRequest())

        XCTAssertEqual(widget.name, "ok")
        await http.assertRequests(2)
        let retried = await http.requests[1]
        XCTAssertEqual(retried.value(forHTTPHeaderField: "Authorization"), "Bearer new-token")
    }

    /// The retry budget is a call-shape parameter, not stored state — so a second 401
    /// can never loop.
    func testSecond401GivesUpAsUnauthorized() async {
        let http = MockHTTPClient([.status(401), .status(401), .status(401)])
        let interceptor = StubAuthInterceptor(refreshedToken: "new-token")
        await AssertThrows(try await client(http, interceptors: [interceptor]).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unauthorized(nil))
        }
        await http.assertRequests(2)
    }

    func test401WithNoInterceptorFailsImmediately() async {
        let http = MockHTTPClient(.status(401))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unauthorized(nil))
        }
        await http.assertRequests(1)
    }

    func testBearerTokenIsAttachedButNotToAuthExemptEndpoints() async throws {
        struct LoginRequest: APIEndpoint {
            var path: String { "auth/login" }
            var method: HTTPMethod { .POST }
            var requiresAuth: Bool { false }
        }
        let http = MockHTTPClient([.ok(#"{"id":1,"name":"a"}"#), .ok(#"{"id":1,"name":"a"}"#)])
        let sut = client(http, interceptors: [BearerTokenInterceptor { "abc" }])

        _ = try await sut.request(WidgetRequest()) as Widget
        _ = try await sut.request(LoginRequest()) as Widget

        let widgetAuth = await http.requests[0].value(forHTTPHeaderField: "Authorization")
        let loginAuth  = await http.requests[1].value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(widgetAuth, "Bearer abc")
        XCTAssertNil(loginAuth, "a login request must never carry a bearer token")
    }

}

// MARK: - Helpers

private struct StubAuthInterceptor: RequestInterceptor {
    let refreshedToken: String

    func retry(_ request: URLRequest, for endpoint: any APIEndpoint,
               response: HTTPURLResponse, data: Data) async -> URLRequest? {
        guard response.statusCode == 401 else { return nil }
        var retry = request
        retry.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
        return retry
    }
}

private func AssertThrows<T>(_ expression: @autoclosure () async throws -> T,
                             file: StaticString = #filePath, line: UInt = #line,
                             _ verify: (any Error) -> Void) async {
    do {
        _ = try await expression()
        XCTFail("expected a thrown error", file: file, line: line)
    } catch {
        verify(error)
    }
}
