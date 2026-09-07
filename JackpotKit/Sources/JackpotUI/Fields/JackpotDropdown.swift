import SwiftUI

public struct JackpotOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct JackpotDropdown: View {
    @Binding private var selection: String?
    private let placeholder: String
    private let options: [JackpotOption]

    @Environment(\.jackpotTheme) private var theme

    public init(_ placeholder: String, selection: Binding<String?>, options: [JackpotOption]) {
        self.placeholder = placeholder
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.id
                } label: {
                    if option.id == selection {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack {
                Text(selected?.label ?? placeholder)
                    .jackpotForegroundStyle(valueColor)
                Spacer()
                Image(systemName: "chevron.down").jackpotForegroundStyle(\.textPrimary)
            }
            .jackpotFont(\.fieldText)
            .padding(.horizontal, theme.sizes.contentPadding)
            .frame(height: theme.sizes.controlHeight)
            .jackpotFieldBackground()
        }
        .accessibilityLabel(placeholder)
        .accessibilityValue(selected?.label ?? "None")
    }

    private var selected: JackpotOption? {
        options.first { $0.id == selection }
    }

    private var valueColor: KeyPath<JackpotColors, Color> {
        selected == nil ? \.textSecondary : \.textPrimary
    }
}
