import Foundation

/// A bootstrap payload that was persisted, and when.
public struct CachedAppData: Sendable, Equatable {
    public let data: Data
    public let validators: HTTPValidatorsBox?
    public let storedAt: Date

    public init(data: Data, validators: HTTPValidatorsBox?, storedAt: Date) {
        self.data = data
        self.validators = validators
        self.storedAt = storedAt
    }

    public func age(now: Date = .now) -> TimeInterval {
        now.timeIntervalSince(storedAt)
    }
}

/// `HTTPValidators` lives in JackpotNetworking; this target stores it without depending on the
/// concrete type's module for persistence.
public struct HTTPValidatorsBox: Sendable, Equatable, Codable {
    public let etag: String?
    public let lastModified: String?

    public init(etag: String?, lastModified: String?) {
        self.etag = etag
        self.lastModified = lastModified
    }
}

public protocol AppDataCaching: Sendable {
    func load(key: String) -> CachedAppData?
    func store(_ data: Data, validators: HTTPValidatorsBox?, key: String)
    func clear(key: String)
}

/// Persists the last good payload to Application Support.
///
/// Not `URLCache`. The response advertises `cache-control: public, max-age=300`, which is a
/// CDN tuning knob — five minutes is right for the edge and useless for app launches, which are
/// usually hours apart. Honouring it as a client policy would mean a cache miss on essentially
/// every cold start. This store keeps the last good payload indefinitely and lets the caller
/// decide how stale is too stale.
public struct FileAppDataCache: AppDataCaching {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let base = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("JackpotAppData", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private func payloadURL(_ key: String) -> URL { directory.appendingPathComponent("\(key).json") }
    private func metaURL(_ key: String) -> URL { directory.appendingPathComponent("\(key).meta.json") }

    public func load(key: String) -> CachedAppData? {
        guard let data = try? Data(contentsOf: payloadURL(key)),
              let attributes = try? fileManager.attributesOfItem(atPath: payloadURL(key).path),
              let storedAt = attributes[.modificationDate] as? Date
        else { return nil }
        let validators = (try? Data(contentsOf: metaURL(key)))
            .flatMap { try? JSONDecoder().decode(HTTPValidatorsBox.self, from: $0) }
        return CachedAppData(data: data, validators: validators, storedAt: storedAt)
    }

    public func store(_ data: Data, validators: HTTPValidatorsBox?, key: String) {
        // Atomic: a half-written payload on next launch is worse than no payload.
        try? data.write(to: payloadURL(key), options: .atomic)
        if let validators, let encoded = try? JSONEncoder().encode(validators) {
            try? encoded.write(to: metaURL(key), options: .atomic)
        } else {
            try? fileManager.removeItem(at: metaURL(key))
        }
    }

    public func clear(key: String) {
        try? fileManager.removeItem(at: payloadURL(key))
        try? fileManager.removeItem(at: metaURL(key))
    }
}

/// In-memory, for tests and previews.
public final class InMemoryAppDataCache: AppDataCaching, @unchecked Sendable {
    private var entries: [String: CachedAppData] = [:]
    private let lock = NSLock()
    private let clock: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { .now }) {
        self.clock = now
    }

    public func load(key: String) -> CachedAppData? {
        lock.lock(); defer { lock.unlock() }
        return entries[key]
    }

    public func store(_ data: Data, validators: HTTPValidatorsBox?, key: String) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = CachedAppData(data: data, validators: validators, storedAt: clock())
    }

    public func clear(key: String) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = nil
    }

    public func seed(_ data: Data, validators: HTTPValidatorsBox? = nil, key: String, storedAt: Date) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = CachedAppData(data: data, validators: validators, storedAt: storedAt)
    }
}
