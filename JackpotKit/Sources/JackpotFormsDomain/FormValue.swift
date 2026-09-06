import Foundation

/// A field's current value.
///
/// Every case renders as a string because the schema validates with regexes — including the
/// checkboxes, whose patterns are literally `^true$`. `stringValue` is therefore both what
/// gets validated and what gets submitted.
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
        case .date(let d):      return FormValue.iso8601.string(from: d)
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
        return stringValue.lowercased() == "true"
    }

    public var dateValue: Date? {
        switch self {
        case .date(let d): return d
        case .text(let s): return FormValue.iso8601.date(from: s)
        default:           return nil
        }
    }

    /// The `dateOfBirth` regex in the schema expects an ISO-8601 date-time with
    /// optional fractional seconds and offset, so that is what we emit.
    public static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

/// What the host receives in the submit callback, and what the cron submit endpoint expects.
/// Encoding lives in `JackpotFormsRemote` so this type stays free of JSON key names.
public struct FormSubmission: Equatable, Sendable {
    public let formId: String
    public let formCodeName: FormName
    public let submittedAt: Date
    public let values: [String: FormValue]
    public let metadata: [String: String]?

    public init(formCodeName: FormName,
                values: [String: FormValue],
                formId: String = "",
                submittedAt: Date = Date(),
                metadata: [String: String]? = nil) {
        self.formId = formId
        self.formCodeName = formCodeName
        self.submittedAt = submittedAt
        self.values = values
        self.metadata = metadata
    }

    public subscript(identifier: String) -> FormValue {
        values[identifier] ?? .empty
    }

    /// Flat string payload, for hosts that want one. The real submit body uses `values`,
    /// because fields are typed on the wire (bool stays bool, empty becomes null).
    public var stringValues: [String: String] {
        values.mapValues(\.stringValue)
    }
}
