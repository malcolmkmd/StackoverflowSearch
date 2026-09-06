# JackpotCore

Shared infrastructure for the JackpotCity app. **Arrives in PR 4** (networking) and **PR 6**
(app-data + localisation) of the delivery plan — see `docs/PR-STRATEGY.md`. Nothing here knows about any one feature —
forms, account, casino and payments all sit on top of it.

**iOS 15+ · no third-party dependencies · 66 tests**

Two targets today:

| Target | Holds |
|---|---|
| `JackpotNetworking` | HTTP transport, typed endpoints, errors, interceptors — **PR 4** |
| `JackpotAppData` | section-wise bootstrap ingestion — **PR 6** |
| `JackpotLocalization` | the session's translation table and its owner — **PR 6** |

`JackpotSecurity` (keychain, biometrics) and `JackpotDiagnostics` (leak detection, memory reporting)
belong here next — see task 13 of the modernization plan.

```bash
swift test        # 66 tests
```

---

## Why this is its own package

It was originally a target inside the forms package. That was wrong: the Account team adopting
the HTTP layer would have written

```swift
.product(name: "JackpotNetworking", package: "JackpotForms")   // reads as a mistake, and is one
```

and would have inherited the forms engine's release cadence and review surface for nothing.
Infrastructure that several features share belongs in a package named for what it is.

## Using it

```swift
// Package.swift
dependencies: [.package(path: "../JackpotCore")],
targets: [
    .target(name: "YourFeature", dependencies: [
        .product(name: "JackpotNetworking", package: "JackpotCore")
    ])
]
```

```swift
import JackpotNetworking

struct BalanceRequest: APIEndpoint {
    var path: String { "player/balance" }
}

let client = RemoteApiClient(
    environment: .init(baseURL: URL(string: "https://api.jackpotcity.co.za/v1")!),
    interceptors: [BearerTokenInterceptor { await session.accessToken }]
)

let balance: BalanceDTO = try await client.request(BalanceRequest())
```

## Design notes

If you're porting from an older client, these are the things worth carrying over. Each is
commented at the site.

**Environment is data, injected once, and this package names no service.** Don't put a
`baseURL` default or app-specific query items in `APIEndpoint` *or* in `APIEnvironment` — that
bakes one API's identity into the generic type and blocks a second host or a staging
environment. Per-service conventions (`api-version=2.0`, a `site` parameter, a locale header)
belong beside the endpoints that need them:

```swift
// In your feature's Data target, not here:
public extension APIEnvironment {
    static func crm(baseURL: URL, apiVersion: String = "2.0") -> APIEnvironment {
        APIEnvironment(baseURL: baseURL,
                       defaultQueryItems: [URLQueryItem(name: "api-version", value: apiVersion)])
    }
}
```

**Wrap `URLSession`, don't retroactively conform it.** A conformance on `URLSession` gives every
session in the process the protocol and leaves nowhere to inject timeouts or
`waitsForConnectivity`.

**One interceptor seam** for auth, refresh, logging and correlation IDs — instead of the same
header code copied into forty API classes.

**`requiresAuth` on the endpoint.** A token-refresh request must never carry the token it's
replacing. `BearerTokenInterceptor` honours it.

**`URLError.cancelled` is not `CancellationError`.** It's what URLSession actually throws when a
task is cancelled mid-flight. Miss it and cancelled loads surface to users as failures.

**Retry budget is a call-shape parameter, not stored state.** `didRetryAuth` and
`transientRetries` are passed down the recursion, so "retry at most once" can't be broken by a
future edit to a counter.

**Decoding errors name the type.** `DecodingError.localizedDescription` is "The data couldn't be
read", which tells you nothing. The full description names the failing key path.

## Status-code policy

The API's contract is **200, 400, 401, 500**. Those four get named cases; anything else can
still arrive from a proxy, gateway or misrouted deploy, so it is reported as what it is rather
than flattened into `.server` and losing the diagnostic.

| Status | Behaviour |
|---|---|
| 200–299 | decode |
| 400 | `.badRequest(APIProblem?)` |
| 401 | one interceptor retry (refresh), then `.unauthorized(APIProblem?)` |
| 500 | retry once **if idempotent**, then `.server(APIProblem?)` |
| 502–504 | retry once if idempotent, then `.unexpectedStatus(code, problem)` |
| anything else | `.unexpectedStatus(code, problem)`, no retry |
| transport | `.transport(URLError.Code)`; `.isOffline` covers the connectivity cases |

A POST is never retried — it may already have taken effect server-side.

## The error envelope

```json
{ "code": 0, "message": "Error message" }
```

`APIProblem.code` is an **`Int`**. It was `String?` in the first draft, which meant `{"code": 0}`
failed to decode and every problem came back `nil` — silently, because problem decoding is
`try?` by design so a gateway's HTML body can't throw. A shape mismatch here produces no crash
and no log, just permanently empty error messages, so `APIProblemTests` exists specifically to
catch a backend field rename.

Two behaviours worth knowing:

- A body with **neither** `code` nor `message` (`{}`, or unrelated JSON) decodes to `nil`, not to
  an empty envelope. `.badRequest(nil)` reads "the server said nothing", which is true and
  different from "the server sent an empty complaint".
- **String codes are coerced to `Int`**, so a backend that changes its mind can't silently break
  every message.

Use `APIError.serverMessage` to get the server's own wording — it is almost always better than
anything the client could substitute.

---

## Building it from scratch

Seven files, one target. Each compiles against the ones above it.

```bash
mkdir -p JackpotCore/Sources/JackpotNetworking JackpotCore/Tests/JackpotNetworkingTests
cd JackpotCore
```

#### `Package.swift`

```swift
// swift-tools-version: 5.7
import PackageDescription

// Shared infrastructure for the JackpotCity app. Nothing here knows about any one
// feature — forms, account, casino and payments all sit on top of it.
//
// `JackpotNetworking`, `JackpotAppData` and `JackpotLocalization` today. `JackpotSecurity` (keychain, biometrics) and
// `JackpotDiagnostics` (leak detection, memory reporting) belong here next; see task 13 of
// the modernization plan.
let package = Package(
    name: "JackpotCore",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
    ],
    targets: [
        .target(name: "JackpotNetworking"),
        // Bootstrap-payload ingestion. Every feature reads its own section from this.
        .target(name: "JackpotAppData", dependencies: ["JackpotNetworking"]),
        .target(name: "JackpotLocalization", dependencies: ["JackpotNetworking", "JackpotAppData"]),

        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),
        .testTarget(name: "JackpotAppDataTests", dependencies: ["JackpotAppData"]),
        .testTarget(name: "JackpotLocalizationTests", dependencies: ["JackpotLocalization"]),
    ]
)
```

#### `Sources/JackpotNetworking/HTTPMethod.swift`

Trivial, but it stops method strings being typed by hand at call sites.

```swift
import Foundation

public enum HTTPMethod: String, Sendable {
    case GET, POST, PUT, PATCH, DELETE
}
```

#### `Sources/JackpotNetworking/HTTPClient.swift`

The transport seam. Tests stub **this**, never `ApiClient` — you want to exercise your URL building, status handling and decoding, not re-test `JSONDecoder`.

```swift
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
```

#### `Sources/JackpotNetworking/APIEnvironment.swift`

Base URL, default headers, default query items — and **nothing service-specific**. An earlier version had a `jpcConfig` factory naming `config.jpc.africa` here; that was the same mistake as the reference project splicing StackExchange query items into `asURLRequest()`, just softer. A generic layer that names one host isn't generic, it just hasn't met a second host yet. That factory now lives beside the endpoints that use it, in `JackpotFormsData`.

