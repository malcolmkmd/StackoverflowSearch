import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct DropdownFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotDropdown(model.localized(field.placeholderKey),
                            selection: model.selection(for: field),
                            options: model.options(for: field))
                .disabled(field.isReadOnly)
        }
    }
}

#if DEBUG
struct DropdownFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Placeholder") {
                DropdownFieldView(field: FormPreview.idNumberType, model: FormPreview.model([FormPreview.idNumberType]))
            }.previewDisplayName("ID type — placeholder")
            JackpotPreviewPanel("Selected") {
                DropdownFieldView(field: FormPreview.idNumberType,
                                  model: FormPreview.model([FormPreview.idNumberType], values: ["idNumberType": .option("idNumber")]))
            }.previewDisplayName("ID type — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DropdownFieldView(field: FormPreview.sourceOfFunds,
                                  model: FormPreview.model([FormPreview.sourceOfFunds], touched: ["sourceOfFunds"]))
            }.previewDisplayName("Source of funds — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
