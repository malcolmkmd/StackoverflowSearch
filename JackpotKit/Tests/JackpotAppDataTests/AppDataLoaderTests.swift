import XCTest
@testable import JackpotAppData
import JackpotNetworking

final class AppDataLoaderTests: XCTestCase {

    private let payload = #"{"locales":{"new-site":"New Site"},"wmsconfig":{"regionCode":"JZA"}}"#
    private let updated = #"{"locales":{"new-site":"Newer Site"}}"#

    private func loader(_ client: SpyClient,
                        cache: InMemoryAppDataCache = InMemoryAppDataCache(),
                        policy: AppDataStalenessPolicy = .default,
                        now: @escaping @Sendable () -> Date = { .now }) -> AppDataLoader {
        AppDataLoader(apiClient: client, cache: cache, policy: policy, now: now)
    }

    // MARK: Cold launch

    func testFirstEverLaunchHasNothingToServe() async {
        let sut = loader(SpyClient(.fresh(Data(), nil)))
        let snapshot = await sut.cached(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertNil(snapshot, "no cache → the app shows a skeleton")
    }

    func testFirstEverLaunchFetchesAndCaches() async throws {
        let cache = InMemoryAppDataCache()
        let client = SpyClient(.fresh(Data(payload.utf8), HTTPValidators(etag: "v1", lastModified: nil)))
        let sut = loader(client, cache: cache)

        let snapshot = try await sut.load(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertEqual(snapshot.origin, .network)
        XCTAssertEqual(snapshot.response.locales, ["new-site": "New Site"])
        XCTAssertNotNil(cache.load(key: "jza-synapse-en-us"))
    }

    // MARK: Warm launch — the whole point

    func testSecondLaunchServesFromCacheWithoutWaiting() async throws {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8), key: "jza-synapse-en-us", storedAt: Date())
        let client = SpyClient(.notModified)
        let sut = loader(client, cache: cache)

        let snapshot = await sut.cached(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertEqual(snapshot?.response.locales, ["new-site": "New Site"])
        guard case .cache = snapshot?.origin else { return XCTFail("expected .cache") }
        XCTAssertEqual(client.calls, 0, "rendering must not touch the network")
    }

    func testRevalidationSendsTheStoredValidators() async throws {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8),
                   validators: HTTPValidators(etag: "v1", lastModified: "Fri, 04 Sep 2026 15:53:27 GMT"),
                   key: "jza-synapse-en-us", storedAt: Date())
        let client = SpyClient(.notModified)
        let sut = loader(client, cache: cache)

        _ = try await sut.refresh(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertEqual(client.sentValidators?.etag, "v1")
        XCTAssertEqual(client.sentValidators?.lastModified, "Fri, 04 Sep 2026 15:53:27 GMT")
    }

