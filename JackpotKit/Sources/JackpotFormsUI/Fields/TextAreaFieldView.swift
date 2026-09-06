import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct TextAreaFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotTextArea(model.localized(field.placeholderKey),
                            text: model.text(for: field))
                .onEditingEnded { model.markTouched(field) }
                .disabled(field.isReadOnly)
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
