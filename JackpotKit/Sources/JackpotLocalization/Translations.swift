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
        string(forKey: "jpc-reg-error.\(code)", regional: false)
            ?? string(forKey: String(code), regional: false)
    }

}
