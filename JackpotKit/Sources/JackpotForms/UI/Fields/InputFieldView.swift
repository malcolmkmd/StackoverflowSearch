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
                JackpotChecklist("Password Validity", items: passwordRules)
                    .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isEditing)
    }

    /// The schema gives password one regex, `^(.){8,20}$`, and the design shows two rules, so the `{min,max}` quantifier is parsed.
    private var passwordRules: [JackpotChecklistItem] {
        guard let bounds = field.regex?.lengthQuantifier else { return [] }
        let count = model.value(for: field).stringValue.count
        return [
            JackpotChecklistItem(id: "min", text: "Minimum of \(bounds.lowerBound) characters", isSatisfied: count >= bounds.lowerBound),
            JackpotChecklistItem(id: "max", text: "Maximum of \(bounds.upperBound) characters", isSatisfied: count > 0 && count <= bounds.upperBound),
        ]
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

extension String {
    /// `8...20` from `^(.){8,20}$`.
    var lengthQuantifier: ClosedRange<Int>? {
        guard let open = lastIndex(of: "{"), let close = self[open...].firstIndex(of: "}") else { return nil }
        let bounds = self[index(after: open)..<close].split(separator: ",").map { Int($0) }
        guard bounds.count == 2, let minimum = bounds[0], let maximum = bounds[1], minimum <= maximum else { return nil }
        return minimum...maximum
    }
}