```swift
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
```

#### `Sources/JackpotNetworking/APIEndpoint.swift`

One endpoint = one request shape. Knows its path, method and body; knows nothing about hosts, auth or versioning.

```swift
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
```

#### `Sources/JackpotNetworking/APIError.swift`

Two types with different owners. `APIProblem` is **server-authored** and open — new codes ship without an app release. `APIError` is **client-authored** and closed — new cases need one. Merging them would let the backend define your error enum.

```swift
import Foundation

/// The error envelope the API returns with a non-2xx response:
///
///     { "code": 0, "message": "Error message" }
///
/// `code` is a **number**, not a string — an earlier version had it as `String?`, which meant
/// `{"code": 0}` failed to decode and every problem silently came back `nil`. Since decoding is
/// `try?` by design (a gateway may return HTML, and that must not throw), a shape mismatch here
/// is invisible: you get no crash, no log, just permanently empty error messages. It decodes
/// both number and string forms now so a backend that changes its mind can't reintroduce that.
public struct APIProblem: Decodable, Sendable, Equatable {
    public let code: Int?
    public let message: String?

    public init(code: Int?, message: String?) {
        self.code = code
        self.message = message
    }

    private enum CodingKeys: String, CodingKey { case code, message }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedCode: Int?
        if let number = try? container.decodeIfPresent(Int.self, forKey: .code) {
            decodedCode = number
        } else {
            decodedCode = (try? container.decodeIfPresent(String.self, forKey: .code)).flatMap { $0.flatMap(Int.init) }
        }
        let decodedMessage = (try? container.decodeIfPresent(String.self, forKey: .message))?.flatMap {
            $0.isEmpty ? nil : $0
        }

        // A body carrying neither field — `{}`, or JSON that happens to parse but isn't a
        // problem envelope — is *not* a problem. Throwing here means the client's `try?`
        // yields nil, so `.badRequest(nil)` correctly reads "the server said nothing"
        // rather than "the server sent an empty complaint".
        guard decodedCode != nil || decodedMessage != nil else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Not a problem envelope: neither `code` nor `message` present"
            ))
        }

        code = decodedCode
        message = decodedMessage
    }
}

/// What the client concluded happened.
///
/// The API contract is **200, 400, 401, 500** — those four have named cases. Anything else can
/// still arrive from a proxy, gateway, WAF or a misrouted deploy, so `unexpectedStatus` carries
/// it rather than pretending it can't happen or silently reporting it as a server error.
///
/// Distinct from `APIProblem`: this enum is client-authored and closed (new cases need an app
/// release); `APIProblem` is server-authored and open (new codes ship without one).
public enum APIError: Error, Sendable, Equatable {
    case invalidURL(String)
    case transport(URLError.Code)
    /// 400 — the request was rejected. `problem.message` is the text to show.
    case badRequest(APIProblem?)
    /// 401 — after any interceptor has had its one chance to refresh and retry.
    case unauthorized(APIProblem?)
    /// 500 — after one retry, if the endpoint was idempotent.
    case server(APIProblem?)
    /// Outside the documented contract. Almost always infrastructure rather than the API.
    case unexpectedStatus(Int, APIProblem?)
    case decoding(String)
    case cancelled

    /// The server's envelope, whichever case carries it.
    public var problem: APIProblem? {
        switch self {
        case .badRequest(let p), .unauthorized(let p), .server(let p), .unexpectedStatus(_, let p):
            return p
        case .invalidURL, .transport, .decoding, .cancelled:
            return nil
        }
    }

    /// The server's own wording, when it sent any. Prefer this over a generic string.
    public var serverMessage: String? {
        problem?.message.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var isOffline: Bool {
        guard case .transport(let code) = self else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut].contains(code)
    }

}
```

#### `Sources/JackpotNetworking/RequestInterceptor.swift`

`adapt` mutates outgoing requests; `retry` gets one chance to fix a failed one. `BearerTokenInterceptor` takes a closure, so this layer never imports a session type.

```swift
import Foundation

/// The seam the reference project has no equivalent of. Auth headers, token refresh,
/// logging and correlation IDs all belong here — once — instead of in every API type.
public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest
    /// Return an adapted request to retry with, or nil to give up. Called at most once.
    func retry(_ request: URLRequest,
               for endpoint: any APIEndpoint,
               response: HTTPURLResponse,
               data: Data) async -> URLRequest?
}

public extension RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest { request }
    func retry(_ request: URLRequest,
               for endpoint: any APIEndpoint,
               response: HTTPURLResponse,
               data: Data) async -> URLRequest? { nil }
}

/// Adds a bearer token. The token is supplied by a closure so this layer never
/// imports a session type — that keeps JackpotNetworking free of app concerns.
public struct BearerTokenInterceptor: RequestInterceptor {
    private let token: @Sendable () async -> String?

    public init(token: @escaping @Sendable () async -> String?) {
        self.token = token
    }

    public func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest {
        // Never attach a token to login/refresh — see `APIEndpoint.requiresAuth`.
        guard endpoint.requiresAuth, let token = await token() else { return request }
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
```

#### `Sources/JackpotNetworking/RemoteApiClient.swift`

The pipeline implementing the table above.

```swift
import Foundation

public protocol ApiClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response
    /// For 204 / empty-body responses.
    func request(_ endpoint: some APIEndpoint) async throws
    /// The raw bytes, for responses decoded section-by-section rather than into one type.
    func requestData(_ endpoint: some APIEndpoint) async throws -> Data
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
        let data = try await perform(endpoint)
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
        try await perform(endpoint)
    }

    // MARK: - Pipeline

    private func perform(_ endpoint: some APIEndpoint) async throws -> Data {
        var request = try endpoint.urlRequest(in: environment)
        for interceptor in interceptors {
            request = try await interceptor.adapt(request, for: endpoint)
        }
        return try await send(request, for: endpoint, didRetryAuth: false, transientRetries: 0)
    }

    private func send(_ request: URLRequest,
                      for endpoint: some APIEndpoint,
                      didRetryAuth: Bool,
                      transientRetries: Int) async throws -> Data {
        let (data, response) = try await transport(request)

        switch response.statusCode {
        case 200..<300:
            return data

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
```

**✓ Checkpoint**

```bash
swift build
```

### Tests

#### `Tests/JackpotNetworkingTests/MockHTTPClient.swift`

An actor, because the client calls it from concurrent tasks. Stubs can be queued, so a 401-then-200 retry sequence is expressible.

