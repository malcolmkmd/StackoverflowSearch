import Foundation

// Wire shapes, exactly as the CRM sends them. Everything is optional but the identifiers: product
// edits the schema in a CMS, so a missing `prefix` must not fail the decode.
struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let sections: [FormSectionDTO]?
}

struct FormSectionDTO: Decodable {
    let formSectionId: Int
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
