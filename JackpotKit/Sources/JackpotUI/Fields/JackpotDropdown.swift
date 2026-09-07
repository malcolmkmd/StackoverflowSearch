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
                ZStack(alignment: .leading) {
                    if let selected {
                        Text(selected.label)
                            .jackpotTextStyle(\.fieldText)
                            .padding(.top, theme.sizes.spacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    JackpotFloatingLabel(title: placeholder, isFloating: isFloating)
                        .offset(y: isFloating ? -16 : 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").jackpotForegroundStyle(\.textPrimary)
            }
            .padding(.horizontal, theme.sizes.contentPadding)
            .frame(height: theme.sizes.controlHeight)
            .jackpotFieldBackground()
            .animation(.easeOut(duration: 0.15), value: isFloating)
        }
        .accessibilityLabel(placeholder)
        .accessibilityValue(selected?.label ?? "None")
    }

    private var selected: JackpotOption? {
        options.first { $0.id == selection }
    }

    private var isFloating: Bool {
        selected != nil
    }
}
