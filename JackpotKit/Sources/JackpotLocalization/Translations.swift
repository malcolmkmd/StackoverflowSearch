import Foundation

/// The app's localisation table, fetched once per session from the app-data endpoint.
///
/// Normalised to lowercase **once**, at construction: one registration form asks for ~36 strings
/// per render pass, and normalising per lookup would mean 36 full dictionary rebuilds to draw
/// one screen.
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

    /// Looks up `key`, cascading `key-<region>` → `key` → nil.
    ///
    /// Region-first by default: a `-jza` variant only exists because someone wanted it used,
    /// and making it opt-in per call site means the callers that forget show the wrong copy.
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

    /// The table doubles as an error-code catalogue: the app-data response carries entries
    /// like `"6000328": "Maximum OTP tries reached…"`, so a `code` in an API error envelope
    /// is a localisation key.
    public func message(forErrorCode code: Int) -> String? {
        string(forKey: "jpc-reg-error.\(code)", regional: false)
            ?? string(forKey: String(code), regional: false)
    }
}
