import XCTest
@testable import JackpotForms
import JackpotNetworking

final class FormSubmitEndpointTests: XCTestCase {

    private let cron = URL(string: "https://config.jpc.africa/cron")!

    func testSubmitURLMatchesProduction() throws {
        let request = try FormSubmitRequest(Self.sample).urlRequest(in: .cron(baseURL: cron))
        XCTAssertEqual(request.url?.absoluteString, "https://config.jpc.africa/cron/forms/submit")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(request.url?.query, "submit has no api-version query item")
    }

    func testCronBaseURLIsDerivedFromTheCRMBase() {
        XCTAssertEqual(
            APIEnvironment.cronBaseURL(fromCRM: URL(string: "https://config.jpc.africa/crm")!).absoluteString,
            "https://config.jpc.africa/cron"
        )
        XCTAssertEqual(
            APIEnvironment.cronBaseURL(fromCRM: cron).absoluteString,
            "https://config.jpc.africa/cron"
        )
        XCTAssertEqual(
            APIEnvironment.cronBaseURL(fromCRM: URL(string: "https://config.jpc.africa")!).absoluteString,
            "https://config.jpc.africa/cron"
        )
    }

    func testFetchByNameMatchesProductionBuildFormURL() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: .registration)
            .urlRequest(in: .cron(baseURL: cron))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://config.jpc.africa/cron/forms/jackpotcity/JZA/registration?api-version=2.0")
    }

    func testSubmitBodyUsesSnakeCaseKeysAndTypedFields() throws {
        let data = try FormSubmitBody.encoder.encode(FormSubmitBody(Self.sample))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["form_id"] as? String, "1052")
        XCTAssertEqual(json["form_name"] as? String, "registration")
        XCTAssertEqual(json["submitted_at"] as? String, "1970-01-01T00:00:00Z")
        let fields = try XCTUnwrap(json["fields"] as? [String: Any])
        XCTAssertEqual(fields["username"] as? String, "849134302")
        XCTAssertEqual(fields["terms"] as? Bool, true)
        XCTAssertTrue(fields["referralCode"] is NSNull)
        XCTAssertNil(json["metadata"] as? [String: String])
    }

    func testEmptyBodyIsAnAcceptedSubmit() {
        if case .accepted(let result) = FormSubmitParser.parse(Data()) {
            XCTAssertNil(result.accountId)
        } else {
            XCTFail("empty body should be success")
        }
    }

    func testEnvelopeSuccessCarriesAccountAndToken() throws {
        let data = Data("""
        {"data":{"accountId":"32212b00-54d0-449e-877a-f712f0976823","message":"User Created Successfully.","status":"Success.","partialRegistrationStatus":1,"complianceResponse":{"complianceStatus":512,"requiredComplianceStatus":1,"isValidId":true,"message":"Auto FICA Verification Failed","accessToken":"act-jwt-x"}},"isSuccessful":true,"error":null,"metadata":null,"httpStatusCode":200}
        """.utf8)
        guard case .accepted(let result) = FormSubmitParser.parse(data) else {
            return XCTFail("expected accepted")
        }
        XCTAssertEqual(result.accountId, "32212b00-54d0-449e-877a-f712f0976823")
        XCTAssertEqual(result.message, "User Created Successfully.")
        XCTAssertEqual(result.partialRegistrationStatus, 1)
        XCTAssertTrue(result.isPartial)
        XCTAssertEqual(result.compliance?.accessToken, "act-jwt-x")
        XCTAssertEqual(result.compliance?.isValidId, true)
    }

    func testHTTP200WithIsSuccessfulFalseIsARejection() {
        let data = Data("""
        {"data":null,"isSuccessful":false,"error":{"code":153008,"displayCode":153008,"message":"An Error Occurred.","remediation":null,"additionalInformation":null,"properties":null},"metadata":null,"httpStatusCode":200}
        """.utf8)
        guard case .rejected(let error) = FormSubmitParser.parse(data) else {
            return XCTFail("HTTP 200 with isSuccessful false must not be treated as success")
        }
        XCTAssertEqual(error?.code, 153008)
        XCTAssertEqual(error?.message, "An Error Occurred.")
    }

    /// A gateway page served with status 200, or JSON of some other shape, is not a
    /// registered account.
    func testABodyThatIsNotTheEnvelopeIsARejection() {
        for body in ["<html>Access denied</html>", "{}", "[]", #"{"httpStatusCode":200}"#] {
            guard case .rejected(let error) = FormSubmitParser.parse(Data(body.utf8)) else {
                return XCTFail("\(body) must not read as success")
            }
            XCTAssertNil(error, body)
        }
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

final class FormRepositoryOperationTests: XCTestCase {

    func testStubServesTheBundledForm() async throws {
        let repo = StubFormRepository(forms: BundledForms.all, delay: 0)
        let form = try await repo.form(named: .registration)
        XCTAssertEqual(form.id, 1052)
    }

    func testStubReportsAnUnknownFormAsNotFound() async {
        let repo = StubFormRepository(forms: BundledForms.all, delay: 0)
        do {
            _ = try await repo.form(named: FormName("deposit"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError, .notFound(FormName("deposit")))
        }
    }

    func testStubSubmitSucceeds() async throws {
        let repo = StubFormRepository(forms: [:], delay: 0)
        let submission = FormSubmission(formCodeName: .registration, values: [:], formId: "1052")
        let submitted = try await repo.submitForm(submission)
        XCTAssertNil(submitted.accountId)
    }

    func testRemoteSubmitPostsToCronAndReadsTheEnvelope() async throws {
        let client = ScriptedApiClient(data: Data(#"{"isSuccessful":true,"data":{"accountId":"abc"}}"#.utf8))
        let repo = RemoteFormRepository(apiClient: client)
        let result = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:], formId: "1"))
        XCTAssertEqual(result.accountId, "abc")
        XCTAssertEqual(client.lastPath, "forms/submit")
    }

    func testRemoteSubmitThrowsOnLogicalFailureDespiteHTTP200() async {
        let body = #"{"isSuccessful":false,"error":{"code":153008,"message":"An Error Occurred."}}"#
        let repo = RemoteFormRepository(apiClient: ScriptedApiClient(data: Data(body.utf8)))
        do {
            _ = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:]))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError, .server(message: "An Error Occurred."))
        }
    }

    func testRemoteSubmitLocalisesErrorCodes() async {
        let localizer = ClosureLocalizer({ _ in nil }, errorCode: { code in
            code == 153008 ? "The ID or Passport Number Provided Is Invalid" : nil
        })
        let body = #"{"isSuccessful":false,"error":{"code":153008,"message":"An Error Occurred."}}"#
        let repo = RemoteFormRepository(
            apiClient: ScriptedApiClient(data: Data(body.utf8)),
            localizer: localizer
        )
        do {
            _ = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:]))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError,
                           .server(message: "The ID or Passport Number Provided Is Invalid"))
        }
    }

    func testRemoteSubmitMapsTransportErrors() async {
        let repo = RemoteFormRepository(
            apiClient: ScriptedApiClient(error: APIError.transport(.notConnectedToInternet))
        )
        do {
            _ = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:]))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError, .offline)
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

    func requestData(_ endpoint: some APIEndpoint) async throws -> Data {
        lastPath = endpoint.path
        if let error { throw error }
        return data
    }

    func requestConditional(_ endpoint: some APIEndpoint,
                           validators: HTTPValidators?) async throws -> ConditionalResponse {
        throw APIError.unexpectedStatus(404, nil)
    }
}
