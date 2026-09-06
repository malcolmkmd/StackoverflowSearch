import Foundation

/// Base URL + headers every request in an environment carries. Injected once, so the
/// layer can serve a second host or a staging environment without touching `APIEndpoint`.
public struct APIEnvironment: Sendable {
    public let baseURL: URL
    public let defaultHeaders: [String: String]
    /// Query items appended to every request (api-version, site, locale…).
    public let defaultQueryItems: [URLQueryItem]

    public init(baseURL: URL,
                defaultHeaders: [String: String] = ["Accept": "application/json"],
                defaultQueryItems: [URLQueryItem] = []) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.defaultQueryItems = defaultQueryItems
    }
}
