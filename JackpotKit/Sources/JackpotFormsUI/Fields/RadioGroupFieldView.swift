import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct RadioGroupFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotRadioGroup(selection: model.selection(for: field),
                              options: model.radioOptions(for: field))
                .disabled(field.isReadOnly)
        }
    }
}

#if DEBUG
struct RadioGroupFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Nothing chosen") {
                RadioGroupFieldView(field: FormPreview.contactMethod, model: FormPreview.model([FormPreview.contactMethod]))
            }.previewDisplayName("Radio — empty")
            JackpotPreviewPanel("Chosen") {
                RadioGroupFieldView(field: FormPreview.contactMethod,
                                    model: FormPreview.model([FormPreview.contactMethod], values: ["contactMethod": .option("email")]))
            }.previewDisplayName("Radio — selected")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
