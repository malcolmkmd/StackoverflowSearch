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
