import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// "Welcome Offer" is a first-class field type in the builder's type list. Options come from
/// `fieldDropdowns`; the picker unlocks with `model.isFormValid`, matching the design.
struct WelcomeOfferFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    private var isUnlocked: Bool { model.isFormValid }
    private var selected: String { model.value(for: field).stringValue }

    var body: some View {
        VStack(spacing: JackpotSpacing.sm) {
            Text(model.localized(field.labelKey))
                .jackpotTextStyle(\.sectionTitle)

            HStack(spacing: JackpotSpacing.sm) {
                ForEach(model.options(for: field)) { option in
                    Button {
                        model.setValue(.option(option.id), for: field)
                        model.markTouched(field)
                    } label: {
                        Text(option.label)
                            .jackpotTextStyle(\.button)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.jackpotCard)
                    .jackpotSelected(selected == option.id)
                }
            }
            .disabled(!isUnlocked)
            .jackpotLocked(!isUnlocked, message: "Complete your registration above to unlock your Welcome offer selection")

            Button("Not yet") {
                model.setValue(.option(""), for: field)
                model.markTouched(field)
            }
            .buttonStyle(.jackpot(.secondary))
            .disabled(!isUnlocked)
        }
    }
}

#if DEBUG
struct WelcomeOfferFieldView_Previews: PreviewProvider {
    private static let fields = [FormPreview.mobile, FormPreview.email, FormPreview.welcomeOffer]

    static var previews: some View {
        Group {
            JackpotPreviewPanel("Locked") {
                WelcomeOfferFieldView(field: FormPreview.welcomeOffer, model: FormPreview.model(fields))
            }.previewDisplayName("Welcome offer — locked")
            JackpotPreviewPanel("Unlocked · selected") {
                WelcomeOfferFieldView(field: FormPreview.welcomeOffer, model: FormPreview.model(fields, values: [
                    "username": .text("849134302"), "email": .text("hi@example.com"), "welcomeOffer": .option("depositMatch"),
                ]))
            }.previewDisplayName("Welcome offer — selected")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
