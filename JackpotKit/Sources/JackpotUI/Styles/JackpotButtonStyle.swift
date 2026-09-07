import SwiftUI

public struct JackpotButtonStyle: ButtonStyle {
    public enum Prominence: Hashable, Sendable {
        case primary
        case secondary
        case tertiary
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
                .background { chrome }
                .contentShape(theme.sizes.fieldShape)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
                .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
        }

        /// `jackpotLoading(_:)` disables the button, but mid-submit it should still look live.
        private var isDimmed: Bool { !isEnabled && !isLoading }

        @ViewBuilder
        private var chrome: some View {
            switch prominence {
            case .primary:
                theme.sizes.fieldShape.fill(isDimmed ? theme.colors.fieldBackground : theme.colors.accentFill)
            case .secondary:
                JackpotButtonHairline(fill: theme.colors.surface)
            case .tertiary:
                theme.sizes.fieldShape.fill(Color.clear)
            }
        }

        private var foreground: Color {
            switch prominence {
            case .primary:   return isDimmed ? theme.colors.textSecondary : theme.colors.textOnAccent
            case .secondary: return isDimmed ? theme.colors.textSecondary : theme.colors.textPrimary
            case .tertiary:  return isDimmed ? theme.colors.textSecondary : theme.colors.accent
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

private struct JackpotButtonHairline: View {
    let fill: Color

    @Environment(\.jackpotTheme) private var theme

    var body: some View {
        theme.sizes.fieldShape
            .fill(fill)
            .overlay {
                theme.sizes.fieldShape
                    .strokeBorder(theme.colors.fieldBorder, lineWidth: theme.sizes.borderWidth)
            }
    }
}

// MARK: - Selectable card

public struct JackpotCardButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CardBody(configuration: configuration)
    }

    private struct CardBody: View {
        let configuration: ButtonStyleConfiguration

        @Environment(\.jackpotTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.jackpotIsSelected) private var isSelected

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, minHeight: theme.sizes.cardMinHeight)
                .jackpotBackground(\.fieldBackground, in: theme.sizes.fieldShape)
                .overlay {
                    theme.sizes.fieldShape
                        .strokeBorder(isSelected ? theme.colors.accent : theme.colors.fieldBorder,
                                      lineWidth: isSelected ? theme.sizes.emphasizedBorderWidth
                                                            : theme.sizes.borderWidth)
                }
                .contentShape(theme.sizes.fieldShape)
                .opacity(isEnabled ? 1 : 0.6)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.2), value: isSelected)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
    }
}

public extension ButtonStyle where Self == JackpotCardButtonStyle {
    static var jackpotCard: JackpotCardButtonStyle { JackpotCardButtonStyle() }
}
