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
                .frame(maxWidth: .infinity, minHeight: theme.metrics.controlHeight)
                .foregroundStyle(foreground)
                .background(background, in: theme.metrics.fieldShape)
                .contentShape(theme.metrics.fieldShape)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
                .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
        }

        /// `jackpotLoading(_:)` disables the button, but mid-submit it should still look live.
        private var isDimmed: Bool { !isEnabled && !isLoading }

        private var background: Color {
            switch prominence {
            case .primary:   return isDimmed ? theme.colors.fieldBackground : theme.colors.accent
            case .secondary: return theme.colors.fieldBackground
            case .tertiary:  return .clear
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
                .frame(maxWidth: .infinity, minHeight: theme.metrics.cardMinHeight)
                .jackpotBackground(\.fieldBackground, in: theme.metrics.fieldShape)
                .overlay {
                    theme.metrics.fieldShape
                        .strokeBorder(isSelected ? theme.colors.accent : theme.colors.fieldBorder,
                                      lineWidth: isSelected ? theme.metrics.emphasizedBorderWidth
                                                            : theme.metrics.borderWidth)
                }
                .contentShape(theme.metrics.fieldShape)
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
