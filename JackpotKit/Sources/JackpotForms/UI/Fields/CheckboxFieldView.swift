import SwiftUI
import JackpotUI

/// Checkbox values validate as the strings "true"/"false" — the schema's `terms` field
/// literally uses the pattern `^true$` to mean "must be ticked".
struct CheckboxFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        Toggle(model.localized(field.labelKey), isOn: model.bool(for: field))
            .toggleStyle(.jackpotCheckbox)
            .disabled(field.isReadOnly)
            .jackpotFieldError(model.error(for: field))
    }
}

#if DEBUG
struct CheckboxFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Unticked · required · touched") {
                CheckboxFieldView(field: FormPreview.field("terms"), model: FormPreview.model([FormPreview.field("terms")], touched: ["terms"]))
            }.previewDisplayName("Terms — must be ticked")
            JackpotPreviewPanel("Ticked") {
                CheckboxFieldView(field: FormPreview.field("terms"),
                                  model: FormPreview.model([FormPreview.field("terms")], values: ["terms": .bool(true)]))
            }.previewDisplayName("Terms — accepted")
            JackpotPreviewPanel("Optional · wraps") {
                CheckboxFieldView(field: FormPreview.field("receivePromotionalInformation"),
                                  model: FormPreview.model([FormPreview.field("receivePromotionalInformation")]))
            }.previewDisplayName("Promotions opt-in")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
