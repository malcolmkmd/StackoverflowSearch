import SwiftUI
import JackpotUI

/// The contract between the form builder and the app: a new server type means a new case here, binding the
/// model to a `JackpotUI` component; until then `unknown` keeps the form usable.
struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        Group {
            switch field.type {
            // `inputType: "Calender"`; the picker's date is serialised through `FormValue.iso8601`.
            case .input where field.inputType == .calendar:
                JackpotDateField(model.translate(field.labelKey), selection: model.date(for: field), in: ...model.maximumDate)
            case .input:
                InputFieldView(field: field, model: model)
            case .dropdown:
                JackpotDropdown(model.translate(field.labelKey), selection: model.selection(for: field), options: model.options(for: field))
            // Checkboxes validate as "true" / "false"; `terms` uses `^true$` to mean "must be ticked".
            case .checkbox:
                Toggle(model.translate(field.labelKey), isOn: model.bool(for: field))
                    .toggleStyle(.jackpotCheckbox)
            case .unknown:
                EmptyView()
            }
        }
        .disabled(field.isReadOnly)
        .jackpotFieldError(model.error(for: field))
    }
}

// MARK: - Keyboard focus order

extension FormField {
    /// Only single-line text entry joins return-key navigation.
    var acceptsKeyboardFocus: Bool {
        type == .input && inputType != .calendar
    }
}

extension DynamicFormModel {
    var focusableIdentifiers: [String] {
        (currentSection?.fields ?? []).filter { $0.isVisible && $0.acceptsKeyboardFocus }.map(\.identifier)
    }

    func fieldAfter(_ identifier: String?) -> String? {
        let ids = focusableIdentifiers
        guard let identifier, let index = ids.firstIndex(of: identifier) else { return nil }
        let next = ids.index(after: index)
        return next < ids.endIndex ? ids[next] : nil
    }
}

// MARK: - Shared bindings

extension DynamicFormModel {
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    // Discrete choices mark the field touched as they write; typing reports blur through `onEditingEnded`.
    func selection(for field: FormField) -> Binding<String?> {
        Binding(get: { let v = self.value(for: field).stringValue; return v.isEmpty ? nil : v },
                set: { self.setValue(.text($0 ?? ""), for: field); self.markTouched(field.identifier) })
    }

    func bool(for field: FormField) -> Binding<Bool> {
        Binding(get: { self.value(for: field).boolValue },
                set: { self.setValue(.bool($0), for: field); self.markTouched(field.identifier) })
    }

    func date(for field: FormField) -> Binding<Date?> {
        Binding(get: { self.value(for: field).dateValue },
                set: { self.setValue($0.map(FormValue.date) ?? .empty, for: field); self.markTouched(field.identifier) })
    }

    func options(for field: FormField) -> [JackpotOption] {
        field.dropdownOptions.map { JackpotOption(id: $0.value, label: translate($0.textKey)) }
    }
}
