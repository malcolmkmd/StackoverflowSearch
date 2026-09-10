import Foundation

/// Answers requests from JSON that ships in a bundle, at the one seam the real client already has.
/// Everything above it — endpoint building, status handling, retries, decoding, error mapping — is
/// the shipping path, so a preview or a demo exercises that code rather than a parallel fake.
public struct BundledHTTPClient: HTTPClient {
    /// The bytes a request is answered with. Loaded up front so routing stays free of file I/O.
    public struct Fixture: Sendable {
        public let data: Data
        public let statusCode: Int

        public init(_ data: Data, statusCode: Int = 200) {
            self.data = data
            self.statusCode = statusCode
        }

        /// A `.json` file in `bundle`. Nil when the resource is missing, which is a wiring mistake
        /// rather than a server condition — let the caller decide how loud that should be.
        public init?(resource: String, in bundle: Bundle, statusCode: Int = 200) {
            guard let url = bundle.url(forResource: resource, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            self.init(data, statusCode: statusCode)
        }
    }

    private let latency: TimeInterval
    private let route: @Sendable (URLRequest) -> Fixture?

    /// - Parameters:
    ///   - latency: Artificial delay, so in-flight states are visible in a preview.
    ///   - route: The fixture that answers a request; nil is served as a 404.
    public init(latency: TimeInterval = 0,
                route: @escaping @Sendable (URLRequest) -> Fixture?) {
        self.latency = latency
        self.route = route
    }

    /// Every request is answered by the same fixture.
    public init(_ fixture: Fixture, latency: TimeInterval = 0) {
        self.init(latency: latency) { _ in fixture }
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if latency > 0 {
            try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        }
        let fixture = route(request)
        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: fixture?.statusCode ?? 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (fixture?.data ?? Data(), response)
    }
}