```swift
import Foundation
import XCTest
@testable import JackpotNetworking

/// Stubs the *transport*, not the client — so these tests exercise real URL building,
/// real status handling and real decoding, with only the socket replaced.
///
/// An actor because the client calls it from concurrent tasks.
actor MockHTTPClient: HTTPClient {

    struct Stub {
        var data: Data
        var statusCode: Int
        var headers: [String: String]
        var error: (any Error)?

        static func ok(_ json: String, status: Int = 200) -> Stub {
            Stub(data: Data(json.utf8), statusCode: status, headers: [:], error: nil)
        }
        static func status(_ code: Int, json: String = "{}", headers: [String: String] = [:]) -> Stub {
            Stub(data: Data(json.utf8), statusCode: code, headers: headers, error: nil)
        }
        static func failure(_ error: any Error) -> Stub {
            Stub(data: Data(), statusCode: 0, headers: [:], error: error)
        }
    }

    private(set) var requests: [URLRequest] = []
    private var queue: [Stub]
    private let fallback: Stub

    init(_ stubs: [Stub], fallback: Stub = .status(500)) {
        self.queue = stubs
        self.fallback = fallback
    }

    convenience init(_ stub: Stub) { self.init([stub], fallback: stub) }

    var requestCount: Int { requests.count }

    /// Asserted inside the actor, so callers don't have to reach across isolation.
    func assertRequests(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(requests.count, expected, file: file, line: line)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let stub = queue.isEmpty ? fallback : queue.removeFirst()
        if let error = stub.error { throw error }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: stub.headers
        )!
        return (stub.data, response)
    }
}

// MARK: - Fixtures

struct Widget: Decodable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct WidgetRequest: APIEndpoint {
    var path: String { "widgets/42" }
}

struct CreateWidgetRequest: APIEndpoint {
    let name: String
    var path: String { "widgets" }
    var method: HTTPMethod { .POST }
    var body: RequestBody? { .form(["name": name]) }
}

struct SearchRequest: APIEndpoint {
    let term: String
    var path: String { "search" }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "q", value: term)] }
}

extension APIEnvironment {
    static let test = APIEnvironment(
        baseURL: URL(string: "https://api.example.com/v1")!,
        defaultHeaders: ["Accept": "application/json"],
        defaultQueryItems: [URLQueryItem(name: "api-version", value: "2.0")]
    )
}
```

#### `Tests/JackpotNetworkingTests/APIEndpointTests.swift`

URL building, query-item merging, body encoding, and the derived defaults.

```swift
import XCTest
@testable import JackpotNetworking

final class APIEndpointTests: XCTestCase {

    func testBuildsURLFromEnvironmentAndPath() throws {
        let request = try WidgetRequest().urlRequest(in: .test)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.example.com/v1/widgets/42?api-version=2.0")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    /// Environment query items come first, then the endpoint's own — so an endpoint can
    /// never accidentally drop the API version.
    func testMergesEnvironmentAndEndpointQueryItems() throws {
        let request = try SearchRequest(term: "swift").urlRequest(in: .test)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.map(\.name), ["api-version", "q"])
        XCTAssertEqual(components.queryItems?.last?.value, "swift")
    }

    func testLeadingSlashInPathDoesNotBreakTheURL() throws {
        struct Slashed: APIEndpoint { var path: String { "/widgets" } }
        let request = try Slashed().urlRequest(in: .test)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.example.com/v1/widgets?api-version=2.0")
    }

    func testFormBodyIsPercentEncodedWithTheRightContentType() throws {
        let request = try CreateWidgetRequest(name: "a b&c").urlRequest(in: .test)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(body, "name=a%20b%26c")
    }

    func testJSONBodySetsContentType() throws {
        struct JSONPost: APIEndpoint {
            var path: String { "x" }
            var method: HTTPMethod { .POST }
            var body: RequestBody? { .json(Data(#"{"a":1}"#.utf8)) }
        }
        let request = try JSONPost().urlRequest(in: .test)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testDefaultsAreSaneWithoutOverrides() {
        let endpoint = WidgetRequest()
        XCTAssertEqual(endpoint.method, .GET)
        XCTAssertTrue(endpoint.queryItems.isEmpty)
        XCTAssertNil(endpoint.body)
        XCTAssertTrue(endpoint.requiresAuth)
        XCTAssertTrue(endpoint.isIdempotent)          // derived from .GET
    }

    func testPostIsNotIdempotentByDefault() {
        XCTAssertFalse(CreateWidgetRequest(name: "x").isIdempotent)
    }
}
```

#### `Tests/JackpotNetworkingTests/RemoteApiClientTests.swift`

The status-code table, the retry budget, and the two traps: `URLError.cancelled`, and never attaching a bearer token to an auth-exempt endpoint.

```swift
import XCTest
@testable import JackpotNetworking

final class RemoteApiClientTests: XCTestCase {

    private func client(_ http: MockHTTPClient,
                        interceptors: [any RequestInterceptor] = []) -> RemoteApiClient {
        RemoteApiClient(environment: .test, httpClient: http, interceptors: interceptors)
    }

    // MARK: Success

    func testDecodesA200() async throws {
        let http = MockHTTPClient(.ok(#"{"id":42,"name":"Sprocket"}"#))
        let widget: Widget = try await client(http).request(WidgetRequest())
        XCTAssertEqual(widget, Widget(id: 42, name: "Sprocket"))
        await http.assertRequests(1)
    }

    func testEmptyBodyRequestIgnoresThePayload() async throws {
        let http = MockHTTPClient(.status(204))
        try await client(http).request(WidgetRequest())
        await http.assertRequests(1)
    }

    // MARK: The documented contract — 200, 400, 401, 500

    func test400CarriesTheServersMessage() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":1042,"message":"Mobile number already registered"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            guard case .badRequest(let problem) = error as? APIError else {
                return XCTFail("expected .badRequest, got \(error)")
            }
            XCTAssertEqual(problem, APIProblem(code: 1042, message: "Mobile number already registered"))
            XCTAssertEqual((error as? APIError)?.serverMessage, "Mobile number already registered")
        }
    }

    /// `{"code": 0, ...}` is the shape the API actually sends. An earlier `code: String?`
    /// meant this decoded to nil and every error message came back empty — silently,
    /// because problem decoding is `try?` by design.
    func testNumericZeroCodeDecodes() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":0,"message":"Error message"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual((error as? APIError)?.problem, APIProblem(code: 0, message: "Error message"))
        }
    }

    func testStringCodeAlsoDecodes() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":"7","message":"x"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual((error as? APIError)?.problem?.code, 7)
        }
    }

    /// A gateway returning HTML must not throw a decoding error on the way to reporting
    /// the status.
    func testNonJSONErrorBodyStillReportsTheStatus() async {
        let http = MockHTTPClient(.status(400, json: "<html>502 Bad Gateway</html>"))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .badRequest(nil))
            XCTAssertNil((error as? APIError)?.serverMessage)
        }
    }

    func test500CarriesTheProblemAfterRetrying() async {
        let http = MockHTTPClient([.status(500), .status(500, json: #"{"code":9,"message":"Down"}"#)])
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .server(APIProblem(code: 9, message: "Down")))
        }
        await http.assertRequests(2)
    }

    func test500DoesNotRetryANonIdempotentRequest() async {
        let http = MockHTTPClient([.status(500), .ok(#"{"id":1,"name":"x"}"#)])
        await AssertThrows(try await client(http).request(CreateWidgetRequest(name: "x")) as Widget) { error in
            XCTAssertEqual(error as? APIError, .server(nil))
        }
        await http.assertRequests(1)
    }

    // MARK: Outside the contract — infrastructure, not the API

    func test404IsReportedAsUnexpectedRatherThanFlattenedIntoServer() async {
        let http = MockHTTPClient(.status(404))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(404, nil))
        }
        await http.assertRequests(1)   // a 404 is not retried
    }

    func testGatewayErrorsRetryOnceThenReportTheirRealStatus() async {
        let http = MockHTTPClient([.status(503), .status(503)])
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(503, nil))
        }
        await http.assertRequests(2)
    }

    // MARK: Transport and decoding

    func testMalformedJSONSurfacesAsDecodingWithTheTypeName() async {
        let http = MockHTTPClient(.ok(#"{"id":"not-an-int"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            guard case .decoding(let message) = error as? APIError else {
                return XCTFail("expected .decoding, got \(error)")
            }
            // DecodingError.localizedDescription is "The data couldn't be read" — useless.
            XCTAssertTrue(message.contains("Widget"), message)
        }
    }

    func testOfflineMapsToTransportAndIsFlaggedOffline() async {
        let http = MockHTTPClient(.failure(URLError(.notConnectedToInternet)))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .transport(.notConnectedToInternet))
            XCTAssertTrue((error as? APIError)?.isOffline == true)
        }
    }

    /// URLSession throws `URLError.cancelled`, not `CancellationError`, when a task is
    /// cancelled mid-flight. Miss this and cancelled loads surface to users as failures.
    func testURLErrorCancelledMapsToCancelled() async {
        let http = MockHTTPClient(.failure(URLError(.cancelled)))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .cancelled)
        }
    }

    // MARK: Auth retry

    func test401RetriesOnceWithTheRefreshedToken() async throws {
        let http = MockHTTPClient([.status(401), .ok(#"{"id":1,"name":"ok"}"#)])
        let interceptor = StubAuthInterceptor(refreshedToken: "new-token")
        let widget: Widget = try await client(http, interceptors: [interceptor]).request(WidgetRequest())

        XCTAssertEqual(widget.name, "ok")
        await http.assertRequests(2)
        let retried = await http.requests[1]
        XCTAssertEqual(retried.value(forHTTPHeaderField: "Authorization"), "Bearer new-token")
    }

    /// The retry budget is a call-shape parameter, not stored state — so a second 401
    /// can never loop.
    func testSecond401GivesUpAsUnauthorized() async {
        let http = MockHTTPClient([.status(401), .status(401), .status(401)])
        let interceptor = StubAuthInterceptor(refreshedToken: "new-token")
        await AssertThrows(try await client(http, interceptors: [interceptor]).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unauthorized(nil))
        }
        await http.assertRequests(2)
    }

    func test401WithNoInterceptorFailsImmediately() async {
        let http = MockHTTPClient(.status(401))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unauthorized(nil))
        }
        await http.assertRequests(1)
    }

    func testBearerTokenIsAttachedButNotToAuthExemptEndpoints() async throws {
        struct LoginRequest: APIEndpoint {
            var path: String { "auth/login" }
            var method: HTTPMethod { .POST }
            var requiresAuth: Bool { false }
        }
        let http = MockHTTPClient([.ok(#"{"id":1,"name":"a"}"#), .ok(#"{"id":1,"name":"a"}"#)])
        let sut = client(http, interceptors: [BearerTokenInterceptor { "abc" }])

        _ = try await sut.request(WidgetRequest()) as Widget
        _ = try await sut.request(LoginRequest()) as Widget

        let widgetAuth = await http.requests[0].value(forHTTPHeaderField: "Authorization")
        let loginAuth  = await http.requests[1].value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(widgetAuth, "Bearer abc")
        XCTAssertNil(loginAuth, "a login request must never carry a bearer token")
    }

}

// MARK: - Helpers

private struct StubAuthInterceptor: RequestInterceptor {
    let refreshedToken: String

    func retry(_ request: URLRequest, for endpoint: any APIEndpoint,
               response: HTTPURLResponse, data: Data) async -> URLRequest? {
        guard response.statusCode == 401 else { return nil }
        var retry = request
        retry.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
        return retry
    }
}

private func AssertThrows<T>(_ expression: @autoclosure () async throws -> T,
                             file: StaticString = #filePath, line: UInt = #line,
                             _ verify: (any Error) -> Void) async {
    do {
        _ = try await expression()
        XCTFail("expected a thrown error", file: file, line: line)
    } catch {
        verify(error)
    }
}
```

