import Foundation

/// The schema ships localization *keys*, not display text: `fieldLabel` is "username", dropdown
/// text is "jpc-reg-idnumber", `validationMessage` is "regex". Something has to resolve them
/// against a string catalogue.
public protocol FormLocalizing: Sendable {
    func string(forKey key: String) -> String?

    /// Copy for a server error code, when the localisation table carries one.
    ///
    /// The app-data response contains entries keyed by error code, so a numeric `code` in an
    /// API error envelope is a localisation key. Defaulted to nil so an implementation with no
    /// such table doesn't have to care.
    func message(forErrorCode code: Int) -> String?
}

public extension FormLocalizing {
    func message(forErrorCode code: Int) -> String? { nil }

    /// Resolve, or fall back to a humanised version of the key so nothing renders blank.
    func display(_ key: String) -> String {
        string(forKey: key) ?? key.humanisedKey
    }

    /// Every field carries the same `validationMessage` ("regex") while the UI shows per-field
    /// copy, so the real key is composed: `jpc-reg-{fieldIdentifier}-{validationMessage}`. See
    /// OPEN-QUESTIONS; confirming the format is a one-line change here.
    func validationMessage(for field: FormField) -> String {
        let composed = "jpc-reg-\(field.identifier)-\(field.validationMessageKey)"
        if let resolved = string(forKey: composed) { return resolved }
        if let resolved = string(forKey: field.validationMessageKey) { return resolved }
        return "Please enter a valid \(field.identifier.humanisedKey.lowercased())"
    }
}

/// Looks up an in-memory table, then a bundle's `.strings`.
public struct ComposedKeyLocalizer: FormLocalizing {
    private let table: [String: String]
    private let bundle: Bundle?

    public init(table: [String: String] = [:], bundle: Bundle? = nil) {
        self.table = table
        self.bundle = bundle
    }

    public func string(forKey key: String) -> String? {
        if let value = table[key] { return value }
        guard let bundle else { return nil }
        let value = bundle.localizedString(forKey: key, value: "\u{0}", table: nil)
        return value == "\u{0}" ? nil : value
    }
}

public extension String {
    /// "jpc-reg-idnumber" → "Idnumber";  "dateOfBirth" → "Date Of Birth"
    var humanisedKey: String {
        var working = self
        if let range = working.range(of: "jpc-reg-") { working.removeSubrange(range) }
        working = working.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")

        var spaced = ""
        for character in working {
            if character.isUppercase, !spaced.isEmpty, spaced.last != " " { spaced.append(" ") }
            spaced.append(character)
        }
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}

/// Wraps any `(key) -> String?` as a localizer, so a host can hand the form engine its
/// existing translation function without either package knowing the other exists.
///
/// `FormLocalizing` uses nil to mean "unresolved" so the engine can fall back to humanised
/// copy. A host function that returns the key on a miss must map that back to nil, or a
/// missing string renders as the raw key.
public struct ClosureLocalizer: FormLocalizing {
    private let resolve: @Sendable (String) -> String?
    private let resolveCode: @Sendable (Int) -> String?

    public init(_ resolve: @escaping @Sendable (String) -> String?,
                errorCode resolveCode: @escaping @Sendable (Int) -> String? = { _ in nil }) {
        self.resolve = resolve
        self.resolveCode = resolveCode
    }

    public func string(forKey key: String) -> String? { resolve(key) }
    public func message(forErrorCode code: Int) -> String? { resolveCode(code) }
}
