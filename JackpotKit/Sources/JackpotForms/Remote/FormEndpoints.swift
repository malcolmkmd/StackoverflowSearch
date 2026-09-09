import Foundation
import JackpotNetworking

/// `GET cron/forms/{brand}/{region}/{name}?api-version=2.0`.
struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    var path: String { "cron/forms/\(brand)/\(region)/\(formName.rawValue)" }
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "2.0")] }
}

/// `POST cron/forms/submit`, with no `api-version`. No auth: registration happens before login.
struct FormSubmitRequest: APIEndpoint {
    let bodyData: Data

    /// ISO-8601 is an assumption; the production encoder wasn't visible.
    init(_ submission: FormSubmission) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        bodyData = try encoder.encode(submission)
    }

    var path: String { "cron/forms/submit" }
    var method: HTTPMethod { .POST }
    var body: RequestBody? { .json(bodyData) }
    var requiresAuth: Bool { false }
}

/// HTTP 200 is not success: `isSuccessful` is.
struct FormSubmitEnvelope: Decodable {
    let data: FormSubmitResult?
    let isSuccessful: Bool?
    let error: Failure?

    struct Failure: Decodable {
        let code: Int?
        let displayCode: Int?
        let message: String?
    }
}