#### `Tests/JackpotNetworkingTests/APIProblemTests.swift`

The envelope's exact shape. These matter more than they look — problem decoding is `try?`, so a field rename on the backend is completely silent.

```swift
import XCTest
@testable import JackpotNetworking

/// The API's envelope is `{ "code": 0, "message": "Error message" }`.
///
/// These matter more than they look: the client decodes problems with `try?` so a gateway's
/// HTML body can't throw. That means a *shape* mismatch is completely silent — no crash, no
/// log, just permanently empty error messages in the UI. These tests are the only thing
/// standing between a backend field rename and that failure.
final class APIProblemTests: XCTestCase {

    private func decode(_ json: String) -> APIProblem? {
        try? JSONDecoder().decode(APIProblem.self, from: Data(json.utf8))
    }

    func testTheDocumentedShape() {
        XCTAssertEqual(decode(#"{"code":0,"message":"Error message"}"#),
                       APIProblem(code: 0, message: "Error message"))
    }

    func testNonZeroCode() {
        XCTAssertEqual(decode(#"{"code":1042,"message":"Mobile already registered"}"#)?.code, 1042)
    }

    /// Tolerated so a backend switching to string codes can't silently break every message.
    func testStringCodeIsCoerced() {
        XCTAssertEqual(decode(#"{"code":"42","message":"x"}"#)?.code, 42)
    }

    func testMessageOnly() {
        XCTAssertEqual(decode(#"{"message":"Just a message"}"#),
                       APIProblem(code: nil, message: "Just a message"))
    }

    func testCodeOnly() {
        XCTAssertEqual(decode(#"{"code":7}"#), APIProblem(code: 7, message: nil))
    }

    // MARK: Things that are *not* a problem envelope

    func testEmptyObjectIsNotAProblem() {
        XCTAssertNil(decode("{}"), "an empty body is 'the server said nothing', not an empty complaint")
    }

    func testEmptyMessageIsTreatedAsAbsent() {
        XCTAssertNil(decode(#"{"message":""}"#))
    }

    func testUnrelatedJSONIsNotAProblem() {
        XCTAssertNil(decode(#"{"data":{"id":1}}"#))
    }

    func testHTMLFromAGatewayIsNotAProblem() {
        XCTAssertNil(decode("<html><body>503</body></html>"))
    }

    func testExtraFieldsAreIgnored() {
        XCTAssertEqual(decode(#"{"code":3,"message":"m","traceId":"abc","status":400}"#),
                       APIProblem(code: 3, message: "m"))
    }
}
```

---

## Building `JackpotLocalization`

`JackpotAppData` (one file) then `JackpotLocalization` (four). `Translations` itself is
Foundation-only.

#### `Sources/JackpotLocalization/Translations.swift`

The table itself: normalised once, region cascade, error-code lookup. A value type, so it can be injected, compared and swapped per preview.

```swift
import Foundation

/// The app's localisation table, fetched once per session from the app-data endpoint.
///
/// Replaces this, which was a free function reaching into a global:
///
/// ```swift
/// func getTranslation(Key: String, regional: Bool = false) -> String {
///     let region = GlobalData.shareData.AppSetupData.wmsNavigationRegionCode.lowercased()
///     let locale = GlobalData.shareData.configData?.locale
///     let lowercasedLocale = locale?.reduce(into: [String: String]()) { result, pair in
///         result[pair.key.lowercased()] = pair.value      // ← rebuilt on EVERY call
///     } ?? [:]
///     …
/// }
/// ```
///
/// Three things wrong with that, in order of cost:
///
/// 1. **It rebuilt the whole lowercased dictionary on every lookup.** The real table has
///    hundreds of entries. One registration form asks for ~36 strings per render pass
///    (12 fields × label + placeholder + validation message), so that's ~36 full dictionary
///    rebuilds to draw one screen — and it gets worse inside a scrolling list. Here the table
///    is normalised **once**, at construction.
/// 2. **It reached into `GlobalData` twice**, so nothing that called it could be tested or
///    previewed, and every caller was coupled to the god object.
/// 3. **It was global**, so there was no way to have a second table — no previews with fixed
///    copy, no per-test isolation, no swapping locale without mutating shared state.
///
/// This is a value type: injected, comparable, and cheap to pass around.
public struct Translations: Sendable, Equatable {

