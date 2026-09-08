import Foundation

// Wire shapes, exactly as the CRM form-builder sends them. Nothing outside this folder knows
// about "formSectionCodeName" or the "Calender" spelling. Keys the app has no use for
// (`fieldName`, `textStyle`, `fieldPlaceholder`, `fieldRadioGroup`) are simply not decoded.
//
// Everything is optional except the identifiers we cannot render without: the schema is edited
// by product in a CMS, so a missing `prefix` must not fail the whole decode.

struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let formTitle: String?
    let formSubTitle: String?
    let regionCode: String?
    let sections: [FormSectionDTO]?
}

struct FormSectionDTO: Decodable {
    let formSectionId: Int
    let formSectionCodeName: String?
    let formSectionTitle: String?
    let formSectionSubTitle: String?
    let formSectionOrder: Int?
    let rows: [FormRowDTO]?
}

struct FormRowDTO: Decodable {
    let rowNumber: Int
    let fields: [FormFieldDTO]?
}

struct FormFieldDTO: Decodable {
    let fieldId: Int
    let fieldIdentifier: String
    let fieldLabel: String?
    let fieldType: String
    let inputType: String?
    let validationMessage: String?
    let isRequired: Bool?
    let isVisible: Bool?
    let isReadOnly: Bool?
    let fieldRegex: String?
    let prefix: String?
    let suffix: String?
    let fieldDropdowns: [FieldDropdownDTO]?
}

struct FieldDropdownDTO: Decodable {
    let value: String
    let text: String?
    let regex: String?
}
