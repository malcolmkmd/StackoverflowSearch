import Foundation

struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let sections: [FormSectionDTO]?

    var schema: FormSchema {
        // Recaptcha is not a field: any row that contains it is dropped, and a visible one sets `hasRecaptcha`.
        var hasRecaptcha = false
        let mapped = (sections ?? [])
            .sorted { ($0.formSectionOrder ?? $0.formSectionId) < ($1.formSectionOrder ?? $1.formSectionId) }
            .map { dto -> FormSection in
                let rows = dto.section.rows.compactMap { row -> FormRow? in
                    guard row.fields.contains(where: { $0.type == .recaptchaV3 }) else { return row }
                    if row.fields.contains(where: { $0.type == .recaptchaV3 && $0.isVisible }) {
                        hasRecaptcha = true
                    }
                    return nil
                }
                return FormSection(id: dto.formSectionId, rows: rows)
            }
        return FormSchema(id: formId, codeName: FormName(formCodeName), sections: mapped, hasRecaptcha: hasRecaptcha)
    }
}

extension FormSchema {
    public init(json: Data) throws {
        self = try JSONDecoder().decode(FormDTO.self, from: json).schema
    }
}

struct FormSectionDTO: Decodable {
    let formSectionId: Int
    let formSectionOrder: Int?
    let rows: [FormRowDTO]?

    var section: FormSection {
        FormSection(id: formSectionId, rows: (rows ?? []).map(\.row).sorted { $0.number < $1.number })
    }
}

struct FormRowDTO: Decodable {
    let rowNumber: Int
    let fields: [FormFieldDTO]?

    var row: FormRow {
        FormRow(number: rowNumber, fields: (fields ?? []).map(\.field))
    }
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

    var field: FormField {
        FormField(
            id: fieldId,
            identifier: fieldIdentifier,
            labelKey: fieldLabel,
            type: FieldType(raw: fieldType),
            inputType: InputType(raw: inputType ?? "Text"),
            validationMessageKey: validationMessage ?? "regex",
            // Unspecified is optional and visible, so a CMS omission cannot block submit.
            isRequired: isRequired ?? false,
            isVisible: isVisible ?? true,
            isReadOnly: isReadOnly ?? false,
            regex: fieldRegex?.isEmpty == true ? nil : fieldRegex,
            prefix: prefix ?? "",
            suffix: suffix ?? "",
            dropdownOptions: (fieldDropdowns ?? []).map {
                DropdownOption(value: $0.value, textKey: $0.text ?? $0.value, regex: $0.regex)
            }
        )
    }
}

struct FieldDropdownDTO: Decodable {
    let value: String
    let text: String?
    let regex: String?
}
