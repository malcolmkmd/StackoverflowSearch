import Foundation
import JackpotNetworking
import JackpotFormsDomain

/// `GET {cron}/forms/{brand}/{region}/{identifier}?api-version=2.0` — one template for both
/// fetch-by-name and fetch-by-id, matching production `buildFormURL`.
public struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let identifier: String

    public init(brand: String, region: String, formName: FormName) {
        self.init(brand: brand, region: region, identifier: formName.rawValue)
    }

    init(brand: String, region: String, identifier: String) {
        self.brand = brand
        self.region = region
        self.identifier = identifier
    }

    public var path: String { "forms/\(brand)/\(region)/\(identifier)" }
    public var method: HTTPMethod { .GET }
    public var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "2.0")] }
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

/// Wire shape of `FormSubmission`, so Domain stays free of JSON key names.
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
        case .date(let d):   return .string(FormValue.iso8601.string(from: d))
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
        if data.isEmpty { return .accepted(FormSubmitResult()) }
        guard let envelope = try? JSONDecoder().decode(FormSubmitEnvelope.self, from: data) else {
            return .accepted(FormSubmitResult())
        }
        if envelope.failed { return .rejected(envelope.error) }
        return .accepted(FormSubmitResult(envelope.data))
    }
}

private extension FormSubmitEnvelope {
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
