import SwiftUI
import UIKit
import JackpotUI
import JackpotFormsDomain

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        if field.inputType == .calendar {
            DateFieldView(field: field, model: model)
        } else {
            JackpotLabeledField(error: model.error(for: field)) {
                VStack(spacing: 6) {
                    JackpotTextField(
                        model.localized(field.placeholderKey),
                        text: model.text(for: field),
                        prefix: field.prefix,              // "+27" comes from the schema
                        suffix: field.suffix,
                        keyboard: keyboard,
                        contentType: contentType,
                        autocapitalization: autocapitalization,
                        isSecure: field.isSecure,
                        isInvalid: model.error(for: field) != nil,
                        isDisabled: field.isReadOnly,
                        onEditingEnded: { model.markTouched(field) }
                    )
                    if field.isSecure {
                        JackpotChecklist(
                            title: "Password Validity",
                            items: model.passwordRules(for: field).map { rule in
                                JackpotChecklistItem(id: rule.id,
                                                     text: rule.fallbackDescription,
                                                     isSatisfied: rule.isSatisfied(by: model.value(for: field).stringValue))
                            }
                        )
                    }
                }
            }
        }
    }

    private var keyboard: UIKeyboardType {
        switch field.inputType {
        case .number:  return .numberPad
        case .phone:   return .phonePad
        case .email:   return .emailAddress
        default:       return .default
        }
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch field.inputType {
        case .email, .password, .number: return .never
        default:                         return .words
        }
    }

    private var contentType: UITextContentType? {
        switch field.identifier.lowercased() {
        case "username", "mobile", "mobilenumber": return .telephoneNumber
        case "password":                            return .newPassword
        case "firstname":                           return .givenName
        case "lastname", "surname":                 return .familyName
        case "email":                               return .emailAddress
        case "otp", "pin", "code":                  return .oneTimeCode
        default:                                    return nil
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
            JackpotPreviewPanel("Password · 7 chars") {
                InputFieldView(field: FormPreview.password,
                               model: FormPreview.model([FormPreview.password], values: ["password": .text("Passwo1")], touched: ["password"]))
            }.previewDisplayName("Password — checklist")
            JackpotPreviewPanel("Optional · empty is fine") {
                InputFieldView(field: FormPreview.referralCode,
                               model: FormPreview.model([FormPreview.referralCode], touched: ["referralCode"]))
            }.previewDisplayName("Referral — optional")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
