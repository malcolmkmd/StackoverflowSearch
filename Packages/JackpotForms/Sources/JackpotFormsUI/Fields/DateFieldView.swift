import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// `inputType: "Calender"`. The schema validates against an ISO-8601 date-time, so the
/// picker's `Date` is serialised through `FormValue.iso8601` rather than a display format.
struct DateFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(label: model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotDateField(
                model.localized(field.placeholderKey),
                title: model.localized(field.labelKey),
                date: model.date(for: field),
                // The form's only age gate is the T&C checkbox; capping the picker stops an
                // under-18 date being entered at all.
                in: ...model.maximumDateOfBirth,
                isInvalid: model.error(for: field) != nil,
                isDisabled: field.isReadOnly,
                onCommit: { model.markTouched(field) }
            )
        }
    }
}

#if DEBUG
struct DateFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("No date") {
                DateFieldView(field: FormPreview.dateOfBirth, model: FormPreview.model([FormPreview.dateOfBirth]))
            }.previewDisplayName("Date — placeholder")
            JackpotPreviewPanel("Chosen") {
                DateFieldView(field: FormPreview.dateOfBirth,
                              model: FormPreview.model([FormPreview.dateOfBirth],
                                                       values: ["dateOfBirth": .date(Date(timeIntervalSince1970: 631152000))]))
            }.previewDisplayName("Date — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DateFieldView(field: FormPreview.dateOfBirth,
                              model: FormPreview.model([FormPreview.dateOfBirth], touched: ["dateOfBirth"]))
            }.previewDisplayName("Date — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
