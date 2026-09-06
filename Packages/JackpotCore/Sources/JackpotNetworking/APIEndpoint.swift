import Foundation

public enum RequestBody: Sendable {
    case json(Data)
    case form([String: String])

    public static func encodable<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) throws -> RequestBody {
        .json(try encoder.encode(value))
    }
}

/// One endpoint = one request shape. Knows its own path, method and body;
/// knows nothing about hosts, auth or versioning.
public protocol APIEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: RequestBody? { get }
    /// False for login and token-refresh endpoints, so auth interceptors skip them —
    /// a refresh request must never carry the token it is replacing. Defaults to true.
    var requiresAuth: Bool { get }
    /// Safe to retry on 5xx / timeout. Defaults to `method == .GET`.
    var isIdempotent: Bool { get }
}

public extension APIEndpoint {
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
    var body: RequestBody? { nil }
    var requiresAuth: Bool { true }
    var isIdempotent: Bool { method == .GET }

    func urlRequest(in environment: APIEnvironment) throws -> URLRequest {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(
            url: environment.baseURL.appendingPathComponent(trimmed),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL(path)
        }

        let allQuery = environment.defaultQueryItems + queryItems
        if !allQuery.isEmpty { components.queryItems = allQuery }

        guard let url = components.url else { throw APIError.invalidURL(path) }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (key, value) in environment.defaultHeaders { request.setValue(value, forHTTPHeaderField: key) }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

        switch body {
        case .json(let data):
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .form(let fields):
            var form = URLComponents()
            form.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        case nil:
            break
        }
        return request
    }
}
