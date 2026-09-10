import XCTest
@testable import JackpotForms
import JackpotNetworking

final class FormEndpointTests: XCTestCase {
    private let host = APIEnvironment(baseURL: URL(string: "https://config.jpc.africa")!)

    func testFetchByNameMatchesProductionBuildFormURL() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: .registration).urlRequest(in: host)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://config.jpc.africa/cron/forms/jackpotcity/JZA/registration?api-version=2.0")
    }

    func testServerAuthoredFormNameLandsInThePath() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: FormName("deposit")).urlRequest(in: host)
        XCTAssertTrue(request.url?.path.hasSuffix("/deposit") == true)
    }

    func testSubmitURLMatchesProduction() throws {
        let request = try FormSubmitRequest(Self.sample).urlRequest(in: host)
        XCTAssertEqual(request.url?.absoluteString, "https://config.jpc.africa/cron/forms/submit")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(request.url?.query, "submit has no api-version query item")
    }

    func testSubmitBodyUsesSnakeCaseKeysAndTypedFields() throws {
        let data = try FormSubmitRequest(Self.sample).bodyData
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["form_id"] as? String, "1052")
        XCTAssertEqual(json["form_name"] as? String, "registration")
        XCTAssertEqual(json["submitted_at"] as? String, "1970-01-01T00:00:00Z")
        let fields = try XCTUnwrap(json["fields"] as? [String: Any])
        XCTAssertEqual(fields["username"] as? String, "849134302")
        XCTAssertEqual(fields["terms"] as? Bool, true)
        XCTAssertTrue(fields["referralCode"] is NSNull)
        XCTAssertEqual(Set(json.keys), ["form_id", "form_name", "submitted_at", "fields"])
    }

    func testSubmitBodyEncodesRecaptchaBesideFields() throws {
        let submission = FormSubmission(
            formCodeName: .registration,
            values: ["username": .text("849134302")],
            recaptcha: "tok-v3",
            formId: "1052",
            submittedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try FormSubmitRequest(submission).bodyData
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["recaptcha"] as? String, "tok-v3")
        XCTAssertEqual(Set(json.keys), ["form_id", "form_name", "submitted_at", "fields", "recaptcha"])
    }

    private static let sample = FormSubmission(
        formCodeName: .registration,
        values: [
            "username": .text("849134302"),
            "terms": .bool(true),
            "referralCode": .empty,
        ],
        formId: "1052",
        submittedAt: Date(timeIntervalSince1970: 0)
    )
}

final class RemoteFormRepositoryTests: XCTestCase {
    private let submission = FormSubmission(formCodeName: .registration, values: [:], formId: "1")

    private func submit(_ body: String, translate: @escaping @Sendable (String) -> String = { $0 }) async throws -> FormSubmitResult {
        try await RemoteFormRepository(apiClient: ScriptedApiClient(data: Data(body.utf8)), translate: translate)
            .submitForm(submission)
    }

    func testRemoteSubmitPostsToCronAndReadsTheEnvelope() async throws {
        let client = ScriptedApiClient(data: Data(#"{"isSuccessful":true,"data":{"accountId":"abc"}}"#.utf8))
        let result = try await RemoteFormRepository(apiClient: client).submitForm(submission)
        XCTAssertEqual(result.accountId, "abc")
        XCTAssertEqual(client.lastPath, "cron/forms/submit")
    }

    /// An empty 2xx is taken as accepted.
    func testEmptyBodyIsAnAcceptedSubmit() async throws {
        let result = try await submit("")
        XCTAssertNil(result.accountId)
    }

    func testEnvelopeSuccessCarriesAccountTokenAndPartialStatus() async throws {
        let result = try await submit("""
        {"data":{"accountId":"32212b00-54d0-449e-877a-f712f0976823","message":"User Created Successfully.","status":"Success.","partialRegistrationStatus":1,"complianceResponse":{"complianceStatus":512,"requiredComplianceStatus":1,"isValidId":true,"message":"Auto FICA Verification Failed","accessToken":"act-jwt-x"}},"isSuccessful":true,"error":null,"metadata":null,"httpStatusCode":200}
        """)
        XCTAssertEqual(result.accountId, "32212b00-54d0-449e-877a-f712f0976823")
        XCTAssertEqual(result.message, "User Created Successfully.")
        XCTAssertTrue(result.isPartial)
        XCTAssertEqual(result.accessToken, "act-jwt-x")
    }

    func testHTTP200WithIsSuccessfulFalseIsARejection() async {
        do {
            _ = try await submit(#"{"data":null,"isSuccessful":false,"error":{"code":153008,"displayCode":153008,"message":"An Error Occurred.","remediation":null},"httpStatusCode":200}"#)
            XCTFail("HTTP 200 with isSuccessful false must not be treated as success")
        } catch {
            XCTAssertEqual(error as? FormError, .server(message: "An Error Occurred."))
        }
    }

    /// A gateway page served with status 200, or JSON of some other shape, is not a registered account.
    func testABodyThatIsNotTheEnvelopeIsARejection() async {
        for body in ["<html>Access denied</html>", "{}", "[]", #"{"httpStatusCode":200}"#, #"{"data":{"accountId":"abc"}}"#] {
            do {
                _ = try await submit(body)
                XCTFail("\(body) must not read as success")
            } catch {
                XCTAssertEqual(error as? FormError, .server(message: "We couldn't submit the form. Please try again."), body)
            }
        }
    }

    /// `displayCode` stands in when `code` is absent, and both are translation keys.
    func testRemoteSubmitLocalisesErrorCodes() async {
        do {
            _ = try await submit(#"{"isSuccessful":false,"error":{"displayCode":153008,"message":"An Error Occurred."}}"#) {
                $0 == "jpc-reg-error.153008" ? "The ID or Passport Number Provided Is Invalid" : $0
            }
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormError, .server(message: "The ID or Passport Number Provided Is Invalid"))
        }
    }

    func testRemoteSubmitMapsTransportErrors() async {
        let repo = RemoteFormRepository(apiClient: ScriptedApiClient(error: APIError.transport(.notConnectedToInternet)))
        do {
            _ = try await repo.submitForm(submission)
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormError, .offline)
        }
    }
}

/// Records the last endpoint and returns scripted bytes. Fetch methods are unused in submit tests.
final class ScriptedApiClient: ApiClient, @unchecked Sendable {
    var data: Data
    var error: (any Error)?
    private(set) var lastPath: String?

    init(data: Data = Data(), error: (any Error)? = nil) {
        self.data = data
        self.error = error
    }

    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response {
        throw APIError.unexpectedStatus(404, nil)
    }

    func request(_ endpoint: some APIEndpoint) async throws {
        if let error { throw error }
    }

    func data(for endpoint: some APIEndpoint) async throws -> Data {
        lastPath = endpoint.path
        if let error { throw error }
        return data
    }

    func revalidate(_ endpoint: some APIEndpoint,
                    validators: HTTPValidators?) async throws -> ConditionalResponse {
        throw APIError.unexpectedStatus(404, nil)
    }
}
