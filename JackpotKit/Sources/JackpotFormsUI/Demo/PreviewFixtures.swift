#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// Hand-built fixtures mirroring the real registration schema.
///
/// Built in Swift rather than decoded from the bundled JSON on purpose: `JackpotFormsUI`
/// does not depend on `JackpotFormsData`, so it has no decoder — and previews that don't
/// touch the bundle render faster and can't fail on a missing resource. The JSON-backed
/// previews live in `JackpotForms`, which can see both layers.
public enum FormPreview {

    // MARK: Field builder

    public static func field(_ identifier: String,
                             type: FieldType = .input,
                             inputType: InputType = .text,
                             label: String? = nil,
                             placeholder: String? = nil,
                             required: Bool = true,
                             regex: String? = nil,
                             prefix: String = "",
                             dropdowns: [DropdownOption] = [],
                             radios: [RadioOption] = []) -> FormField {
        FormField(
            id: abs(identifier.hashValue % 10_000),
            identifier: identifier,
            name: identifier,
            labelKey: label ?? identifier,
            type: type,
            inputType: inputType,
            textStyle: "Regular",
            validationMessageKey: "regex",
            isRequired: required,
            isVisible: true,
            isReadOnly: false,
            regex: regex,
            prefix: prefix,
            suffix: "",
            placeholderKey: placeholder ?? identifier,
            dropdownOptions: dropdowns,
            radioOptions: radios
        )
    }

    // MARK: Individual fields, matching the real schema's rules

    public static let mobile = field("username", inputType: .number,
                                     regex: "^(27|0)?[1-9][0-9]{8}$", prefix: "+27")

    public static let password = field("password", inputType: .password,
                                       regex: "^(.){8,20}$")

    public static let firstName = field("firstname",
                                        regex: "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$")

    public static let email = field("email", inputType: .email,
                                    regex: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

    public static let referralCode = field("referralCode", required: false,
                                           regex: "^[a-zA-Z0-9]{3,25}$|^$")

    public static let idNumberType = field(
        "idNumberType", type: .dropdown, regex: "^[a-zA-Z]+$",
        dropdowns: [
            DropdownOption(value: "idNumber", textKey: "jpc-reg-idnumber", regex: "idNumberRegex"),
            DropdownOption(value: "passport", textKey: "jpc-reg-passport", regex: "passportNumberRegex"),
        ]
    )

    public static let idNumber = field("idNumber", regex: "^[0-9]{13}$")

    public static let dateOfBirth = field(
        "dateOfBirth", inputType: .calendar,
        regex: "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$"
    )

    public static let sourceOfFunds = field(
        "sourceOfFunds", type: .dropdown, regex: "^[a-zA-Z]+$",
        dropdowns: [
            DropdownOption(value: "SalaryOrWages", textKey: "jpc-reg-SalaryOrWages", regex: "[a-zA-Z]"),
            DropdownOption(value: "PensionOrGrant", textKey: "jpc-reg-PensionOrGrant", regex: "[a-zA-Z]"),
            DropdownOption(value: "AllowanceOrBursary", textKey: "jpc-reg-AllowanceOrBursary", regex: "[a-zA-Z]"),
            DropdownOption(value: "SavingsOrRentalOrOther", textKey: "jpc-reg-SavingsOrRentalOrOther", regex: "[a-zA-Z]"),
            DropdownOption(value: "SelfEmployed", textKey: "jpc-reg-SelfEmployed", regex: "[a-zA-Z]"),
        ]
    )

    public static let promoOptIn = field("receivePromotionalInformation", type: .checkbox,
                                         label: "receivePromotionalInformation-jza",
                                         required: false, regex: "^true|^false$")

    public static let terms = field("terms", type: .checkbox, required: true, regex: "^true$")

    public static let notes = field("notes", type: .textArea, label: "Notes",
                                    placeholder: "Anything else?", required: false)

    public static let contactMethod = field(
        "contactMethod", type: .radioGroup, label: "Preferred contact method", required: true,
        regex: "^.+$",
        radios: [
            RadioOption(value: "sms", textKey: "SMS"),
            RadioOption(value: "email", textKey: "Email"),
            RadioOption(value: "whatsapp", textKey: "WhatsApp"),
        ]
    )

    public static let welcomeOffer = field(
        "welcomeOffer", type: .welcomeOffer, label: "Select your Welcome Offer:", required: false,
        dropdowns: [
            DropdownOption(value: "depositMatch", textKey: "100% Deposit Match", regex: nil),
            DropdownOption(value: "freeSpins", textKey: "50 Free Spins", regex: nil),
        ]
    )

    // MARK: Whole schemas

    /// The two-section registration form, structured exactly as the CRM sends it.
    public static let registration = FormSchema(
        id: 1052, codeName: .registration, title: "registration", subTitle: "registration",
        regionCode: "JZA",
        sections: [
            FormSection(id: 45, codeName: "1", title: "1", subTitle: "1", order: 1, rows: [
                FormRow(number: 1, fields: [mobile]),
                FormRow(number: 2, fields: [password]),
                FormRow(number: 3, fields: [firstName]),
                FormRow(number: 4, fields: [field("lastname", regex: "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$")]),
                FormRow(number: 5, fields: [email]),
                FormRow(number: 6, fields: [referralCode]),
            ]),
            FormSection(id: 46, codeName: "2", title: "2", subTitle: "2", order: 2, rows: [
                FormRow(number: 1, fields: [idNumberType]),
                FormRow(number: 2, fields: [idNumber]),
                FormRow(number: 3, fields: [dateOfBirth]),
                FormRow(number: 4, fields: [sourceOfFunds]),
                FormRow(number: 5, fields: [promoOptIn]),
                FormRow(number: 6, fields: [terms]),
            ]),
        ]
    )

    /// A single field wrapped in a one-section schema — for previewing components alone.
    public static func schema(_ fields: [FormField]) -> FormSchema {
        FormSchema(id: 1, codeName: FormName("preview"), title: "", subTitle: "", regionCode: "JZA",
                   sections: [FormSection(id: 1, codeName: "1", title: "", subTitle: "", order: 1,
                                          rows: fields.enumerated().map { FormRow(number: $0.offset + 1, fields: [$0.element]) })])
    }

    /// Model holding just these fields, optionally pre-filled and pre-touched so the
    /// invalid (red) state can be previewed without interacting.
    @MainActor
    public static func model(_ fields: [FormField],
                            values: [String: FormValue] = [:],
                            touched: [String] = []) -> DynamicFormModel {
        .preview(schema: schema(fields), values: values, touched: touched)
    }

    /// Values that make section one valid — useful for previewing the unlocked
    /// Welcome Offer and the enabled Next button.
    public static let validSectionOne: [String: FormValue] = [
        "username": .text("849134302"),
        "password": .text("Password1"),
        "firstname": .text("Malcolm"),
        "lastname": .text("Collin"),
        "email": .text("hi@example.com"),
    ]
}
#endif
