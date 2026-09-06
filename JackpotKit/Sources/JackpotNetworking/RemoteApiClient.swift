import Foundation

public protocol ApiClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response
    /// For 204 / empty-body responses.
    func request(_ endpoint: some APIEndpoint) async throws
    /// The raw bytes, for responses decoded section-by-section rather than into one type.
    func requestData(_ endpoint: some APIEndpoint) async throws -> Data
    /// Revalidates against what the caller already holds. Returns `.notModified` on a 304.
    func requestConditional(_ endpoint: some APIEndpoint,
                            validators: HTTPValidators?) async throws -> ConditionalResponse
}

public struct RemoteApiClient: ApiClient {
    private let environment: APIEnvironment
    private let httpClient: any HTTPClient
    private let interceptors: [any RequestInterceptor]
    private let decoder: JSONDecoder
    private let maxTransientRetries: Int

    public init(environment: APIEnvironment,
                httpClient: any HTTPClient = URLSessionHTTPClient(),
                interceptors: [any RequestInterceptor] = [],
                decoder: JSONDecoder = JSONDecoder(),
                maxTransientRetries: Int = 1) {
        self.environment = environment
        self.httpClient = httpClient
        self.interceptors = interceptors
        self.decoder = decoder
        self.maxTransientRetries = maxTransientRetries
    }

    public func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response {
        let (data, _) = try await perform(endpoint)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            // Cleanup vs. the reference project: it throws `.decoding(error.localizedDescription)`,
            // which for DecodingError is famously useless ("The data couldn't be read"). The
            // full description names the key path that failed.
            throw APIError.decoding("\(Response.self): \(error)")
        }
    }

    public func request(_ endpoint: some APIEndpoint) async throws {
        _ = try await perform(endpoint)
    }

    public func requestData(_ endpoint: some APIEndpoint) async throws -> Data {
        try await perform(endpoint).0
    }

    public func requestConditional(_ endpoint: some APIEndpoint,
                                   validators: HTTPValidators?) async throws -> ConditionalResponse {
        let (data, response) = try await perform(endpoint, extraHeaders: validators?.conditionalHeaders ?? [:])
        if response.statusCode == 304 { return .notModified }
        return .fresh(data, HTTPValidators(response))
    }

    // MARK: - Pipeline

    private func perform(_ endpoint: some APIEndpoint,
                         extraHeaders: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var request = try endpoint.urlRequest(in: environment)
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        for interceptor in interceptors {
            request = try await interceptor.adapt(request, for: endpoint)
        }
        return try await send(request, for: endpoint, didRetryAuth: false, transientRetries: 0)
    }

    private func send(_ request: URLRequest,
                      for endpoint: some APIEndpoint,
                      didRetryAuth: Bool,
                      transientRetries: Int) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await transport(request)

        switch response.statusCode {
        case 200..<300:
            return (data, response)

        case 304:
            // Only reachable when the caller sent conditional headers; `requestConditional`
            // turns this into `.notModified`.
            return (data, response)

        case 401:
            // One chance for an interceptor to refresh and retry. `didRetryAuth` is a
            // parameter rather than stored state, so a second 401 can never loop.
            if !didRetryAuth {
                for interceptor in interceptors {
                    if let retry = await interceptor.retry(request, for: endpoint, response: response, data: data) {
                        return try await send(retry, for: endpoint, didRetryAuth: true, transientRetries: transientRetries)
                    }
                }
            }
            throw APIError.unauthorized(problem(from: data))

        case 400:
            throw APIError.badRequest(problem(from: data))

        case 500:
            // A POST may already have taken effect server-side, so only idempotent
            // requests are retried.
            if endpoint.isIdempotent, transientRetries < maxTransientRetries {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await send(request, for: endpoint, didRetryAuth: didRetryAuth,
                                      transientRetries: transientRetries + 1)
            }
            throw APIError.server(problem(from: data))

        default:
            // Outside the documented contract (200/400/401/500) — a proxy, gateway, WAF or a
            // misrouted deploy. Retry idempotent 5xx the same way, then report the real status
            // rather than flattening it into `.server` and losing the diagnostic.
            if (502...504).contains(response.statusCode),
               endpoint.isIdempotent,
               transientRetries < maxTransientRetries {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await send(request, for: endpoint, didRetryAuth: didRetryAuth,
                                      transientRetries: transientRetries + 1)
            }
            throw APIError.unexpectedStatus(response.statusCode, problem(from: data))
        }
    }

    private func transport(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await httpClient.send(request)
        } catch is CancellationError {
            // Cleanup vs. the reference project: it writes `catch is CancellationError { throw CancellationError() }`,
            // which constructs a fresh error to say the same thing. And it never handles
            // `URLError.cancelled`, which is what URLSession actually throws when a Task is
            // cancelled mid-flight — so cancelled loads surfaced to users as failures.
            throw APIError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch let error as URLError {
            throw APIError.transport(error.code)
        }
    }

    private func problem(from data: Data) -> APIProblem? {
        try? JSONDecoder().decode(APIProblem.self, from: data)
    }
}