    private let table: [String: String]
    /// Lowercased region code, e.g. `"jza"`. Nil when the app has no region yet.
    public let regionSuffix: String?

    public init(_ locales: [String: String] = [:], regionCode: String? = nil) {
        self.table = Dictionary(
            locales.lazy.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let trimmed = regionCode?.trimmingCharacters(in: .whitespaces).lowercased()
        self.regionSuffix = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    public var isEmpty: Bool { table.isEmpty }
    public var count: Int { table.count }

    /// Looks up `key`, preferring a region-specific override.
    ///
    /// Cascade: `key-<region>` → `key` → nil.
    ///
    /// Region-first is the default here, where the old function made it opt-in per call site.
    /// A `-jza` variant only exists because someone wanted it used, and requiring every caller
    /// to remember `regional: true` means the ones that forget silently show the wrong copy.
    /// Pass `regional: false` to force the plain key.
    public func string(forKey key: String, regional: Bool = true) -> String? {
        let normalized = key.lowercased()
        if regional, let regionSuffix, let regional = table["\(normalized)-\(regionSuffix)"] {
            return regional
        }
        return table[normalized]
    }

    /// Resolved string, falling back to the key itself so a missing translation is visible in
    /// QA rather than rendering as an empty label.
    public func callAsFunction(_ key: String, regional: Bool = true) -> String {
        string(forKey: key, regional: regional) ?? key
    }

    public subscript(key: String) -> String {
        callAsFunction(key)
    }

    // MARK: Typed keys

    /// Type-safe lookup for the enums the app already declares
    /// (`FixedJackpotTranslationsKeys`, `ProgressiveJackpotTranslationsKeys`, …).
    /// Conform them to `LocalizationKey` and they work unchanged — see that protocol.
    public func callAsFunction(_ key: some LocalizationKey, regional: Bool = true) -> String {
        callAsFunction(key.localizationKey, regional: regional)
    }

    public subscript(key: some LocalizationKey) -> String {
        callAsFunction(key.localizationKey)
    }

    // MARK: Error codes
    //
    // The table doubles as an error-code catalogue — the app-data response contains entries
    // like "6000328": "Maximum OTP tries reached, …". So a `code` in an API error envelope is
    // a localisation key, and this is how a server error becomes a sentence a player can read
    // in their own language.

    public func message(forErrorCode code: Int) -> String? {
        string(forKey: String(code), regional: false)
    }

}
```

#### `Sources/JackpotLocalization/LocalizationKey.swift`

Lets the app's existing string-backed key enums be used directly, with an empty conformance.

```swift
import Foundation

/// Anything that names a row in the localisation table.
///
/// The app already declares its keys as string-backed enums:
///
/// ```swift
/// enum FixedJackpotTranslationsKeys: String {
///     case startsIn = "jpc-fixed-jackpots-starts-in"
///     case cityJackpots = "city-jackpots"
/// }
/// ```
///
/// Those were good — the raw strings were already centralised. What they lacked was a way to
/// *use* them without going through the global function. Add the conformance and nothing else
/// changes:
///
/// ```swift
/// extension FixedJackpotTranslationsKeys: LocalizationKey {}
///
/// label.text = translations(FixedJackpotTranslationsKeys.startsIn)
/// ```
///
/// The `RawRepresentable` default below means the conformance is genuinely empty.
public protocol LocalizationKey {
    var localizationKey: String { get }
}

public extension LocalizationKey where Self: RawRepresentable, RawValue == String {
    var localizationKey: String { rawValue }
}
```

#### `Sources/JackpotAppData/AppData.swift`

The bootstrap endpoint and a response type that decodes **one section at a time**. See the note above on why that matters. Its own target: reading the payload is not a localisation concern — every feature reads its own section from it.

```swift
import Foundation
import JackpotNetworking

/// The once-per-session bootstrap call:
///
///     GET https://config.jpc.africa/cron/app-data/{region}/{platform}/{tenant}/{locale}?api-version=1.0
///     GET .../cron/app-data/JZA/IOS/synapse/en-US?api-version=1.0
///
/// Note this is a **different service and version** from the forms endpoint
/// (`/crm/forms/...` at `api-version=2.0`) on the same host — the response advertises
/// `api-supported-versions: 1.0,2.0`. Two services, one gateway, so the version belongs to the
/// request rather than to a single shared environment.
public struct AppDataRequest: APIEndpoint {
    let region: String
    let platform: String
    let tenant: String
    let locale: String

    public init(region: String, platform: String = "IOS", tenant: String, locale: String) {
        self.region = region
        self.platform = platform
        self.tenant = tenant
        self.locale = locale
    }

    public var path: String { "cron/app-data/\(region)/\(platform)/\(tenant)/\(locale)" }
    public var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "1.0")] }
    public var requiresAuth: Bool { false }
}

/// One response, decoded a section at a time.
///
/// The payload carries six unrelated things — `appsettings`, `wmsconfig`, `registration`,
/// `redirects`, `sitemaps`, `locales` — owned by six different parts of the app. Two ways to
/// model that, and only one of them survives contact with a CMS:
///
/// **The single-struct version** (what the app does today) puts every section in one
/// `Decodable` and decodes them together. It has two failure modes:
///
/// - Any section using non-optional `decode` takes the **whole response** with it when that
///   key is null. The app's `ConfigData` does exactly this for `locales`, so a CMS edit that
///   nulls the strings also loses app settings, sitemaps, redirects and registration — none
///   of which have anything to do with copy.
/// - It becomes the next god object. Every feature that needs a slice adds a property, and
///   nothing can be extracted afterwards.
///
/// **This version** splits the top-level keys up front and hands each one out on request. One
/// network call, six independent decodes, and a malformed `wmsconfig` cannot stop `locales`
/// from loading. `section(_:as:)` returns nil rather than throwing, because a section this
/// build doesn't understand is not a reason to fail the ones it does.
public struct AppDataResponse: Sendable, Equatable {

    private let sections: [String: Data]

    public init(data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppDataError.notAnObject
        }
        sections = object.reduce(into: [:]) { result, pair in
            // A null section is the same as an absent one.
            guard !(pair.value is NSNull) else { return }
            guard let data = try? JSONSerialization.data(withJSONObject: pair.value,
                                                         options: [.fragmentsAllowed]) else { return }
            result[pair.key] = data
        }
    }

    /// Decodes one section, or nil if it's absent, null, or shaped differently than expected.
    /// Never throws: one feature's broken section must not break another's.
    public func section<T: Decodable>(_ key: String,
                                      as type: T.Type = T.self,
                                      decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = sections[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// Which sections actually arrived. Worth logging — it's how you notice the CMS has
    /// started returning null for something the app depends on.
    public var presentSections: [String] { sections.keys.sorted() }

    public func contains(_ key: String) -> Bool { sections[key] != nil }

    // MARK: Sections this module owns

    /// The `locales` table. Every other section belongs to whichever feature owns it —
    /// `wmsconfig` to app settings, `sitemaps` to navigation, `registration` to sign-up —
    /// and each decodes its own type from the same response.
    public var locales: [String: String] {
        section("locales") ?? [:]
    }
}

public enum AppDataError: Error, Equatable {
    case notAnObject
}
```

#### `Sources/JackpotLocalization/TranslationsRepository.swift`

Fetches the payload through `JackpotAppData` and keeps the `locales` section.

```swift
import Foundation
import JackpotNetworking
import JackpotAppData

public protocol TranslationsRepository: Sendable {
    func translations(region: String, tenant: String, locale: String) async throws -> Translations
}

public struct RemoteTranslationsRepository: TranslationsRepository {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) {
        self.apiClient = apiClient
    }

    /// Fetches the whole bootstrap payload and keeps only the strings. Other features can
    /// fetch the same endpoint and keep their own section, or — better once more than one
    /// feature needs it — one caller fetches `AppDataResponse` and hands it round.
    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        let data = try await apiClient.requestData(
            AppDataRequest(region: region, tenant: tenant, locale: locale)
        )
        return Translations(try AppDataResponse(data: data).locales, regionCode: region)
    }
}

