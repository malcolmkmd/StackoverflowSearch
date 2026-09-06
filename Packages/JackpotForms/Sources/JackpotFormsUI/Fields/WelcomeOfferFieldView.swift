import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// "Welcome Offer" is a first-class field type in the builder's type list. Options come from
/// `fieldDropdowns`; the picker unlocks with `model.isFormValid`, matching the design.
struct WelcomeOfferFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel
    @Environment(\.jackpotTheme) private var theme

    private var isUnlocked: Bool { model.isFormValid }
    private var selected: String { model.value(for: field).stringValue }

    var body: some View {
        VStack(spacing: 10) {
            Text(model.localized(field.labelKey))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 10) {
                ForEach(model.options(for: field)) { option in
                    JackpotSelectableCard(isSelected: selected == option.id, isEnabled: isUnlocked) {
                        model.setValue(.option(option.id), for: field)
                        model.markTouched(field)
                    } content: {
                        Text(option.label)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .jackpotLocked(!isUnlocked, message: "Complete your registration above to unlock your Welcome offer selection")

            JackpotButton("Not yet", kind: .secondary, isEnabled: isUnlocked) {
                model.setValue(.option(""), for: field)
                model.markTouched(field)
            }
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
