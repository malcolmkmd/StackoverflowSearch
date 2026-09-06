import Foundation

/// One rule shown in the "Password Validity" panel.
public struct PasswordRule: Identifiable, Equatable, Sendable {
    public let id: String
    public let description: String
    private let test: @Sendable (String) -> Bool

    public init(id: String, description: String, test: @escaping @Sendable (String) -> Bool) {
        self.id = id
        self.description = description
        self.test = test
    }

    public func isSatisfied(by password: String) -> Bool { test(password) }

    public static func == (lhs: PasswordRule, rhs: PasswordRule) -> Bool { lhs.id == rhs.id }
}

/// Supplies the checklist behind the password field.
///
/// The schema gives password a single regex, `^(.){8,20}$`, but the design shows two
/// independently ticking rules, which one regex match cannot produce. Parsing the `{min,max}`
/// quantifier reproduces the design for this form; see OPEN-QUESTIONS.
public protocol PasswordPolicyProviding: Sendable {
    func rules(for field: FormField) -> [PasswordRule]
}

public struct PasswordPolicy: PasswordPolicyProviding {
    public init() {}

    public func rules(for field: FormField) -> [PasswordRule] {
        let bounds = Self.lengthBounds(in: field.regex)
        var rules: [PasswordRule] = []

        if let minimum = bounds.min {
            rules.append(PasswordRule(id: "min",
                                      description: "Minimum of \(minimum) characters",
                                      test: { $0.count >= minimum }))
        }
        if let maximum = bounds.max {
            rules.append(PasswordRule(id: "max",
                                      description: "Maximum of \(maximum) characters",
                                      test: { !$0.isEmpty && $0.count <= maximum }))
        }
        return rules
    }

    /// Pulls `{8,20}` out of `^(.){8,20}$`.
    static func lengthBounds(in pattern: String?) -> (min: Int?, max: Int?) {
        guard let pattern,
              let expression = try? NSRegularExpression(pattern: #"\{(\d+),(\d+)\}"#),
              let match = expression.firstMatch(in: pattern, range: NSRange(pattern.startIndex..., in: pattern)),
              let minRange = Range(match.range(at: 1), in: pattern),
              let maxRange = Range(match.range(at: 2), in: pattern)
        else { return (nil, nil) }
        return (Int(pattern[minRange]), Int(pattern[maxRange]))
    }
}
