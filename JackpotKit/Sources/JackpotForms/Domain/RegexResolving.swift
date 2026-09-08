import Foundation

/// Dropdown options in the schema carry a `regex` that is sometimes a pattern (`"[a-zA-Z]"` on
/// sourceOfFunds) and sometimes the *name* of one (`"idNumberRegex"` on idNumberType). A name
/// has to resolve to a pattern somewhere; this protocol is that somewhere.
///
/// Named regexes *replace* the dependent field's rule: choosing "South African ID" vs
/// "Passport" changes what a valid ID Number is. `DynamicFormModel` applies that, gated on
/// `FormDependencies.appliesOptionRegexToDependentField`.
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

    /// Named option regexes that redirect onto a dependent field. `passportNumberRegex` is a
    /// **length** rule, not a character class: any 5–20 characters.
    public static let jpcDefaults = RegexCatalog(patterns: [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ])
}

public extension String {
    /// Tells a regex *pattern* from a regex *name*. A bare identifier has no metacharacters;
    /// a real pattern almost always does.
    var looksLikeRegexPattern: Bool {
        let metacharacters = CharacterSet(charactersIn: "^$[]{}()|*+?\\.")
        return rangeOfCharacter(from: metacharacters) != nil
    }
}
