import SwiftUI

/// A tappable checkbox row. The whole row is the hit target (44pt minimum).
public struct JackpotCheckbox: View {
    @Binding private var isOn: Bool
    private let label: String
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onToggle: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ label: String,
                isOn: Binding<Bool>,
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onToggle: @escaping () -> Void = {}) {
        self.label = label
        self._isOn = isOn
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onToggle = onToggle
    }

    public var body: some View {
        Button {
            isOn.toggle()
            onToggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isOn ? theme.accent : (isInvalid ? theme.fieldBorderInvalid : theme.textSecondary))
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// A labelled switch.
public struct JackpotToggleRow: View {
    @Binding private var isOn: Bool
    private let label: String
    private let isDisabled: Bool
    private let onToggle: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ label: String, isOn: Binding<Bool>, isDisabled: Bool = false,
                onToggle: @escaping () -> Void = {}) {
        self.label = label
        self._isOn = isOn
        self.isDisabled = isDisabled
        self.onToggle = onToggle
    }

    public var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { isOn = $0; onToggle() })) {
            Text(label).font(.subheadline).foregroundColor(theme.textPrimary)
        }
        .tint(theme.accent)
        .disabled(isDisabled)
    }
}

/// Mutually exclusive options as a vertical list of radio rows.
public struct JackpotRadioGroup: View {
    @Binding private var selection: String?
    private let options: [JackpotOption]
    private let isDisabled: Bool
    private let onSelect: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(selection: Binding<String?>, options: [JackpotOption],
                isDisabled: Bool = false, onSelect: @escaping () -> Void = {}) {
        self._selection = selection
        self.options = options
        self.isDisabled = isDisabled
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection == option.id
                Button {
                    selection = option.id
                    onSelect()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(isSelected ? theme.accent : theme.textSecondary)
                        Text(option.label).font(.subheadline).foregroundColor(theme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .disabled(isDisabled)
    }
}
