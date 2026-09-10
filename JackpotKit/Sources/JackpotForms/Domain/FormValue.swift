import Foundation

/// Every case renders as a string because the schema validates with regexes, `^true$` for checkboxes included.
public enum FormValue: Equatable, Hashable, Sendable {
    case empty
    case text(String)
    case bool(Bool)
    case date(Date)

    public var stringValue: String {
        switch self {
        case .empty:       return ""
        case .text(let s): return s
        case .bool(let b): return b ? "true" : "false"
        case .date(let d): return FormValue.iso8601.format(d)
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .empty:       return true
        case .text(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // An unticked required checkbox counts as empty, which is what makes `terms` work.
        case .bool(let b): return !b
        case .date:        return false
        }
    }

    public var boolValue: Bool { stringValue == "true" }

    public var dateValue: Date? {
        if case .date(let d) = self { return d }
        return nil
    }

    /// The `dateOfBirth` regex expects an ISO-8601 date-time: `1990-01-01T00:00:00Z`.
    public static let iso8601 = Date.ISO8601FormatStyle()
}

/// Untagged JSON: a string, a bare `true` / `false` for checkboxes, `null` for an empty value.
extension FormValue: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .empty:       try container.encodeNil()
        case .bool(let b): try container.encode(b)
        default:           try container.encode(stringValue)
        }
    }
}

/// Recaptcha is encoded as a sibling of `fields`, matching the web request body.
public struct FormSubmission: Equatable, Sendable, Encodable {
    public let formId: String
    public let formCodeName: FormName
    public let submittedAt: Date
    public let values: [String: FormValue]
    public let recaptcha: String?

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case formCodeName = "form_name"
        case submittedAt = "submitted_at"
        case values = "fields"
        case recaptcha
    }

    public init(formCodeName: FormName,
                values: [String: FormValue],
                recaptcha: String? = nil,
                formId: String = "",
                submittedAt: Date = Date()) {
        self.formId = formId
        self.formCodeName = formCodeName
        self.submittedAt = submittedAt
        self.values = values
        self.recaptcha = recaptcha
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formId, forKey: .formId)
        try container.encode(formCodeName, forKey: .formCodeName)
        try container.encode(submittedAt, forKey: .submittedAt)
        try container.encode(values, forKey: .values)
        try container.encodeIfPresent(recaptcha, forKey: .recaptcha)
    }

    public subscript(identifier: String) -> FormValue {
        values[identifier] ?? .empty
    }
}
