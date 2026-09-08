import Foundation

/// `unknown` is load-bearing: the CRM edits the schema without an app release, so an unknown type is
/// skipped and reported through `unsupportedFields`, never fatal.
public enum FieldType: Equatable, Hashable, Sendable {
    case input
    case dropdown
    case checkbox
    case unknown(String)

    public init(raw: String) {
        switch raw.lowercased().replacingOccurrences(of: " ", with: "") {
        case "input":              self = .input
        case "dropdown", "select": self = .dropdown
        case "checkbox":           self = .checkbox
        default:                   self = .unknown(raw)
        }
    }
}

public enum InputType: Equatable, Hashable, Sendable {
    case text
    case number
    case password
    case email
    case calendar
    case phone
    case unknown(String)

    public init(raw: String) {
        switch raw.lowercased() {
        case "text":                  self = .text
        case "number", "numeric":     self = .number
        case "password":              self = .password
        case "email":                 self = .email
        // The schema spells it "Calender"; accept both.
        case "calender", "calendar", "date": self = .calendar
        case "phone", "tel":          self = .phone
        default:                      self = .unknown(raw)
        }
    }
}

public struct DropdownOption: Identifiable, Equatable, Hashable, Sendable {
    public let value: String
    public let textKey: String
    /// A pattern, or the name of one; see `FormDependencies.namedPatterns`.
    public let regex: String?

    public var id: String { value }

    public init(value: String, textKey: String, regex: String?) {
        self.value = value
        self.textKey = textKey
        self.regex = regex
    }
}

public struct FormField: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public let identifier: String
    public let labelKey: String
    public let type: FieldType
    public let inputType: InputType
    public let validationMessageKey: String
    public let isRequired: Bool
    /// Hidden fields are neither rendered, validated nor submitted.
    public let isVisible: Bool
    public let isReadOnly: Bool
    /// Server-supplied, so possibly invalid; see `FieldValidator`.
    public let regex: String?
    public let prefix: String
    public let suffix: String
    public let dropdownOptions: [DropdownOption]

    /// Defaults are the schema's own: an unspecified field is an optional, visible text input labelled by its identifier.
    public init(id: Int,
                identifier: String,
                labelKey: String? = nil,
                type: FieldType = .input,
                inputType: InputType = .text,
                validationMessageKey: String = "regex",
                isRequired: Bool = false,
                isVisible: Bool = true,
                isReadOnly: Bool = false,
                regex: String? = nil,
                prefix: String = "",
                suffix: String = "",
                dropdownOptions: [DropdownOption] = []) {
        self.id = id
        self.identifier = identifier
        self.labelKey = labelKey ?? identifier
        self.type = type
        self.inputType = inputType
        self.validationMessageKey = validationMessageKey
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isReadOnly = isReadOnly
        self.regex = regex
        self.prefix = prefix
        self.suffix = suffix
        self.dropdownOptions = dropdownOptions
    }

    public var isSecure: Bool { inputType == .password }
}