/// Fixed table, for previews and tests.
public struct StubTranslationsRepository: TranslationsRepository {
    private let table: Translations

    public init(_ table: Translations) {
        self.table = table
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        table
    }
}
```

#### `Sources/JackpotLocalization/TranslationsStore.swift`

Owns the table for the life of the session. Created by the composition root and injected — deliberately not a singleton.

`adopt(_:)` is the migration seam: the legacy app already pulls app-data into `GlobalData.shareData.configData?.locale`, so hand that dictionary over in one call rather than fetching it twice during the transition.

```swift
import Foundation
import Combine

/// Owns the session's translation table.
///
/// `Translations` is a value type with no home; something has to hold it for the life of the
/// session. This is that something — and, deliberately, **not** a singleton: it is created by
/// the composition root and injected, so tests and previews can have their own.
///
/// `ObservableObject` rather than `@Observable` because JackpotCore targets iOS 15. When the app
/// moves to 17 the change is mechanical — see the migration notes in the README.
@MainActor
public final class TranslationsStore: ObservableObject {

    @Published public private(set) var translations = Translations()
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: (any Error)?

    private let repository: any TranslationsRepository
    private var loadTask: Task<Void, Never>?

    public init(repository: any TranslationsRepository) {
        self.repository = repository
    }

    /// Whether the table has arrived. Screens can render placeholder copy until it has.
    public var isLoaded: Bool { !translations.isEmpty }

    /// Fetches once per session. Coalesced: concurrent callers share one request.
    public func load(region: String, tenant: String, locale: String) {
        guard loadTask == nil else { return }
        isLoading = true
        loadTask = Task { [weak self] in
            defer {
                self?.loadTask = nil
                self?.isLoading = false
            }
            guard let self else { return }
            do {
                self.translations = try await repository.translations(region: region, tenant: tenant, locale: locale)
                self.lastError = nil
            } catch is CancellationError {
            } catch {
                // A missing table is degraded, not fatal: every lookup falls back to its key,
                // so the app stays usable and QA can see which strings are missing.
                self.lastError = error
            }
        }
    }

    /// Adopts a table someone else fetched.
    ///
    /// This is the incremental-adoption seam. The legacy app already pulls app-data into
    /// `GlobalData.shareData.configData?.locale`; rather than fetching it twice during the
    /// migration, hand the existing dictionary over:
    ///
    /// ```swift
    /// translationsStore.adopt(
    ///     Translations(GlobalData.shareData.configData?.locale ?? [:],
    ///                  regionCode: GlobalData.shareData.AppSetupData.wmsNavigationRegionCode)
    /// )
    /// ```
    ///
    /// One call, at the point the legacy fetch completes. Nothing else in the old code changes.
    public func adopt(_ translations: Translations) {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        self.translations = translations
    }


    public func clear() {
        loadTask?.cancel()
        loadTask = nil
        translations = Translations()
    }

    deinit { loadTask?.cancel() }
}
```

#### `Tests/JackpotLocalizationTests/TranslationsTests.swift`

Lookup, case-insensitivity, the region cascade including a pre-suffixed key, error codes, the typed-enum path, and the performance guard.

```swift
import XCTest
@testable import JackpotLocalization

/// Keys and values below are taken from the real app-data response.
final class TranslationsTests: XCTestCase {

    private let sample = Translations([
        "6000328": "Maximum OTP tries reached, Please contact support on +233 30 825 5838",
        "markets.windrawwin": "1X2",
        "new-site": "New Site",
        "select-password-reset-method": "Select Password Reset Method",
        "jpc-fixed-jackpots-starts-in": "Starts in",
        "city-jackpots": "City Jackpots",
        "receivePromotionalInformation": "Send me promotions",
        "receivePromotionalInformation-jza": "Send Jackpot City Promotions to me",
    ], regionCode: "JZA")

    // MARK: Lookup

    func testResolvesAKey() {
        XCTAssertEqual(sample("new-site"), "New Site")
        XCTAssertEqual(sample("markets.windrawwin"), "1X2")
    }

