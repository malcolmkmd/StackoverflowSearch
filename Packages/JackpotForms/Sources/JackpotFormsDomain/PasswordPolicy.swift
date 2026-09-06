import Foundation

/// One rule shown in the "Password Validity" panel.
public struct PasswordRule: Identifiable, Equatable, Sendable {
    public let id: String
    /// Localization key, with a plain-English fallback baked in for the demo.
    public let descriptionKey: String
    public let fallbackDescription: String
    private let test: @Sendable (String) -> Bool

    public init(id: String, descriptionKey: String, fallbackDescription: String,
                test: @escaping @Sendable (String) -> Bool) {
        self.id = id
        self.descriptionKey = descriptionKey
        self.fallbackDescription = fallbackDescription
        self.test = test
    }

    public func isSatisfied(by password: String) -> Bool { test(password) }

    public static func == (lhs: PasswordRule, rhs: PasswordRule) -> Bool { lhs.id == rhs.id }
}

/// Supplies the checklist behind the password field.
///
/// ⚠️ OPEN QUESTION: the schema gives password a single regex, `^(.){8,20}$`, but the
/// web UI shows two separate rules ("Minimum of 8 characters", "Maximum of 20
/// characters") with independent tick states and a strength bar. Those cannot both come
/// from one regex match. Either web parses the quantifier out of the pattern, or it has
/// its own rules config. The default below parses the `{min,max}` quantifier, which
/// reproduces the screenshots exactly for this form — but confirm with the web team.
public protocol PasswordPolicyProviding: Sendable {
    func rules(for field: FormField) -> [PasswordRule]
}

public struct PasswordPolicy: PasswordPolicyProviding {
    public init() {}

    public func rules(for field: FormField) -> [PasswordRule] {
        let bounds = Self.lengthBounds(in: field.regex)
        var rules: [PasswordRule] = []

        if let minimum = bounds.min {
            rules.append(PasswordRule(
                id: "min",
                descriptionKey: "jpc-reg-password-min",
                fallbackDescription: "Minimum of \(minimum) characters",
                test: { $0.count >= minimum }
            ))
        }
        if let maximum = bounds.max {
            rules.append(PasswordRule(
                id: "max",
                descriptionKey: "jpc-reg-password-max",
                fallbackDescription: "Maximum of \(maximum) characters",
                test: { !$0.isEmpty && $0.count <= maximum }
            ))
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
