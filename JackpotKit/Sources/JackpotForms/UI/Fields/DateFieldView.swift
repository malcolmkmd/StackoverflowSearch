import SwiftUI
import JackpotUI

/// `inputType: "Calender"`. The schema validates against an ISO-8601 date-time, so the
/// picker's `Date` is serialised through `FormValue.iso8601` rather than a display format.
struct DateFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotDateField(model.localized(field.labelKey),
                         selection: model.date(for: field),
                         in: ...model.maximumDate)
            .disabled(field.isReadOnly)
            .jackpotFieldError(model.error(for: field))
    }
}

#if DEBUG
struct DateFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("No date") {
                DateFieldView(field: FormPreview.field("dateOfBirth"), model: FormPreview.model([FormPreview.field("dateOfBirth")]))
            }.previewDisplayName("Date — placeholder")
            JackpotPreviewPanel("Chosen") {
                DateFieldView(field: FormPreview.field("dateOfBirth"),
                              model: FormPreview.model([FormPreview.field("dateOfBirth")],
                                                       values: ["dateOfBirth": .date(Date(timeIntervalSince1970: 631152000))]))
            }.previewDisplayName("Date — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DateFieldView(field: FormPreview.field("dateOfBirth"),
                              model: FormPreview.model([FormPreview.field("dateOfBirth")], touched: ["dateOfBirth"]))
            }.previewDisplayName("Date — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
