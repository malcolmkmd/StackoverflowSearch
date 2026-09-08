import Foundation

/// What component renders this field.
///
/// `unknown` is load-bearing: the schema is served from a CRM that product edits without
/// shipping an app build, so an unrecognised `fieldType` that threw would brick registration
/// for every installed version. Unknown fields are skipped and reported through
/// `DynamicFormModel.unsupportedFields` instead.
///
/// When the CRM starts serving a type this build should draw, add a case here and a view for it
/// in `FieldRenderer`; that switch is the whole contract.
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

/// Keyboard and formatting hint for `.input`.
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
        // The schema spells this "Calender". Accept both so a server-side fix
        // doesn't silently turn every date field into a plain text box.
        case "calender", "calendar", "date": self = .calendar
        case "phone", "tel":          self = .phone
        default:                      self = .unknown(raw)
        }
    }
}

public struct DropdownOption: Identifiable, Equatable, Hashable, Sendable {
    /// Submitted value, e.g. "SalaryOrWages".
    public let value: String
    /// Localisation key for the visible text, e.g. "jpc-reg-SalaryOrWages".
    public let textKey: String
    /// Either a regex pattern or the *name* of one — see `RegexResolving`.
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
    /// Key used for state, validation and the submitted payload, e.g. "idNumber".
    public let identifier: String
    /// Localisation key for the in-field label.
    public let labelKey: String
    public let type: FieldType
    public let inputType: InputType
    /// Localisation key for the validation failure message.
    public let validationMessageKey: String
    public let isRequired: Bool
    /// Hidden fields are neither rendered, validated nor submitted.
    public let isVisible: Bool
    public let isReadOnly: Bool
    /// Regex the value must match. Server-supplied, so it may be invalid — see `FieldValidator`.
    public let regex: String?
    public let prefix: String
    public let suffix: String
    public let dropdownOptions: [DropdownOption]

    /// Defaults are the schema's own: an unspecified field is an optional, visible, editable
    /// text input labelled by its identifier.
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
