#if DEBUG
import Foundation

/// The registration schema decoded from the bundled JSON, plus helpers that seed a model so
/// component previews render a chosen state without a fetch.
enum FormPreview {

    static let registration: FormSchema = {
        // A broken bundled schema should fail previews loudly rather than render nothing.
        try! StubFormRepository.decode(BundledForms.json(named: "registration"))
    }()

    static func field(_ identifier: String) -> FormField {
        guard let field = registration.field(identifiedBy: identifier) else {
            preconditionFailure("registration.json has no field \(identifier)")
        }
        return field
    }

    /// A one-section schema of just these fields, for previewing components alone.
    static func schema(_ fields: [FormField]) -> FormSchema {
        FormSchema(id: 1, codeName: FormName("preview"), title: "", subTitle: "", regionCode: "JZA",
                   sections: [FormSection(id: 1, codeName: "1", title: "", subTitle: "", order: 1,
                                          rows: fields.enumerated().map { FormRow(number: $0.offset + 1, fields: [$0.element]) })])
    }

    /// Model holding just these fields, optionally pre-filled and pre-touched so the
    /// invalid (red) state can be previewed without interacting.
    @MainActor
    static func model(_ fields: [FormField],
                      values: [String: FormValue] = [:],
                      touched: [String] = []) -> DynamicFormModel {
        .preview(schema: schema(fields), values: values, touched: touched)
    }

    /// Values that make section one valid, for previewing the enabled Next button.
    static let validSectionOne: [String: FormValue] = [
        "username": .text("849134302"),
        "password": .text("Password1"),
        "firstname": .text("Malcolm"),
        "lastname": .text("Collin"),
        "email": .text("hi@example.com"),
    ]
}
#endif