    /// The old function lowercased both sides on every call; the table is normalised once now,
    /// but the behaviour has to be identical.
    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(sample("NEW-SITE"), "New Site")
        XCTAssertEqual(sample("New-Site"), "New Site")
    }

    /// A missing key renders as itself — visible in QA, rather than an empty label.
    func testMissingKeyFallsBackToTheKey() {
        XCTAssertEqual(sample("no-such-key"), "no-such-key")
        XCTAssertNil(sample.string(forKey: "no-such-key"))
    }

    // MARK: Region cascade

    func testRegionalVariantWinsWhenItExists() {
        XCTAssertEqual(sample("receivePromotionalInformation"),
                       "Send Jackpot City Promotions to me")
    }

    func testPlainKeyUsedWhenNoRegionalVariantExists() {
        XCTAssertEqual(sample("new-site"), "New Site")
    }

    func testRegionalLookupCanBeForcedOff() {
        XCTAssertEqual(sample("receivePromotionalInformation", regional: false),
                       "Send me promotions")
    }

    /// The CRM sometimes hands us a key that already carries the region suffix — the
    /// registration schema's `fieldLabel` is literally `receivePromotionalInformation-jza`.
    /// Looking that up must not double-suffix into a miss.
    func testAPreSuffixedKeyStillResolves() {
        XCTAssertEqual(sample("receivePromotionalInformation-jza"),
                       "Send Jackpot City Promotions to me")
    }

    func testNoRegionMeansNoRegionalLookup() {
        let noRegion = Translations(["a-jza": "regional", "a": "plain"], regionCode: nil)
        XCTAssertEqual(noRegion("a"), "plain")
        XCTAssertNil(noRegion.regionSuffix)
    }

    func testBlankRegionIsTreatedAsAbsent() {
        XCTAssertNil(Translations(["a": "b"], regionCode: "   ").regionSuffix)
    }

    // MARK: Error codes

    /// The table doubles as an error-code catalogue, which is what ties an API error envelope
    /// (`{"code": 6000328, …}`) to a sentence in the player's language.
    func testErrorCodeResolvesToItsMessage() {
        XCTAssertEqual(sample.message(forErrorCode: 6000328),
                       "Maximum OTP tries reached, Please contact support on +233 30 825 5838")
    }

    func testUnknownErrorCodeIsNil() {
        XCTAssertNil(sample.message(forErrorCode: 999))
    }

    /// A numeric code must never pick up the region suffix — "6000328-jza" isn't a thing.
    func testErrorCodeLookupIgnoresRegion() {
        let table = Translations(["123": "plain", "123-jza": "regional"], regionCode: "JZA")
        XCTAssertEqual(table.message(forErrorCode: 123), "plain")
    }

    // MARK: Typed keys — the app's existing enums work unchanged

    func testStringBackedEnumsResolveWithAnEmptyConformance() {
        enum FixedJackpotTranslationsKeys: String, LocalizationKey {
            case startsIn = "jpc-fixed-jackpots-starts-in"
            case cityJackpots = "city-jackpots"
        }
        XCTAssertEqual(sample(FixedJackpotTranslationsKeys.startsIn), "Starts in")
        XCTAssertEqual(sample[FixedJackpotTranslationsKeys.cityJackpots], "City Jackpots")
    }

    // MARK: Housekeeping

    func testEmptyTable() {
        let empty = Translations()
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty("anything"), "anything")
    }


    /// Guards the fix for the real bug: the old implementation rebuilt the whole lowercased
    /// dictionary inside every lookup. Normalising once is what this asserts — 50k lookups
    /// against a 2k-row table finish in well under a second.
    func testLookupIsConstantTimeNotAFullTableRebuild() {
        let big = Translations(
            Dictionary(uniqueKeysWithValues: (0..<2_000).map { ("key-\($0)", "value-\($0)") }),
            regionCode: "jza"
        )
        let started = Date()
        for index in 0..<50_000 {
            _ = big("KEY-\(index % 2_000)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.0)
    }
}
```

#### `Tests/JackpotLocalizationTests/TranslationsStoreTests.swift`

Coalesced loading, the `adopt` migration seam, merging, and the important one — a failed fetch leaves the app usable, because every lookup falls back to its key.

```swift
import XCTest
@testable import JackpotLocalization

@MainActor
final class TranslationsStoreTests: XCTestCase {

    private func store(_ table: Translations = Translations(["a": "A"], regionCode: "jza"),
                       delay: TimeInterval = 0) -> TranslationsStore {
        TranslationsStore(repository: SpyRepository(table, delay: delay))
    }

    func testStartsEmptyAndUnloaded() {
        let store = store()
        XCTAssertFalse(store.isLoaded)
        XCTAssertTrue(store.translations.isEmpty)
    }

    func testLoadPopulatesTheTable() async throws {
        let store = store()
        store.load(region: "JZA", tenant: "synapse", locale: "en-US")
        try await waitUntil { store.isLoaded }
        XCTAssertEqual(store.translations("a"), "A")
    }

    /// Once per session means once: concurrent callers must not each fire a request.
    func testConcurrentLoadsAreCoalesced() async throws {
        let spy = SpyRepository(Translations(["a": "A"]), delay: 0.05)
        let store = TranslationsStore(repository: spy)
        for _ in 0..<5 { store.load(region: "JZA", tenant: "synapse", locale: "en-US") }
        try await waitUntil { store.isLoaded }
        let calls = await spy.callCount
        XCTAssertEqual(calls, 1)
    }

    /// The migration path: the legacy app already fetched this, so don't fetch it twice.
    func testAdoptTakesATableFetchedElsewhere() {
        let store = store()
        store.adopt(Translations(["legacy-key": "From GlobalData"], regionCode: "jza"))
        XCTAssertTrue(store.isLoaded)
        XCTAssertEqual(store.translations("legacy-key"), "From GlobalData")
    }


    /// A failed fetch must degrade, not break: lookups fall back to their keys so the app
    /// stays usable and the gaps are visible.
    func testFailureLeavesTheAppUsable() async throws {
        struct Boom: Error {}
        let store = TranslationsStore(repository: FailingRepository(Boom()))
        store.load(region: "JZA", tenant: "synapse", locale: "en-US")
        try await waitUntil { store.lastError != nil }
        XCTAssertFalse(store.isLoaded)
        XCTAssertEqual(store.translations("some-key"), "some-key")
    }

    func testClearResets() {
        let store = store()
        store.adopt(Translations(["a": "A"]))
        store.clear()
        XCTAssertFalse(store.isLoaded)
    }

    // MARK: Helpers

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("timed out") }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

private actor SpyRepository: TranslationsRepository {
    private let table: Translations
    private let delay: TimeInterval
    private(set) var callCount = 0

    init(_ table: Translations, delay: TimeInterval = 0) {
        self.table = table
        self.delay = delay
    }

    func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        callCount += 1
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        return table
    }
}

private struct FailingRepository: TranslationsRepository {
    let error: any Error
    init(_ error: any Error) { self.error = error }
    func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        throw error
    }
}
```

#### `Tests/JackpotAppDataTests/AppDataResponseTests.swift`

Section independence in both directions: a malformed `wmsconfig` doesn't cost you the strings, and null `locales` doesn't cost you the other five sections.

```swift
import XCTest
@testable import JackpotAppData
import JackpotNetworking

/// The bootstrap payload carries six unrelated sections owned by six parts of the app. These
/// assert that one section can never take down another — which is the failure the app's
/// current `ConfigData` has, because it decodes `locales` with non-optional `decode` while
/// every other section uses `decodeIfPresent`.
final class AppDataResponseTests: XCTestCase {

    private func response(_ json: String) throws -> AppDataResponse {
        try AppDataResponse(data: Data(json.utf8))
    }

    // MARK: The real shape

