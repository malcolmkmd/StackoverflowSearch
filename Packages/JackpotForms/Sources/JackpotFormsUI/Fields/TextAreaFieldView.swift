import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct TextAreaFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(label: model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotTextArea(model.localized(field.placeholderKey),
                            text: model.text(for: field),
                            isInvalid: model.error(for: field) != nil,
                            isDisabled: field.isReadOnly,
                            onEditingEnded: { model.markTouched(field) })
        }
    }
}

#if DEBUG
struct TextAreaFieldView_Previews: PreviewProvider {
    static var previews: some View {
        JackpotPreviewPanel("Empty") {
            TextAreaFieldView(field: FormPreview.notes, model: FormPreview.model([FormPreview.notes]))
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
