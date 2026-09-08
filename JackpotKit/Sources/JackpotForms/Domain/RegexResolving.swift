import Foundation

/// A dropdown option's `regex` is sometimes a pattern and sometimes the name of one; names resolve here
/// and replace the dependent field's rule.
public protocol RegexResolving: Sendable {
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

    /// `passportNumberRegex` is a length rule, not a character class.
    public static let jpcDefaults = RegexCatalog(patterns: [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ])
}

public extension String {
    /// A bare identifier has no metacharacters; a real pattern almost always does.
    var looksLikeRegexPattern: Bool {
        let metacharacters = CharacterSet(charactersIn: "^$[]{}()|*+?\\.")
        return rangeOfCharacter(from: metacharacters) != nil
    }
}
