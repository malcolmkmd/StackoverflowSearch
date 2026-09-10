import SwiftUI
import JackpotUI

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    @State private var isEditing = false

    var body: some View {
        VStack(spacing: .xs) {
            JackpotTextField(model.translate(field.labelKey),
                             text: model.text(for: field),
                             kind: kind,
                             prefix: field.prefix,
                             suffix: field.suffix)
                .onEditingEnded { model.markTouched(field.identifier) }
                .onFocusChange { isEditing = $0 }
                .jackpotFieldIdentity(field.identifier)
                .submitLabel(model.focusableIdentifiers.last == field.identifier ? .done : .next)

            // The rules are guidance while composing; once the field is left, the error line carries the verdict.
            if field.inputType == .password, isEditing {
                JackpotChecklist(model.translate("password-validity"),
                                 section: model.translate("required"),
                                 items: PasswordSuggestions.items(for: model.value(for: field).stringValue,
                                                                 config: model.passwordConfig,
                                                                 translate: model.translate))
                    .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isEditing)
    }

    private var kind: JackpotFieldKind {
        switch field.inputType {
        case .password: return .newPassword
        case .email:    return .email
        case .phone:    return .phoneNumber
        case .number:   return .number
        default:        break
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
