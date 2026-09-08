import Foundation

/// One rule in the "Password Validity" panel.
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

/// The schema gives password one regex, `^(.){8,20}$`, and the design shows two rules, so the
/// `{min,max}` quantifier is parsed. Registration only.
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
