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
    private let title: String
    private let options: [JackpotOption]

    @Environment(\.jackpotTheme) private var theme

    /// - Parameter title: the in-field label. It floats to the top edge once an option is chosen.
    public init(_ title: String, selection: Binding<String?>, options: [JackpotOption]) {
        self.title = title
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
            HStack(spacing: 0) {
                JackpotFloatingField(title, isFloating: selected != nil) {
                    if let selected {
                        Text(selected.label).jackpotTextStyle(\.fieldText)
                    }
                }
                Image(systemName: "chevron.down")
                    .jackpotForegroundStyle(\.textPrimary)
                    .padding(.trailing, theme.sizes.contentPadding)
            }
            .jackpotFieldBackground()
        }
        .accessibilityLabel(title)
        .accessibilityValue(selected?.label ?? "None")
    }

    private var selected: JackpotOption? {
        options.first { $0.id == selection }
    }
}
