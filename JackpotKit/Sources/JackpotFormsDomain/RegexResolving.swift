import Foundation

/// Dropdown options in the schema carry a `regex` that is sometimes a pattern
/// (`"[a-zA-Z]"` on sourceOfFunds) and sometimes a *name* (`"idNumberRegex"`,
/// `"passportNumberRegex"` on idNumberType). A name has to resolve to a pattern
/// somewhere; this protocol is that somewhere.
///
/// Named regexes *replace* the dependent field's rule. Choosing "South African ID" vs
/// "Passport" changes what a valid ID Number is. `DynamicFormModel` implements that behind
/// `dependentRegexOverrides`; flip it off with
/// `FormDependencies.appliesOptionRegexToDependentField = false`.
public protocol RegexResolving: Sendable {
    /// Pattern for a named regex, or nil if the name is unknown.
    func pattern(named name: String) -> String?
}

public struct RegexCatalog: RegexResolving {
    private let patterns: [String: String]

    public init(patterns: [String: String]) {
        self.patterns = patterns
    }

    public func pattern(named name: String) -> String? {
        patterns[name]
    }

    /// Named option regexes that redirect onto a dependent field.
    ///
    /// `idNumberRegex` matches the `idNumber` field's own schema regex (`^[0-9]{13}$`).
    /// `passportNumberRegex` is a **length** rule, not a character-class regex: any 5–20
    /// characters. Same idea as the password field's `^(.){8,20}$`.
    public static let jpcDefaults = RegexCatalog(patterns: [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ])
}

public extension String {
    /// Tells a regex *pattern* from a regex *name*.
    ///
    /// The schema uses both in the same place: `idNumberType`'s options carry
    /// `"idNumberRegex"` (a name, which redirects to another field's rule) while
    /// `sourceOfFunds`'s carry `"[a-zA-Z]"` (a literal pattern describing the selection
    /// itself). A bare identifier has no metacharacters; a real pattern almost always does.
    var looksLikeRegexPattern: Bool {
        let metacharacters = CharacterSet(charactersIn: "^$[]{}()|*+?\\.")
        return rangeOfCharacter(from: metacharacters) != nil
    }
}