    /// 304 means "what you have is current" — nothing to republish.
    func testNotModifiedReturnsNil() async throws {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8), key: "jza-synapse-en-us", storedAt: Date())
        let sut = loader(SpyClient(.notModified), cache: cache)
        let result = try await sut.refresh(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertNil(result)
    }

    func testChangedConfigReplacesTheCache() async throws {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8), key: "jza-synapse-en-us", storedAt: Date())
        let sut = loader(SpyClient(.fresh(Data(updated.utf8), nil)), cache: cache)

        let result = try await sut.refresh(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertEqual(result?.response.locales, ["new-site": "Newer Site"])

        let reread = await loader(SpyClient(.notModified), cache: cache)
            .cached(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertEqual(reread?.response.locales, ["new-site": "Newer Site"])
    }

    // MARK: Staleness

    func testCacheBeyondMaxStaleIsNotServed() async {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8), key: "jza-synapse-en-us",
                   storedAt: Date(timeIntervalSinceNow: -60 * 60 * 13))
        let sut = loader(SpyClient(.notModified), cache: cache, policy: .default)
        let snapshot = await sut.cached(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertNil(snapshot, "13h old against a 12h budget → skeleton, wait for the network")
    }

    func testAZeroMaxStalePolicyNeverServesCache() async {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8), key: "jza-synapse-en-us", storedAt: Date())
        let policy = AppDataStalenessPolicy(maxStale: 0)
        let sut = loader(SpyClient(.notModified), cache: cache, policy: policy,
                         now: { Date(timeIntervalSinceNow: 1) })
        let snapshot = await sut.cached(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertNil(snapshot)
    }

    /// A 304 re-stamps the entry: it ages from the last time we confirmed it, not from the last
    /// time the content happened to change. Otherwise a config nobody edits for a fortnight
    /// would fall out of the staleness budget while being perfectly current.
    func testNotModifiedRestampsTheCache() async throws {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8), key: "jza-synapse-en-us",
                   storedAt: Date(timeIntervalSinceNow: -60 * 60 * 11))
        let sut = loader(SpyClient(.notModified), cache: cache)

        _ = try await sut.refresh(region: "JZA", tenant: "synapse", locale: "en-US")

        let age = cache.load(key: "jza-synapse-en-us")!.age()
        XCTAssertLessThan(age, 5, "re-stamped to now")
    }

    // MARK: Failure

    /// A config fetch must never brick a launch when a good payload is already on disk.
    func testRevalidationFailureLeavesTheCacheIntact() async {
        let cache = InMemoryAppDataCache()
        cache.seed(Data(payload.utf8), key: "jza-synapse-en-us", storedAt: Date())
        let sut = loader(SpyClient(.failure(APIError.transport(.notConnectedToInternet))), cache: cache)

        do {
            _ = try await sut.refresh(region: "JZA", tenant: "synapse", locale: "en-US")
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? APIError, .transport(.notConnectedToInternet))
        }
        let snapshot = await sut.cached(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertEqual(snapshot?.response.locales, ["new-site": "New Site"])
    }

    func testMalformedCacheIsIgnoredRatherThanCrashing() async {
        let cache = InMemoryAppDataCache()
        cache.seed(Data("<html>oops</html>".utf8), key: "jza-synapse-en-us", storedAt: Date())
        let sut = loader(SpyClient(.notModified), cache: cache)
        let snapshot = await sut.cached(region: "JZA", tenant: "synapse", locale: "en-US")
        XCTAssertNil(snapshot)
    }

    func testCacheKeyIsScopedToRegionTenantAndLocale() {
        XCTAssertEqual(AppDataLoader.key(region: "JZA", tenant: "synapse", locale: "en-US"), "jza-synapse-en-us")
        XCTAssertNotEqual(AppDataLoader.key(region: "JZA", tenant: "synapse", locale: "en-US"),
                          AppDataLoader.key(region: "JGH", tenant: "synapse", locale: "en-US"))
    }
}

// MARK: - Doubles

private final class SpyClient: ApiClient, @unchecked Sendable {
    enum Outcome {
        case notModified
        case fresh(Data, HTTPValidators?)
        case failure(any Error)
    }

    private let outcome: Outcome
    private(set) var calls = 0
    private(set) var sentValidators: HTTPValidators?

    init(_ outcome: Outcome) { self.outcome = outcome }

    func requestConditional(_ endpoint: some APIEndpoint,
                            validators: HTTPValidators?) async throws -> ConditionalResponse {
        calls += 1
        sentValidators = validators
        switch outcome {
        case .notModified:            return .notModified
        case .fresh(let d, let v):    return .fresh(d, v)
        case .failure(let error):     throw error
        }
    }

    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response {
        throw APIError.unexpectedStatus(404, nil)
    }
    func request(_ endpoint: some APIEndpoint) async throws { throw APIError.unexpectedStatus(404, nil) }
    func requestData(_ endpoint: some APIEndpoint) async throws -> Data { throw APIError.unexpectedStatus(404, nil) }
}
