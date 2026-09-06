import Foundation

/// The schema ships localization *keys*, not display text: `fieldLabel` is "username",
/// dropdown text is "jpc-reg-idnumber", `validationMessage` is "regex". The rendered UI
/// shows "Enter Mobile Number", "South African ID", "Enter in a valid ID number", so a
/// string catalogue resolves them somewhere.
///
/// ⚠️ OPEN QUESTION: every field carries the *same* `validationMessage` value ("regex")
/// yet the UI shows per-field messages. The key is therefore almost certainly composed,
/// something like `jpc-reg-{fieldIdentifier}-{validationMessage}`. `ComposedKeyLocalizer`
/// implements that guess and is a one-line change once the backend confirms the format.
public protocol FormLocalizing: Sendable {
    func string(forKey key: String) -> String?

    /// Copy for a server error code, when the localisation table carries one.
    ///
    /// The app-data response contains entries keyed by error code — `6000328` maps to the
    /// max-OTP-tries message — so a numeric `code` in an API error envelope is a localisation
    /// key. Defaulted to nil so an implementation that has no such table (bundled placeholder
    /// copy, previews) doesn't have to care.
    func message(forErrorCode code: Int) -> String?
}

public extension FormLocalizing {
    func message(forErrorCode code: Int) -> String? { nil }

    /// Resolve, or fall back to a humanised version of the key so nothing renders blank.
    func display(_ key: String) -> String {
        string(forKey: key) ?? key.humanisedKey
    }

    func validationMessage(for field: FormField) -> String {
        let composed = "jpc-reg-\(field.identifier)-\(field.validationMessageKey)"
        if let resolved = string(forKey: composed) { return resolved }
        if let resolved = string(forKey: field.validationMessageKey) { return resolved }
        return "Please enter a valid \(field.identifier.humanisedKey.lowercased())"
    }
}

/// Looks up an in-memory table, then a bundle's `.strings`. Good enough for the demo
/// and for production once the table is fed from the CRM strings endpoint.
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
    /// "jpc-reg-idnumber" → "Idnumber";  "firstname" → "Firstname";  "dateOfBirth" → "Date Of Birth"
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

/// Wraps any `(key) -> String?` as a localizer.
///
/// This is how the app hands the form engine its *existing* `getTranslation` during the
/// migration, without either package knowing the other exists:
///
/// ```swift
/// ClosureLocalizer { key in
///     let value = getTranslation(Key: key)
///     return value == key ? nil : value      // getTranslation returns the key on a miss
/// }
/// ```
///
/// That last line matters. `FormLocalizing` uses `nil` to mean "unresolved" so the engine
/// can fall back to humanised copy; without mapping key-on-miss back to `nil`, a missing
/// string renders as the raw key ("username") instead of a readable label.
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
