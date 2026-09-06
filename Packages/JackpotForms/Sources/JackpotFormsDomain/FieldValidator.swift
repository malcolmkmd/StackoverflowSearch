import Foundation

public enum ValidationResult: Equatable, Sendable {
    case valid
    /// Localization key for the message to show, plus the field it belongs to.
    case invalid(messageKey: String)

    public var isValid: Bool { self == .valid }
}

/// Validates a value against a field's schema rules.
///
/// Two things make this less trivial than it looks:
///  1. The regexes come from a server, so they can be malformed. `NSRegularExpression`
///     throws on a bad pattern — if that propagated, one CRM typo would crash signup.
///     A pattern that will not compile is treated as "no constraint", and reported.
///  2. Compiling a pattern on every keystroke, for every field, is wasteful. Compiled
///     expressions are cached by pattern string.
public struct FieldValidator: Sendable {
    private let regexResolver: any RegexResolving
    private let cache = RegexCache()

    public init(regexResolver: any RegexResolving = RegexCatalog.jpcDefaults) {
        self.regexResolver = regexResolver
    }

    /// - Parameter overrideRegex: pattern that replaces `field.regex`, used when a
    ///   dropdown selection changes a dependent field's rule (ID type → ID number).
    public func validate(_ value: FormValue,
                         against field: FormField,
                         overrideRegex: String? = nil) -> ValidationResult {
        guard field.carriesValue, !field.isReadOnly else { return .valid }

        if field.isRequired, value.isEmpty {
            return .invalid(messageKey: field.validationMessageKey)
        }

        // An empty optional field has nothing left to check. Note some schema regexes
        // permit empty explicitly (referralCode: `...|^$`), but not all do, so this
        // guard is what keeps optional fields genuinely optional.
        if !field.isRequired, value.isEmpty { return .valid }

        guard let pattern = resolvedPattern(overrideRegex ?? field.regex), !pattern.isEmpty else {
            return .valid
        }

        guard let expression = cache.expression(for: pattern) else {
            // Malformed server pattern: do not block the user on our inability to
            // compile it. Surfaced via `invalidPatterns` for diagnostics.
            return .valid
        }

        let subject = value.stringValue
        let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
        let matched = expression.firstMatch(in: subject, options: [], range: range) != nil
        return matched ? .valid : .invalid(messageKey: field.validationMessageKey)
    }

    /// Pattern for a dropdown option's `regex`, resolving names via the catalogue.
    public func optionPattern(_ raw: String?) -> String? {
        resolvedPattern(raw)
    }

    private func resolvedPattern(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if let named = regexResolver.pattern(named: raw) { return named }
        return raw.looksLikeRegexPattern ? raw : nil
    }

    /// Patterns in this form that will not compile — worth logging in debug.
    public func invalidPatterns(in form: FormSchema) -> [String] {
        form.allFields.compactMap { field in
            guard let pattern = resolvedPattern(field.regex), !pattern.isEmpty else { return nil }
            return cache.expression(for: pattern) == nil ? pattern : nil
        }
    }
}

/// Thread-safe compiled-regex cache.
private final class RegexCache: @unchecked Sendable {
    private var storage: [String: NSRegularExpression?] = [:]
    private let lock = NSLock()

    func expression(for pattern: String) -> NSRegularExpression? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = storage[pattern] { return cached }
        let compiled = try? NSRegularExpression(pattern: pattern)
        storage[pattern] = compiled
        return compiled
    }
}
