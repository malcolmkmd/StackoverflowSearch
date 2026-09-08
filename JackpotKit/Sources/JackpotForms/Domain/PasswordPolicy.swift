import Foundation

/// One rule in the "Password Validity" panel, already judged against the current password.
public struct PasswordRule: Equatable, Sendable {
    public let description: String
    public let isSatisfied: Bool
}

/// The schema gives password one regex, `^(.){8,20}$`, and the design shows two rules, so the
/// `{min,max}` quantifier is parsed. Registration only.
public enum PasswordPolicy {
    public static func rules(for field: FormField, password: String) -> [PasswordRule] {
        guard let bounds = lengthBounds(in: field.regex) else { return [] }
        return [
            PasswordRule(description: "Minimum of \(bounds.lowerBound) characters",
                         isSatisfied: password.count >= bounds.lowerBound),
            PasswordRule(description: "Maximum of \(bounds.upperBound) characters",
                         isSatisfied: !password.isEmpty && password.count <= bounds.upperBound),
        ]
    }

    static func lengthBounds(in pattern: String?) -> ClosedRange<Int>? {
        guard let pattern,
              let expression = try? NSRegularExpression(pattern: #"\{(\d+),(\d+)\}"#),
              let match = expression.firstMatch(in: pattern, range: NSRange(pattern.startIndex..., in: pattern)),
              let minRange = Range(match.range(at: 1), in: pattern),
              let maxRange = Range(match.range(at: 2), in: pattern),
              let minimum = Int(pattern[minRange]), let maximum = Int(pattern[maxRange]),
              minimum <= maximum
        else { return nil }
        return minimum...maximum
    }
}
