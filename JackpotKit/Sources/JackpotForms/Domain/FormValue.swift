import Foundation

/// Every case renders as a string because the schema validates with regexes, `^true$` for checkboxes included.
public enum FormValue: Equatable, Hashable, Sendable {
    case empty
    case text(String)
    case bool(Bool)
    case option(String)
    case date(Date)

    public var stringValue: String {
        switch self {
        case .empty:            return ""
        case .text(let s):      return s
        case .bool(let b):      return b ? "true" : "false"
        case .option(let v):    return v
        case .date(let d):      return FormValue.iso8601.format(d)
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .empty:         return true
        case .text(let s):   return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .option(let v): return v.isEmpty
        // An unticked required checkbox counts as empty, which is what makes `terms` work.
        case .bool(let b):   return !b
        case .date:          return false
        }
    }

    public var boolValue: Bool {
        if case .bool(let b) = self { return b }
        return false
    }

    public var dateValue: Date? {
        if case .date(let d) = self { return d }
        return nil
    }

    /// The `dateOfBirth` regex expects an ISO-8601 date-time: `1990-01-01T00:00:00Z`.
    public static let iso8601 = Date.ISO8601FormatStyle()
}

/// What the host receives on submit and what the submit endpoint expects; encoding lives in `Remote`.
public struct FormSubmission: Equatable, Sendable {
    public let formId: String
    public let formCodeName: FormName
    public let submittedAt: Date
    public let values: [String: FormValue]

    public init(formCodeName: FormName,
                values: [String: FormValue],
                formId: String = "",
                submittedAt: Date = Date()) {
        self.formId = formId
        self.formCodeName = formCodeName
        self.submittedAt = submittedAt
        self.values = values
    }

    public subscript(identifier: String) -> FormValue {
        values[identifier] ?? .empty
    }
}
