import SwiftUI
import JackpotUI

struct DropdownFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotDropdown(model.localized(field.labelKey),
                        selection: model.selection(for: field),
                        options: model.options(for: field))
            .disabled(field.isReadOnly)
            .jackpotFieldError(model.error(for: field))
    }
}

#if DEBUG
struct DropdownFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Placeholder") {
                DropdownFieldView(field: FormPreview.field("idNumberType"), model: FormPreview.model([FormPreview.field("idNumberType")]))
            }.previewDisplayName("ID type — placeholder")
            JackpotPreviewPanel("Selected") {
                DropdownFieldView(field: FormPreview.field("idNumberType"),
                                  model: FormPreview.model([FormPreview.field("idNumberType")], values: ["idNumberType": .option("idNumber")]))
            }.previewDisplayName("ID type — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DropdownFieldView(field: FormPreview.field("sourceOfFunds"),
                                  model: FormPreview.model([FormPreview.field("sourceOfFunds")], touched: ["sourceOfFunds"]))
            }.previewDisplayName("Source of funds — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
