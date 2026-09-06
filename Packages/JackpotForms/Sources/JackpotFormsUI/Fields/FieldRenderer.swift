import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// Maps a schema `fieldType` to a component. This switch is the entire contract between the
/// form builder and the app: adding a type on the server means adding a case here and
/// shipping — until then, the unknown case keeps the form usable.
///
/// Every case binds the model to a `JackpotUI` component. The components know nothing about
/// forms; the views in this folder are the only place the two meet.
struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        switch field.type {
        case .input:                    InputFieldView(field: field, model: model)
        case .textArea:                 TextAreaFieldView(field: field, model: model)
        case .dropdown:                 DropdownFieldView(field: field, model: model)
        case .checkbox:                 CheckboxFieldView(field: field, model: model)
        case .toggle:                   ToggleFieldView(field: field, model: model)
        case .radio, .radioGroup:       RadioGroupFieldView(field: field, model: model)
        case .divider:                  JackpotDivider()
        case .welcomeOffer:             WelcomeOfferFieldView(field: field, model: model)
        case .button:                   EmptyView()          // the form's footer owns navigation
        case .recaptchaV2, .recaptchaV3: RecaptchaPlaceholderView(field: field)
        case .unknown:                  EmptyView()          // reported via model.unsupportedFields
        }
    }
}

/// reCAPTCHA needs a WKWebView bridge; out of scope for the first PR but the type is
/// recognised so the form still renders and validates around it.
struct RecaptchaPlaceholderView: View {
    let field: FormField
    @Environment(\.jackpotTheme) private var theme

    var body: some View {
        #if DEBUG
        Text("reCAPTCHA (\(field.identifier)) — not implemented")
            .font(.caption)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .jackpotFieldBorder(isInvalid: false)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Shared bindings

extension DynamicFormModel {
    /// Text binding for a field, writing back as `.text`.
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    /// Selection binding for dropdowns and radio groups. An empty selection is `.option("")`.
    func selection(for field: FormField) -> Binding<String?> {
        Binding(get: { let v = self.value(for: field).stringValue; return v.isEmpty ? nil : v },
                set: { self.setValue(.option($0 ?? ""), for: field) })
    }

    func bool(for field: FormField) -> Binding<Bool> {
        Binding(get: { self.value(for: field).boolValue },
                set: { self.setValue(.bool($0), for: field) })
    }

    func date(for field: FormField) -> Binding<Date?> {
        Binding(get: { self.value(for: field).dateValue },
                set: { self.setValue($0.map(FormValue.date) ?? .empty, for: field) })
    }

    func options(for field: FormField) -> [JackpotOption] {
        field.dropdownOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }
    }

    func radioOptions(for field: FormField) -> [JackpotOption] {
        field.radioOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }
    }
}
