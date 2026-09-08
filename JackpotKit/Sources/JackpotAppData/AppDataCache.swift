import Foundation
import JackpotNetworking

public struct CachedAppData: Sendable, Equatable {
    public let data: Data
    public let validators: HTTPValidators?
    public let storedAt: Date

    public init(data: Data, validators: HTTPValidators?, storedAt: Date) {
        self.data = data
        self.validators = validators
        self.storedAt = storedAt
    }

    public func age(now: Date = .now) -> TimeInterval {
        now.timeIntervalSince(storedAt)
    }
}

public protocol AppDataCaching: Sendable {
    func load(key: String) -> CachedAppData?
    func store(_ data: Data, validators: HTTPValidators?, key: String)
    func clear(key: String)
}

/// The last good payload, kept indefinitely in Application Support. Not `URLCache`: its five-minute
/// `max-age` is a CDN knob, useless for launches hours apart; the caller decides how stale is too stale.
public struct FileAppDataCache: AppDataCaching {
    private let directory: URL

    public init(directory: URL? = nil) {
        let manager = FileManager.default
        self.directory = directory ?? ((try? manager.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("JackpotAppData", isDirectory: true)
        try? manager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private func payloadURL(_ key: String) -> URL { directory.appendingPathComponent("\(key).json") }
    private func metaURL(_ key: String) -> URL { directory.appendingPathComponent("\(key).meta.json") }

    public func load(key: String) -> CachedAppData? {
        let payload = payloadURL(key)
        guard let data = try? Data(contentsOf: payload),
              let attributes = try? FileManager.default.attributesOfItem(atPath: payload.path),
              let storedAt = attributes[.modificationDate] as? Date
        else { return nil }
        let validators = (try? Data(contentsOf: metaURL(key)))
            .flatMap { try? JSONDecoder().decode(HTTPValidators.self, from: $0) }
        return CachedAppData(data: data, validators: validators, storedAt: storedAt)
    }

    public func store(_ data: Data, validators: HTTPValidators?, key: String) {
        // Atomic: a half-written payload on next launch is worse than none.
        try? data.write(to: payloadURL(key), options: .atomic)
        if let validators, let encoded = try? JSONEncoder().encode(validators) {
            try? encoded.write(to: metaURL(key), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: metaURL(key))
        }
    }

    public func clear(key: String) {
        try? FileManager.default.removeItem(at: payloadURL(key))
        try? FileManager.default.removeItem(at: metaURL(key))
    }
}

/// For tests and previews.
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

    public func store(_ data: Data, validators: HTTPValidators?, key: String) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = CachedAppData(data: data, validators: validators, storedAt: clock())
    }

    public func clear(key: String) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = nil
    }

    public func seed(_ data: Data, validators: HTTPValidators? = nil, key: String, storedAt: Date) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = CachedAppData(data: data, validators: validators, storedAt: storedAt)
    }
}
