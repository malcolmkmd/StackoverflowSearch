import XCTest
@testable import JackpotNetworking

final class APIEndpointTests: XCTestCase {

    func testBuildsURLFromEnvironmentAndPath() throws {
        let request = try WidgetRequest().urlRequest(in: .test)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.example.com/v1/widgets/42?api-version=2.0")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    /// Environment query items come first, then the endpoint's own — so an endpoint can
    /// never accidentally drop the API version.
    func testMergesEnvironmentAndEndpointQueryItems() throws {
        let request = try SearchRequest(term: "swift").urlRequest(in: .test)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.map(\.name), ["api-version", "q"])
        XCTAssertEqual(components.queryItems?.last?.value, "swift")
    }

    func testLeadingSlashInPathDoesNotBreakTheURL() throws {
        struct Slashed: APIEndpoint { var path: String { "/widgets" } }
        let request = try Slashed().urlRequest(in: .test)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.example.com/v1/widgets?api-version=2.0")
    }

    func testFormBodyIsPercentEncodedWithTheRightContentType() throws {
        let request = try CreateWidgetRequest(name: "a b&c").urlRequest(in: .test)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(body, "name=a%20b%26c")
    }

    func testJSONBodySetsContentType() throws {
        struct JSONPost: APIEndpoint {
            var path: String { "x" }
            var method: HTTPMethod { .POST }
            var body: RequestBody? { .json(Data(#"{"a":1}"#.utf8)) }
        }
        let request = try JSONPost().urlRequest(in: .test)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testDefaultsAreSaneWithoutOverrides() {
        let endpoint = WidgetRequest()
        XCTAssertEqual(endpoint.method, .GET)
        XCTAssertTrue(endpoint.queryItems.isEmpty)
        XCTAssertNil(endpoint.body)
        XCTAssertTrue(endpoint.requiresAuth)
        XCTAssertTrue(endpoint.isIdempotent)          // derived from .GET
    }

    func testPostIsNotIdempotentByDefault() {
        XCTAssertFalse(CreateWidgetRequest(name: "x").isIdempotent)
    }
}
