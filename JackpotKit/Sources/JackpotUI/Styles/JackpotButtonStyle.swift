import SwiftUI

public struct JackpotButtonStyle: ButtonStyle {
    public enum Prominence: Hashable, Sendable {
        /// Filled with the accent: Next, Sign Up, Retry, Done. Disabled, the fill dims to
        /// `accentFillDisabled` under `textPrimary`, so the button still reads as the way forward.
        case primary
        /// Background fill with a hairline: Previous.
        case secondary
    }

    private let prominence: Prominence

    public init(_ prominence: Prominence = .primary) {
        self.prominence = prominence
    }

    public func makeBody(configuration: Configuration) -> some View {
        // A ButtonStyle is not a View, so @Environment on the style itself never updates.
        ButtonBody(prominence: prominence, configuration: configuration)
    }

    private struct ButtonBody: View {
        let prominence: Prominence
        let configuration: ButtonStyleConfiguration

        @Environment(\.jackpotTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.jackpotIsLoading) private var isLoading

        var body: some View {
            configuration.label
                .jackpotFont(\.button)
                .opacity(isLoading ? 0 : 1)
                .overlay {
                    if isLoading {
                        ProgressView().tint(foreground).accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: theme.sizes.controlHeight)
                .foregroundStyle(foreground)
                .background { shell }
                .contentShape(theme.sizes.fieldShape)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
                .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
        }

        /// `jackpotLoading(_:)` disables the button, but mid-submit it should still look live.
        private var isDimmed: Bool { !isEnabled && !isLoading }

        @ViewBuilder
        private var shell: some View {
            switch prominence {
            case .primary:
                theme.sizes.fieldShape.fill(isDimmed ? theme.colors.accentFillDisabled : theme.colors.accentFill)
            case .secondary:
                theme.sizes.fieldShape
                    .fill(theme.colors.background)
                    .overlay {
                        theme.sizes.fieldShape
                            .strokeBorder(theme.colors.fieldBorder, lineWidth: theme.sizes.borderWidth)
                    }
            }
        }

        private var foreground: Color {
            switch prominence {
            case .primary:   return isDimmed ? theme.colors.textPrimary : theme.colors.textOnAccent
            case .secondary: return isDimmed ? theme.colors.textSecondary : theme.colors.textPrimary
            }
        }
    }
}

public extension ButtonStyle where Self == JackpotButtonStyle {
    static var jackpot: JackpotButtonStyle { JackpotButtonStyle(.primary) }

    static func jackpot(_ prominence: JackpotButtonStyle.Prominence) -> JackpotButtonStyle {
        JackpotButtonStyle(prominence)
    }
}
