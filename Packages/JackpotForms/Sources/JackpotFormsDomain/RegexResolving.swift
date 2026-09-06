import Foundation

/// Dropdown options in the schema carry a `regex` that is sometimes a pattern
/// (`"[a-zA-Z]"` on sourceOfFunds) and sometimes a *name* (`"idNumberRegex"`,
/// `"passportNumberRegex"` on idNumberType). A name has to resolve to a pattern
/// somewhere; this protocol is that somewhere.
///
/// ⚠️ OPEN QUESTION for the backend team — see the guide, "Open questions". Confirm
/// whether a named regex on an option is meant to (a) validate the option itself, or
/// (b) *replace* the regex of a dependent field. The registration UI strongly implies
/// (b): choosing "South African ID" vs "Passport" changes what a valid ID Number is,
/// and the ID Number field's own regex is `^[0-9]{13}$`, which is SA-ID-specific.
/// `DynamicFormModel` implements (b) behind `dependentRegexOverrides`; flip it off
/// with `FormDependencies.appliesOptionRegexToDependentField = false`.
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

    /// ⚠️ **These patterns are invented.** The schema references `idNumberRegex` and
    /// `passportNumberRegex` by *name*; it never sends the patterns, and we haven't been told
    /// where they live. `idNumberRegex` is safe — it matches the `idNumber` field's own regex
    /// in the schema (`^[0-9]{13}$`), which is the SA ID format. **`passportNumberRegex` is a
    /// guess.**
    ///
    /// It is deliberately permissive. The two failure modes are not symmetric:
    ///
    /// - too strict → a real passport is rejected client-side and the user cannot register at
    ///   all, with no way to appeal;
    /// - too loose → the server rejects it and the user sees a message and retries.
    ///
    /// The server validates either way, so erring loose costs a round trip and erring strict
    /// costs a registration. Replace this the moment the real pattern is known — see
    /// `docs/OPEN-QUESTIONS.md` Q4b.
    public static let jpcDefaults = RegexCatalog(patterns: [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^[a-zA-Z0-9]{5,20}$",
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
