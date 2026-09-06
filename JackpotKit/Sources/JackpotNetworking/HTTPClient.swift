import Foundation

/// The transport seam. Tests stub this — never the ApiClient itself.
///
/// Cleanup vs. the reference project: there, `URLSession` is retroactively conformed
/// to `HTTPClient` in an extension. That works, but it means every `URLSession` in the
/// process gains the conformance and there is nowhere to inject configuration
/// (timeouts, cache policy, `waitsForConnectivity`). A wrapper struct keeps the
/// conformance private to us and gives configuration a home.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public init(timeout: TimeInterval, waitsForConnectivity: Bool = false) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.waitsForConnectivity = waitsForConnectivity
        self.session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
