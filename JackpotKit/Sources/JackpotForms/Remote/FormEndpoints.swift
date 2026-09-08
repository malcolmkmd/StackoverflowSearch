import Foundation
import JackpotNetworking

// Fetch carries `api-version=2.0` and submit carries none, so the version lives on the request.
extension APIEnvironment {
    static func cron(baseURL: URL) -> APIEnvironment {
        APIEnvironment(baseURL: baseURL)
    }

    /// `…/crm` → `…/cron`: call sites historically passed a CRM base; production fetch is on cron.
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

/// `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`.
struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    var path: String { "forms/\(brand)/\(region)/\(formName.rawValue)" }
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "2.0")] }
}

/// `POST {cron}/forms/submit`. No auth: registration happens before login.
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

/// Wire shape of `FormSubmission`.
struct FormSubmitBody: Encodable {
    let formId: String
    let formName: String
    let submittedAt: Date
    let fields: [String: FormValue]

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case formName = "form_name"
        case submittedAt = "submitted_at"
        case fields
    }

    init(_ submission: FormSubmission) {
        formId = submission.formId
        formName = submission.formCodeName.rawValue
        submittedAt = submission.submittedAt
        fields = submission.values
    }

    /// ISO-8601 is an assumption; the production encoder wasn't visible.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

/// Untagged JSON: a string, a bare `true` / `false` for checkboxes, `null` for an empty value.
extension FormValue: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .empty:       try container.encodeNil()
        case .bool(let b): try container.encode(b)
        default:           try container.encode(stringValue)
        }
    }
}

/// HTTP 200 is not success: `isSuccessful` is.
struct FormSubmitEnvelope: Decodable {
    let data: FormSubmitResult?
    let isSuccessful: Bool?
    let error: FormSubmitErrorDTO?
}

struct FormSubmitErrorDTO: Decodable {
    let code: Int?
    let displayCode: Int?
    let message: String?
}

enum FormSubmitParser {
    enum Outcome {
        case accepted(FormSubmitResult)
        case rejected(FormSubmitErrorDTO?)
    }

    /// An empty 2xx is taken as accepted (an assumption); anything else must be the envelope.
    static func parse(_ data: Data) -> Outcome {
        if data.isEmpty { return .accepted(FormSubmitResult()) }
        guard let envelope = try? JSONDecoder().decode(FormSubmitEnvelope.self, from: data),
              envelope.isEnvelope else {
            return .rejected(nil)
        }
        if envelope.failed { return .rejected(envelope.error) }
        return .accepted(envelope.data ?? FormSubmitResult())
    }
}

private extension FormSubmitEnvelope {
    /// Every field is optional, so a body with none of them is some other document.
    var isEnvelope: Bool {
        data != nil || isSuccessful != nil || error != nil
    }

    var failed: Bool {
        isSuccessful == false || (isSuccessful == nil && error != nil)
    }
}
