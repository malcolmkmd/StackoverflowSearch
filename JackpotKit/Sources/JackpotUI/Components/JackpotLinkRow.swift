import SwiftUI

/// A prompt with a link at its trailing edge, on `background` so it rests on a `surface` band.
public struct JackpotLinkRow: View {
    private let prompt: String
    private let link: String
    private let action: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ prompt: String, link: String, action: @escaping () -> Void) {
        self.prompt = prompt
        self.link = link
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(prompt).jackpotTextStyle(\.rowLabel)
                Spacer(minLength: 0)
                HStack(spacing: .xxs) {
                    Text(link).jackpotTextStyle(\.rowLabel, color: \.accent)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .jackpotForegroundStyle(\.accent)
                }
            }
            .padding(.m)
            .frame(minHeight: theme.sizes.controlHeight)
            .jackpotBackground(\.background, in: theme.sizes.fieldShape)
            .overlay {
                theme.sizes.fieldShape
                    .strokeBorder(theme.colors.fieldBorder, lineWidth: theme.sizes.borderWidth)
            }
            .contentShape(theme.sizes.fieldShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prompt) \(link)")
    }
}
