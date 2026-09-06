import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    @State private var isEditing = false

    var body: some View {
        if field.inputType == .calendar {
            DateFieldView(field: field, model: model)
        } else {
            JackpotLabeledField(error: model.error(for: field)) {
                VStack(spacing: 6) {
                    JackpotTextField(model.localized(field.placeholderKey),
                                     text: model.text(for: field))
                        .onEditingEnded { model.markTouched(field) }
                        .onFocusChange { isEditing = $0 }
                        .jackpotField(kind)
                        .jackpotFieldPrefix(field.prefix)
                        .jackpotFieldSuffix(field.suffix)
                        .jackpotFieldIdentity(field.identifier)
                        .jackpotSubmitLabel(isLastFocusable ? .done : .next)
                        .disabled(field.isReadOnly)

                    // The rules are guidance while composing a password, not a permanent
                    // fixture — once the field is left the error line carries the verdict.
                    if field.isSecure, isEditing {
                        JackpotChecklist("Password Validity", items: passwordItems)
                            .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isEditing)
            }
        }
    }

    private var isLastFocusable: Bool {
        model.focusableIdentifiers.last == field.identifier
    }

    private var passwordItems: [JackpotChecklistItem] {
        model.passwordRules(for: field).map { rule in
            JackpotChecklistItem(id: rule.id,
                                 text: rule.description,
                                 isSatisfied: rule.isSatisfied(by: model.value(for: field).stringValue))
        }
    }

    private var kind: JackpotFieldKind {
        if field.isSecure { return .newPassword }
        switch field.inputType {
        case .email:  return .email
        case .phone:  return .phoneNumber
        case .number: return .number
        default:      break
        }
        // Falls back to the identifier, because the schema's `inputType` is coarser than the
        // autofill hints iOS can use.
        switch field.identifier.lowercased() {
        case "username", "mobile", "mobilenumber": return .phoneNumber
        case "firstname":                          return .givenName
        case "lastname", "surname":                return .familyName
        case "email":                              return .email
        case "otp", "pin", "code":                 return .oneTimeCode
        default:                                   return .text.with { $0.capitalization = .words }
        }
    }
}

#if DEBUG
struct InputFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Empty · untouched") {
                InputFieldView(field: FormPreview.mobile, model: FormPreview.model([FormPreview.mobile]))
            }.previewDisplayName("Mobile — empty")
            JackpotPreviewPanel("Invalid · touched") {
                InputFieldView(field: FormPreview.mobile,
                               model: FormPreview.model([FormPreview.mobile], values: ["username": .text("123")], touched: ["username"]))
            }.previewDisplayName("Mobile — invalid")
            // The checklist is focus-gated, so it stays hidden here; focus the field in the
            // live preview to see it.
            JackpotPreviewPanel("Password · 7 chars · unfocused") {
                InputFieldView(field: FormPreview.password,
                               model: FormPreview.model([FormPreview.password], values: ["password": .text("Passwo1")], touched: ["password"]))
            }.previewDisplayName("Password — rules hidden")
            JackpotPreviewPanel("Optional · empty is fine") {
                InputFieldView(field: FormPreview.referralCode,
                               model: FormPreview.model([FormPreview.referralCode], touched: ["referralCode"]))
            }.previewDisplayName("Referral — optional")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