    func testDecodesLocalesFromTheRealPayloadShape() throws {
        let payload = try response(#"""
        {
          "appsettings": null, "wmsconfig": null, "registration": null,
          "redirects": null, "sitemaps": null,
          "locales": { "new-site": "New Site", "6000328": "Maximum OTP tries reached" }
        }
        """#)
        XCTAssertEqual(payload.locales["new-site"], "New Site")
        XCTAssertEqual(payload.presentSections, ["locales"])
    }

    /// A null section is the same as an absent one, and neither is an error.
    func testNullSectionsAreTreatedAsAbsent() throws {
        let payload = try response(#"{ "locales": {"a":"A"}, "sitemaps": null }"#)
        XCTAssertFalse(payload.contains("sitemaps"))
        XCTAssertTrue(payload.contains("locales"))
    }

    // MARK: Independence — the point of the type

    struct WMSConfig: Decodable, Equatable { let regionCode: String? }

    func testSectionsDecodeIndependently() throws {
        let payload = try response(#"""
        { "wmsconfig": { "regionCode": "JZA" }, "locales": { "a": "A" } }
        """#)
        XCTAssertEqual(payload.section("wmsconfig", as: WMSConfig.self), WMSConfig(regionCode: "JZA"))
        XCTAssertEqual(payload.locales, ["a": "A"])
    }

    /// The bug this design exists to prevent: today, one bad section loses all six.
    func testAMalformedSectionDoesNotCostYouTheOthers() throws {
        let payload = try response(#"""
        { "wmsconfig": "this should have been an object", "locales": { "a": "A" } }
        """#)
        XCTAssertNil(payload.section("wmsconfig", as: WMSConfig.self))
        XCTAssertEqual(payload.locales, ["a": "A"], "a broken wmsconfig must not lose the strings")
    }

    /// The mirror image, and the one that actually bites: today `locales` is decoded with
    /// non-optional `decode`, so nulling it throws and takes appsettings, sitemaps, redirects
    /// and registration down with it.
    func testMissingLocalesDoesNotCostYouTheOtherSections() throws {
        let payload = try response(#"""
        { "wmsconfig": { "regionCode": "JZA" }, "sitemaps": { "sitemap": [] }, "locales": null }
        """#)
        XCTAssertEqual(payload.locales, [:], "no strings — degraded, not fatal")
        XCTAssertEqual(payload.section("wmsconfig", as: WMSConfig.self), WMSConfig(regionCode: "JZA"))
        XCTAssertTrue(payload.contains("sitemaps"))
    }

    /// A section this build has never heard of must not be an error — the CMS adds them
    /// without an app release.
    func testUnknownSectionsAreIgnoredButVisible() throws {
        let payload = try response(#"{ "locales": {"a":"A"}, "somethingNew": { "x": 1 } }"#)
        XCTAssertEqual(payload.presentSections, ["locales", "somethingNew"])
        XCTAssertEqual(payload.locales, ["a": "A"])
    }

    // MARK: Malformed input

    func testNonObjectPayloadThrows() {
        XCTAssertThrowsError(try response("[1,2,3]")) { error in
            XCTAssertEqual(error as? AppDataError, .notAnObject)
        }
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try response("<html>502</html>"))
    }

    func testEmptyObjectYieldsNoSections() throws {
        let payload = try response("{}")
        XCTAssertTrue(payload.presentSections.isEmpty)
        XCTAssertEqual(payload.locales, [:])
    }

    // MARK: Endpoint

    func testBuildsTheURLFromTheCurlCommand() throws {
        let request = try AppDataRequest(region: "JZA", tenant: "synapse", locale: "en-US")
            .urlRequest(in: .init(baseURL: URL(string: "https://config.jpc.africa")!))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://config.jpc.africa/cron/app-data/JZA/IOS/synapse/en-US?api-version=1.0")
    }

    /// Bootstrap runs before login.
    func testBootstrapDoesNotRequireAuth() {
        XCTAssertFalse(AppDataRequest(region: "JZA", tenant: "synapse", locale: "en-US").requiresAuth)
    }
}
```

**✓ Final checkpoint**

```bash
swift test        # Executed 66 tests, with 0 failures
```

**✓ Checkpoint**

```bash
swift test --filter JackpotNetworkingTests     # Executed 34 tests, with 0 failures
```

---

## `JackpotLocalization`

The app fetches its copy once per session:

```
GET https://config.jpc.africa/cron/app-data/JZA/IOS/synapse/en-US?api-version=1.0
```

```json
{
  "appsettings": null, "wmsconfig": null, "registration": null,
  "redirects": null, "sitemaps": null,
  "locales": {
    "6000328": "Maximum OTP tries reached, Please contact support on +233 30 825 5838",
    "markets.windrawwin": "1X2",
    "new-site": "New Site",
    "select-password-reset-method": "Select Password Reset Method"
  }
}
```

Note this is a **different service and version** from the forms endpoint (`/crm/forms/…` at
`api-version=2.0`) on the same host — the response advertises `api-supported-versions: 1.0,2.0`.
Two services, one gateway, so the version belongs to the request rather than to a shared
environment constant.

### What it replaces

```swift
func getTranslation(Key: String, regional: Bool = false) -> String {
    let region = GlobalData.shareData.AppSetupData.wmsNavigationRegionCode.lowercased()
    let locale = GlobalData.shareData.configData?.locale
    let lowercasedLocale = locale?.reduce(into: [String: String]()) { result, pair in
        result[pair.key.lowercased()] = pair.value      // ← rebuilt on EVERY call
    } ?? [:]
    let value = lowercasedLocale[regionalKey] ?? lowercasedLocale[normalizedKey] ?? Key
    return value
}
```

Three problems, in order of cost:

1. **It rebuilt the whole lowercased dictionary on every lookup.** The real table has hundreds
   of entries. One registration form asks for ~36 strings per render pass (12 fields × label +
   placeholder + validation message), so that's ~36 full dictionary rebuilds to draw one screen
   — and far worse inside a scrolling list. `Translations` normalises **once**, at construction.
   `testLookupIsConstantTimeNotAFullTableRebuild` guards it.
2. **It reached into `GlobalData` twice**, so nothing that called it could be tested or
   previewed, and every caller inherited the god object.
3. **It was global**, so there was no second table — no previews with fixed copy, no per-test
   isolation, no swapping locale without mutating shared state.

### Using it

One store, created at your composition root and injected:

```swift
let store = TranslationsStore(repository: RemoteTranslationsRepository(apiClient: client))
store.load(region: "JZA", tenant: "synapse", locale: "en-US")   // coalesced

let translations = store.translations

translations("new-site")                        // "New Site"
translations["select-password-reset-method"]    // "Select Password Reset Method"
translations.message(forErrorCode: 6000328)     // the OTP message
```

**Region cascade:** `key-<region>` → `key` → the key itself. Region-first is the default, where
the old function made it opt-in per call site — a `-jza` variant only exists because someone
wanted it used, and requiring every caller to remember `regional: true` means the ones that
forget silently show the wrong copy. Pass `regional: false` to force the plain key.

**A missing key renders as itself**, so a gap is visible in QA rather than an empty label.

### Your existing key enums work unchanged

```swift
extension FixedJackpotTranslationsKeys: LocalizationKey {}   // that's the whole conformance

label.text = translations(FixedJackpotTranslationsKeys.startsIn)
```

The enums were already the good part of the old code — the raw strings were centralised. What
they lacked was a way to *use* them without going through the global.

### Adopting it in the existing app

The legacy app already fetches app-data into `GlobalData.shareData.configData?.locale`. Don't
fetch it twice during the migration — hand the dictionary over:

```swift
store.adopt(
    Translations(GlobalData.shareData.configData?.locale ?? [:],
                 regionCode: GlobalData.shareData.AppSetupData.wmsNavigationRegionCode)
)
```

Then reimplement the free function as a shim, which fixes the rebuild-per-lookup bug for the
**whole app** without touching a single call site:

```swift
@available(*, deprecated, message: "Inject TranslationsStore and call translations(key)")
@MainActor
func getTranslation(Key: String, regional: Bool = false) -> String {
    // `regional` passed through as given, not defaulted to true, so existing call sites
    // return exactly what they did before.
    LegacyDependencies.translations.translations(Key, regional: regional)
}
```

The deprecation turns every remaining call site into a compiler warning — an always-accurate
burn-down list. Full sequence in the JackpotForms README, Part 10.

### One response, six owners

The bootstrap payload isn't just strings. It carries six unrelated sections:

```json
{ "appsettings": …, "wmsconfig": …, "registration": …,
  "redirects": …, "sitemaps": …, "locales": … }
```

`wmsconfig` alone holds countries, cultures, currencies, verticals, feature flags, channels,
`regionCode`, licence and more. Six sections, owned by six different parts of the app.

`AppDataResponse` splits the top-level keys up front and hands each one out on request:

```swift
let response = try AppDataResponse(data: bytes)

response.locales                                    // this module owns this one
response.section("wmsconfig", as: WMSConfig.self)   // app settings owns this one
response.section("sitemaps", as: Sitemaps.self)     // navigation owns this one
response.presentSections                            // what actually arrived — worth logging
```

One network call, six independent decodes, and `section(_:as:)` returns nil rather than
throwing.

**Why not one `Decodable` struct with six properties?** That's what the app does today, and it
has two failure modes:

1. **A section decoded with non-optional `decode` takes the whole response with it.** The app's
   `ConfigData` does exactly this:

   ```swift
   let locale: [String: String]                                        // non-optional
   self.locale = try container.decode([String: String].self, forKey: .locale)   // not decodeIfPresent
   ```

   Every *other* section uses `decodeIfPresent`. So a CMS edit that nulls `locales` doesn't
   just lose the copy — it throws, and app settings, sitemaps, redirects and registration are
   lost with it. And that endpoint demonstrably does return nulls for sections.

2. **It becomes the next god object.** Every feature that needs a slice adds a property, and
   nothing can be extracted afterwards.

`testMissingLocalesDoesNotCostYouTheOtherSections` and
`testAMalformedSectionDoesNotCostYouTheOthers` guard both directions.

### The table is also an error-code catalogue

`"6000328": "Maximum OTP tries reached, …"` is an entry in `locales`. So a numeric `code` in an
API error envelope (`{ "code": 0, "message": "…" }`) is a localisation key, and
`message(forErrorCode:)` is what turns a server rejection into a sentence in the player's own
language — better than `problem.message`, which arrives in whatever language the API defaulted
to.
