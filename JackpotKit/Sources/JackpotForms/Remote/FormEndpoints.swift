import Foundation
import JackpotNetworking

// Fetch, submit and app-data all live under `https://config.jpc.africa/cron`. Fetch carries
// `api-version=2.0` and submit carries none, so the version belongs on the request rather than
// on the environment.

extension APIEnvironment {
    /// The cron config service — `https://config.jpc.africa/cron`.
    static func cron(baseURL: URL) -> APIEnvironment {
        APIEnvironment(baseURL: baseURL)
    }

    /// `https://config.jpc.africa/crm` → `https://config.jpc.africa/cron`, because call sites
    /// historically passed a CRM base and production fetch is on cron.
    static func cronBaseURL(fromCRM url: URL) -> URL {
        switch url.lastPathComponent {
        case "crm":
            return url.deletingLastPathComponent().appendingPathComponent("cron")
        case "cron":
            return url
        default:
            return url.appendingPathComponent("cron")
        }
    }
}

/// `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`, matching production `buildFormURL`.
struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    var path: String { "forms/\(brand)/\(region)/\(formName.rawValue)" }
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "2.0")] }
}

/// `POST {cron}/forms/submit` — no `api-version` query item. Auth is not required, because
/// registration happens before login.
struct FormSubmitRequest: APIEndpoint {
    let bodyData: Data

    init(_ submission: FormSubmission) throws {
        self.bodyData = try FormSubmitBody.encoder.encode(FormSubmitBody(submission))
    }

    var path: String { "forms/submit" }
    var method: HTTPMethod { .POST }
    var body: RequestBody? { .json(bodyData) }
    var requiresAuth: Bool { false }
}

/// Wire shape of `FormSubmission`, so the domain type stays free of JSON key names.
struct FormSubmitBody: Encodable {
    let formId: String
    let formName: String
    let submittedAt: Date
    let fields: [String: FieldValue]
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case formName = "form_name"
        case submittedAt = "submitted_at"
        case fields, metadata
    }

    init(_ submission: FormSubmission) {
        formId = submission.formId
        formName = submission.formCodeName.rawValue
        submittedAt = submission.submittedAt
        fields = submission.values.mapValues(\.fieldValue)
        metadata = submission.metadata
    }

    /// ISO-8601 is an assumption — the production encoder wasn't visible.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

/// Untagged JSON value for a form field.
///
/// The custom `encode` is required: synthesized `Codable` would emit a tagged object
/// (`{"bool":true}`) instead of a bare JSON value.
enum FieldValue: Equatable, Sendable, Encodable {
    case string(String)
    case bool(Bool)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .bool(let value):   try container.encode(value)
        case .null:              try container.encodeNil()
        }
    }
}

extension FormValue {
    var fieldValue: FieldValue {
        switch self {
        case .empty:         return .null
        case .text(let s):   return .string(s)
        case .bool(let b):   return .bool(b)
        case .option(let s): return .string(s)
        case .date(let d):   return .string(FormValue.iso8601.format(d))
        }
    }
}

/// HTTP 200 is not success: the body carries `isSuccessful` / `error`, so a client that only
/// looked for `"success"` would swallow a failed create.
struct FormSubmitEnvelope: Decodable {
    let data: FormSubmitDataDTO?
    let isSuccessful: Bool?
    let success: Bool?
    let error: FormSubmitErrorDTO?
}

struct FormSubmitDataDTO: Decodable {
    let accountId: String?
    let message: String?
    let status: String?
    let partialRegistrationStatus: Int?
    let complianceResponse: FormComplianceDTO?
}

struct FormSubmitErrorDTO: Decodable {
    let code: Int?
    let displayCode: Int?
    let message: String?
}

struct FormComplianceDTO: Decodable {
    let complianceStatus: Int?
    let requiredComplianceStatus: Int?
    let isValidId: Bool?
    let message: String?
    let accessToken: String?
}

enum FormSubmitParser {
    enum Outcome {
        case accepted(FormSubmitResult)
        case rejected(FormSubmitErrorDTO?)
    }

    static func parse(_ data: Data) -> Outcome {
        // An empty 2xx is taken as accepted (an assumption; see OPEN-QUESTIONS). Anything else
        // has to be the envelope: a gateway page served with status 200, or JSON that is not
        // this shape, is not a registered account.
        if data.isEmpty { return .accepted(FormSubmitResult()) }
        guard let envelope = try? JSONDecoder().decode(FormSubmitEnvelope.self, from: data),
              envelope.isEnvelope else {
            return .rejected(nil)
        }
        if envelope.failed { return .rejected(envelope.error) }
        return .accepted(FormSubmitResult(envelope.data))
    }
}

private extension FormSubmitEnvelope {
    /// Every field is optional so a partial body still decodes; a body with none of them is
    /// some other document that happened to parse.
    var isEnvelope: Bool {
        data != nil || isSuccessful != nil || success != nil || error != nil
    }

    var failed: Bool {
        if isSuccessful == false || success == false { return true }
        return error != nil && isSuccessful != true
    }
}

extension FormSubmitResult {
    init(_ data: FormSubmitDataDTO?) {
        self.init(
            accountId: data?.accountId,
            message: data?.message,
            status: data?.status,
            partialRegistrationStatus: data?.partialRegistrationStatus,
            compliance: data?.complianceResponse.map(FormComplianceResult.init)
        )
    }
}

extension FormComplianceResult {
    init(_ dto: FormComplianceDTO) {
        self.init(
            complianceStatus: dto.complianceStatus,
            requiredComplianceStatus: dto.requiredComplianceStatus,
            isValidId: dto.isValidId,
            message: dto.message,
            accessToken: dto.accessToken
        )
    }
}
