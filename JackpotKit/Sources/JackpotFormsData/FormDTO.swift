import Foundation

// Wire shapes, exactly as the CRM form-builder sends them. Nothing outside this file knows
// about "formSectionCodeName" or the "Calender" spelling.
//
// Everything is optional except the identifiers we cannot render without: the schema is edited
// by product in a CMS, so a missing `prefix` must not fail the whole decode.

public struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let formTitle: String?
    let formSubTitle: String?
    let regionCode: String?
    let sections: [FormSectionDTO]?
}

public struct FormSectionDTO: Decodable {
    let formSectionId: Int
    let formSectionCodeName: String?
    let formSectionTitle: String?
    let formSectionSubTitle: String?
    let formSectionOrder: Int?
    let rows: [FormRowDTO]?
}

public struct FormRowDTO: Decodable {
    let rowNumber: Int
    let fields: [FormFieldDTO]?
}

public struct FormFieldDTO: Decodable {
    let fieldId: Int
    let fieldIdentifier: String
    let fieldName: String?
    let fieldLabel: String?
    let fieldType: String
    let inputType: String?
    let textStyle: String?
    let validationMessage: String?
    let isRequired: Bool?
    let isVisible: Bool?
    let isReadOnly: Bool?
    let fieldRegex: String?
    let prefix: String?
    let suffix: String?
    let fieldPlaceholder: String?
    let fieldDropdowns: [FieldDropdownDTO]?
    let fieldRadioGroup: [FieldRadioDTO]?
}

public struct FieldDropdownDTO: Decodable {
    let value: String
    let text: String?
    let regex: String?
}

public struct FieldRadioDTO: Decodable {
    let value: String
    let text: String?
}
