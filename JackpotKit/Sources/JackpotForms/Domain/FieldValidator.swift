import Foundation

/// Regexes come from a server: one that will not compile is treated as no constraint, and compiled
/// expressions are cached by pattern.
public struct FieldValidator: Sendable {
    private let cache = RegexCache()

    public init() {}

    /// - Parameter overrideRegex: replaces `field.regex` when a dropdown selection changes a dependent field's rule.
    public func validate(_ value: FormValue, against field: FormField, overrideRegex: String? = nil) -> Bool {
        guard field.isVisible, !field.isReadOnly else { return true }
        // Not every optional field's regex permits empty; this is what keeps optional optional.
        if value.isEmpty { return !field.isRequired }
        guard let pattern = overrideRegex ?? field.regex, !pattern.isEmpty,
              let expression = cache.expression(for: pattern) else { return true }

        let subject = value.stringValue
        let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
        return expression.firstMatch(in: subject, options: [], range: range) != nil
    }
}

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
