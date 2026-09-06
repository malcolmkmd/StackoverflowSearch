import Foundation

/// What component renders this field.
///
/// `unknown` is load-bearing, not defensive padding: the form schema is served from
/// a CRM that product edits without shipping an app build. If an unrecognised
/// `fieldType` threw, one CRM edit would brick registration for every installed
/// version. Unknown fields are skipped and reported instead — see
/// `DynamicFormModel.unsupportedFields`.
public enum FieldType: Equatable, Hashable, Sendable {
    case input
    case button
    case checkbox
    case radio
    case radioGroup
    case dropdown
    case divider
    case textArea
    case recaptchaV2
    case recaptchaV3
    case toggle
    case welcomeOffer
    case unknown(String)

    public init(raw: String) {
        switch raw.lowercased().replacingOccurrences(of: " ", with: "") {
        case "input":                    self = .input
        case "button":                   self = .button
        case "checkbox":                 self = .checkbox
        case "radio":                    self = .radio
        case "radiogroup":               self = .radioGroup
        case "dropdown", "select":       self = .dropdown
        case "divider":                  self = .divider
        case "textarea":                 self = .textArea
        case "recapchav2", "recaptchav2": self = .recaptchaV2
        case "recapchav3", "recaptchav3": self = .recaptchaV3
        case "toggle":                   self = .toggle
        case "welcomeoffer":             self = .welcomeOffer
        default:                         self = .unknown(raw)
        }
    }

    /// Layout-only types hold no value and are never validated or submitted.
    public var isDecorative: Bool {
        switch self {
        case .divider, .button: return true
        default:                return false
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
    /// Localization key for the visible text, e.g. "jpc-reg-SalaryOrWages".
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

public struct RadioOption: Identifiable, Equatable, Hashable, Sendable {
    public let value: String
    public let textKey: String

    public var id: String { value }

    public init(value: String, textKey: String) {
        self.value = value
        self.textKey = textKey
    }
}

public struct FormField: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    /// Key used for state, validation and the submitted payload. e.g. "idNumber".
    public let identifier: String
    public let name: String
    /// Localization key for the label.
    public let labelKey: String
    public let type: FieldType
    public let inputType: InputType
    public let textStyle: String
    /// Localization key for the validation failure message.
    public let validationMessageKey: String
    public let isRequired: Bool
    public let isVisible: Bool
    public let isReadOnly: Bool
    /// Regex the value must match. Server-supplied, so it may be invalid — see `FieldValidator`.
    public let regex: String?
    public let prefix: String
    public let suffix: String
    /// Localization key for the placeholder.
    public let placeholderKey: String
    public let dropdownOptions: [DropdownOption]
    public let radioOptions: [RadioOption]

    public init(id: Int, identifier: String, name: String, labelKey: String,
                type: FieldType, inputType: InputType, textStyle: String,
                validationMessageKey: String, isRequired: Bool, isVisible: Bool, isReadOnly: Bool,
                regex: String?, prefix: String, suffix: String, placeholderKey: String,
                dropdownOptions: [DropdownOption], radioOptions: [RadioOption]) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.labelKey = labelKey
        self.type = type
        self.inputType = inputType
        self.textStyle = textStyle
        self.validationMessageKey = validationMessageKey
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isReadOnly = isReadOnly
        self.regex = regex
        self.prefix = prefix
        self.suffix = suffix
        self.placeholderKey = placeholderKey
        self.dropdownOptions = dropdownOptions
        self.radioOptions = radioOptions
    }

    /// Fields that hold a value: rendered, validated and submitted.
    public var carriesValue: Bool {
        isVisible && !type.isDecorative && !(type == .recaptchaV2 || type == .recaptchaV3)
    }

    public var isSecure: Bool { inputType == .password }
}
