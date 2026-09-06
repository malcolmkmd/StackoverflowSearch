import SwiftUI

/// One selectable option. `id` is what gets stored; `label` is what the user sees.
public struct JackpotOption: Identifiable, Hashable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// A `Menu`-backed picker styled as a field.
public struct JackpotDropdown: View {
    @Binding private var selection: String?
    private let options: [JackpotOption]
    private let placeholder: String
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onSelect: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ placeholder: String,
                selection: Binding<String?>,
                options: [JackpotOption],
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onSelect: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self._selection = selection
        self.options = options
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.label) {
                    selection = option.id
                    onSelect()
                }
            }
        } label: {
            HStack {
                Text(selected?.label ?? placeholder)
                    .foregroundColor(selected == nil ? theme.textSecondary : theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.down").foregroundColor(theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: theme.controlHeight)
            .jackpotFieldBorder(isInvalid: isInvalid)
        }
        .disabled(isDisabled)
        .accessibilityValue(selected?.label ?? placeholder)
    }

    private var selected: JackpotOption? {
        options.first { $0.id == selection }
    }
}
