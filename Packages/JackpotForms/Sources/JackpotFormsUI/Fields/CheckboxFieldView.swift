import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// Checkbox values validate as the strings "true"/"false" — the schema's `terms` field
/// literally uses the pattern `^true$` to mean "must be ticked".
struct CheckboxFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(error: model.error(for: field)) {
            JackpotCheckbox(
                model.localized(field.labelKey),
                isOn: model.bool(for: field),
                isInvalid: model.error(for: field) != nil,
                isDisabled: field.isReadOnly,
                onToggle: { model.markTouched(field) }
            )
        }
    }
}

struct ToggleFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(error: model.error(for: field)) {
            JackpotToggleRow(model.localized(field.labelKey),
                             isOn: model.bool(for: field),
                             isDisabled: field.isReadOnly,
                             onToggle: { model.markTouched(field) })
        }
    }
}

#if DEBUG
struct CheckboxFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Unticked · required · touched") {
                CheckboxFieldView(field: FormPreview.terms, model: FormPreview.model([FormPreview.terms], touched: ["terms"]))
            }.previewDisplayName("Terms — must be ticked")
            JackpotPreviewPanel("Ticked") {
                CheckboxFieldView(field: FormPreview.terms,
                                  model: FormPreview.model([FormPreview.terms], values: ["terms": .bool(true)]))
            }.previewDisplayName("Terms — accepted")
            JackpotPreviewPanel("Optional · wraps") {
                CheckboxFieldView(field: FormPreview.promoOptIn, model: FormPreview.model([FormPreview.promoOptIn]))
            }.previewDisplayName("Promotions opt-in")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
