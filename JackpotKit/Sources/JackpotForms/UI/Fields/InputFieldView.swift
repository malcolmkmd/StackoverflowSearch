import SwiftUI
import JackpotUI

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    @State private var isEditing = false

    var body: some View {
        if field.inputType == .calendar {
            DateFieldView(field: field, model: model)
        } else {
            VStack(spacing: .xs) {
                JackpotTextField(model.localized(field.labelKey),
                                 text: model.text(for: field),
                                 kind: kind,
                                 prefix: field.prefix,
                                 suffix: field.suffix)
                    .onEditingEnded { model.markTouched(field) }
                    .onFocusChange { isEditing = $0 }
                    .jackpotFieldIdentity(field.identifier)
                    .submitLabel(isLastFocusable ? .done : .next)
                    .disabled(field.isReadOnly)

                // The rules are guidance while composing; once the field is left, the error line carries the verdict.
                if field.isSecure, isEditing {
                    JackpotChecklist("Password Validity", items: passwordItems)
                        .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isEditing)
            .jackpotFieldError(model.error(for: field))
        }
    }

    private var isLastFocusable: Bool {
        model.focusableIdentifiers.last == field.identifier
    }

    private var passwordItems: [JackpotChecklistItem] {
        PasswordPolicy.rules(for: field, password: model.value(for: field).stringValue).map {
            JackpotChecklistItem(id: $0.description, text: $0.description, isSatisfied: $0.isSatisfied)
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
        // The schema's `inputType` is coarser than iOS autofill: `username` is a mobile number typed as Number.
        switch field.identifier.lowercased() {
        case "username", "mobile", "mobilenumber": return .phoneNumber
        case "firstname":                          return .givenName
        case "lastname", "surname":                return .familyName
        case "email":                              return .email
        default:                                   return .text.with { $0.capitalization = .words }
        }
    }
}

#if DEBUG
struct InputFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Empty · untouched") {
                InputFieldView(field: FormPreview.field("username"), model: FormPreview.model([FormPreview.field("username")]))
            }.previewDisplayName("Mobile — empty")
            JackpotPreviewPanel("Invalid · touched") {
                InputFieldView(field: FormPreview.field("username"),
                               model: FormPreview.model([FormPreview.field("username")], values: ["username": .text("123")], touched: ["username"]))
            }.previewDisplayName("Mobile — invalid")
            JackpotPreviewPanel("Password · 7 chars · unfocused") {
                InputFieldView(field: FormPreview.field("password"),
                               model: FormPreview.model([FormPreview.field("password")], values: ["password": .text("Passwo1")], touched: ["password"]))
            }.previewDisplayName("Password — rules hidden")
            JackpotPreviewPanel("Optional · empty is fine") {
                InputFieldView(field: FormPreview.field("referralCode"),
                               model: FormPreview.model([FormPreview.field("referralCode")], touched: ["referralCode"]))
            }.previewDisplayName("Referral — optional")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
