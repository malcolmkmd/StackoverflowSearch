import SwiftUI

public struct JackpotRadioGroup: View {
    @Binding private var selection: String?
    private let options: [JackpotOption]

    @Environment(\.jackpotTheme) private var theme

    public init(selection: Binding<String?>, options: [JackpotOption]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: JackpotSpacing.s) {
            ForEach(options) { option in
                row(for: option)
            }
        }
    }

    private func row(for option: JackpotOption) -> some View {
        let isSelected = selection == option.id
        return Button {
            selection = option.id
        } label: {
            HStack(spacing: theme.sizes.spacing) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textSecondary)
                    .animation(.easeOut(duration: 0.15), value: isSelected)
                Text(option.label).jackpotTextStyle(\.rowLabel)
                Spacer(minLength: 0)
            }
            .frame(minHeight: theme.sizes.minimumHitTarget)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
