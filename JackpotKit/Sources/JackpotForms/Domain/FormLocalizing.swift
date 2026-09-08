import Foundation

/// The schema ships localisation keys, not text; something has to resolve them.
public protocol FormLocalizing: Sendable {
    func string(forKey key: String) -> String?

    /// Copy for a server error code, when the table carries one.
    func message(forErrorCode code: Int) -> String?
}

public extension FormLocalizing {
    func message(forErrorCode code: Int) -> String? { nil }

    /// Resolves, or humanises the key so nothing renders blank.
    func display(_ key: String) -> String {
        string(forKey: key) ?? key.humanisedKey
    }

    /// Every field carries `validationMessage: "regex"`, so the real key is composed: `jpc-reg-{identifier}-{key}`.
    func validationMessage(for field: FormField) -> String {
        let composed = "jpc-reg-\(field.identifier)-\(field.validationMessageKey)"
        if let resolved = string(forKey: composed) { return resolved }
        if let resolved = string(forKey: field.validationMessageKey) { return resolved }
        return "Please enter a valid \(field.identifier.humanisedKey.lowercased())"
    }
}

public extension String {
    /// "jpc-reg-idnumber" → "Idnumber"; "dateOfBirth" → "Date Of Birth".
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

/// Wraps any `(key) -> String?`. Return nil on a miss, not the key, or the engine cannot fall back.
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
