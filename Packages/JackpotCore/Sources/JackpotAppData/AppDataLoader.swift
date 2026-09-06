import Foundation
import JackpotNetworking

/// Where a payload came from. The app renders a skeleton only for `.none`.
public enum AppDataOrigin: Sendable, Equatable {
    /// No usable payload yet — first ever launch, or the cache was beyond `maxStale`.
    case none
    /// Served from disk. `age` is how old it is.
    case cache(age: TimeInterval)
    case network
}

public struct AppDataSnapshot: Sendable {
    public let response: AppDataResponse
    public let origin: AppDataOrigin

    public init(response: AppDataResponse, origin: AppDataOrigin) {
        self.response = response
        self.origin = origin
    }
}

/// How long a cached payload may be served for.
///
/// Two numbers, because "cached" and "trusted" are different questions:
///
/// - `refreshAfter` — serve the cache immediately but revalidate in the background. Zero means
///   always revalidate, which is the right default: revalidation is a 304 with an empty body.
/// - `maxStale` — beyond this, do **not** render from cache. Wait for the network and show a
///   skeleton.
///
/// ⚠️ `maxStale` is a product decision, not a technical one, and the payload's sections do not
/// all tolerate staleness equally:
///
/// | Section | Stale consequence |
/// |---|---|
/// | `locales` | wrong copy; self-corrects; harmless |
/// | `redirects` | a dead link |
/// | `sitemaps` | navigation offers a removed vertical, or misses a new one |
/// | `wmsconfig` (feature flags, verticals, licence) | **a game or provider disabled for compliance still appears** |
///
/// The default below is deliberately conservative for that last row. Raise it only with someone
/// who owns the compliance answer.
public struct AppDataStalenessPolicy: Sendable, Equatable {
    public let refreshAfter: TimeInterval
    public let maxStale: TimeInterval

    public init(refreshAfter: TimeInterval = 0, maxStale: TimeInterval = 60 * 60 * 12) {
        self.refreshAfter = refreshAfter
        self.maxStale = maxStale
    }

    /// Always revalidate; render from cache up to twelve hours old.
    public static let `default` = AppDataStalenessPolicy()

    /// Never render from cache. Every launch waits for the network — what the app does today.
    public static let alwaysFresh = AppDataStalenessPolicy(refreshAfter: 0, maxStale: 0)
}

/// Loads the bootstrap payload, cache first.
///
/// Stale-while-revalidate: return whatever is on disk immediately so the app can render, then
/// revalidate in the background and publish an update if the server has something newer.
///
/// The launch sequence this produces:
///
/// - **first ever launch** — no cache; `.none`, skeleton, one round trip
/// - **every launch after** — cache hit, zero-latency render, background 304 (empty body)
/// - **config changed** — cache hit, zero-latency render, background 200, UI updates in place
/// - **offline** — cache hit, zero-latency render, revalidation fails silently and is ignored
///
/// A failed revalidation never surfaces. Config is not worth blocking a launch for when a
/// perfectly good payload is already on disk.
public actor AppDataLoader {

    private let apiClient: any ApiClient
    private let cache: any AppDataCaching
    private let policy: AppDataStalenessPolicy
    private let now: @Sendable () -> Date

    public init(apiClient: any ApiClient,
                cache: any AppDataCaching,
                policy: AppDataStalenessPolicy = .default,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.apiClient = apiClient
        self.cache = cache
        self.policy = policy
        self.now = now
    }

    /// Whatever can be served right now, without waiting for the network.
    ///
    /// Returns nil when there is no cache, or the cache is beyond `maxStale` — the only two
    /// cases where the app should show a skeleton.
    public func cached(region: String, tenant: String, locale: String) -> AppDataSnapshot? {
        let key = Self.key(region: region, tenant: tenant, locale: locale)
        guard let entry = cache.load(key: key) else { return nil }
        let age = entry.age(now: now())
        guard age <= policy.maxStale else { return nil }
        guard let response = try? AppDataResponse(data: entry.data) else { return nil }
        return AppDataSnapshot(response: response, origin: .cache(age: age))
    }

    /// Revalidates against the server. Returns nil when the server says nothing changed, so a
    /// caller can skip republishing identical state.
    @discardableResult
    public func refresh(region: String, tenant: String, locale: String) async throws -> AppDataSnapshot? {
        let key = Self.key(region: region, tenant: tenant, locale: locale)
        let entry = cache.load(key: key)
        let validators = entry?.validators.map { HTTPValidators(etag: $0.etag, lastModified: $0.lastModified) }

        let result = try await apiClient.requestConditional(
            AppDataRequest(region: region, tenant: tenant, locale: locale),
            validators: validators
        )

        switch result {
        case .notModified:
            // Re-stamp so the entry ages from the last time we confirmed it, not from the last
            // time the content happened to change.
            if let entry {
                cache.store(entry.data, validators: entry.validators, key: key)
            }
            return nil

        case .fresh(let data, let validators):
            let response = try AppDataResponse(data: data)
            cache.store(data, validators: validators.map { HTTPValidatorsBox(etag: $0.etag, lastModified: $0.lastModified) }, key: key)
            return AppDataSnapshot(response: response, origin: .network)
        }
    }

    /// Cache if usable, otherwise wait for the network. What a cold launch calls.
    public func load(region: String, tenant: String, locale: String) async throws -> AppDataSnapshot {
        if let snapshot = cached(region: region, tenant: tenant, locale: locale) {
            return snapshot
        }
        guard let fresh = try await refresh(region: region, tenant: tenant, locale: locale) else {
            throw AppDataError.notAnObject
        }
        return fresh
    }

    public func clear(region: String, tenant: String, locale: String) {
        cache.clear(key: Self.key(region: region, tenant: tenant, locale: locale))
    }

    static func key(region: String, tenant: String, locale: String) -> String {
        "\(region)-\(tenant)-\(locale)".lowercased()
    }
}
