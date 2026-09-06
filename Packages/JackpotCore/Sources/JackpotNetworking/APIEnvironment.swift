import Foundation

/// Base URL + headers every request in an environment carries.
///
/// Cleanup vs. the reference project: there, `APIEndpoint` has a default
/// `baseURL` pointing at a hardcoded host, and `asURLRequest()` splices in
/// `StackExchangeRequest.commonQueryItems()`. That bakes one API's identity into
/// the generic protocol, so the layer can't serve a second host or a staging
/// environment without editing the protocol. Environment is data, injected once.
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
