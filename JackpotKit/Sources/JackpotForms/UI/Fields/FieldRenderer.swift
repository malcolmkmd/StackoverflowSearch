import SwiftUI
import JackpotUI

/// Maps a schema `fieldType` to a component. This switch is the entire contract between the
/// form builder and the app: a new type on the server means a new `FieldType` case, a new
/// `XxxFieldView` here binding the model to a `JackpotUI` component, and until then the
/// unknown case keeps the form usable.
///
/// The `JackpotUI` components know nothing about forms; the views in this folder are the only
/// place the two meet.
struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        switch field.type {
        case .input:    InputFieldView(field: field, model: model)
        case .dropdown: DropdownFieldView(field: field, model: model)
        case .checkbox: CheckboxFieldView(field: field, model: model)
        case .unknown:  EmptyView()          // reported via model.unsupportedFields
        }
    }
}

// MARK: - Keyboard focus order

extension FormField {
    /// Only single-line text entry joins return-key navigation. A date opens a picker.
    var acceptsKeyboardFocus: Bool {
        type == .input && inputType != .calendar
    }
}

extension DynamicFormModel {
    /// The current section's text fields, in the order the return key walks them.
    var focusableIdentifiers: [String] {
        (currentSection?.rows ?? [])
            .flatMap(\.fields)
            .filter { $0.isVisible && $0.acceptsKeyboardFocus }
            .map(\.identifier)
    }

    /// Returns the field after `identifier`, or nil at the end so the keyboard dismisses.
    func fieldAfter(_ identifier: String?) -> String? {
        let ids = focusableIdentifiers
        guard let identifier, let index = ids.firstIndex(of: identifier) else { return nil }
        let next = ids.index(after: index)
        return next < ids.endIndex ? ids[next] : nil
    }
}

// MARK: - Shared bindings

extension DynamicFormModel {
    /// Text binding for a field, writing back as `.text`.
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    // The three below mark the field touched as they write. A discrete choice is a complete
    // answer, so validating it immediately is right — unlike typing, where `text(for:)` stays
    // silent and the field reports blur through `onEditingEnded`.

    /// Selection binding for dropdowns. An empty selection is `.option("")`.
    func selection(for field: FormField) -> Binding<String?> {
        Binding(get: { let v = self.value(for: field).stringValue; return v.isEmpty ? nil : v },
                set: { self.setValue(.option($0 ?? ""), for: field); self.markTouched(field) })
    }

    func bool(for field: FormField) -> Binding<Bool> {
        Binding(get: { self.value(for: field).boolValue },
                set: { self.setValue(.bool($0), for: field); self.markTouched(field) })
    }

    func date(for field: FormField) -> Binding<Date?> {
        Binding(get: { self.value(for: field).dateValue },
                set: { self.setValue($0.map(FormValue.date) ?? .empty, for: field); self.markTouched(field) })
    }

    func options(for field: FormField) -> [JackpotOption] {
        field.dropdownOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }
    }
}
