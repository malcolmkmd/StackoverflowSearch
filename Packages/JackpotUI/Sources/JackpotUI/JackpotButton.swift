import SwiftUI

public struct JackpotButtonStyle: ButtonStyle {
    public enum Kind { case primary, secondary, tertiary }

    private let kind: Kind
    private let isEnabled: Bool
    @Environment(\.jackpotTheme) private var theme

    public init(_ kind: Kind = .primary, isEnabled: Bool = true) {
        self.kind = kind
        self.isEnabled = isEnabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: theme.controlHeight)
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(theme.cornerRadius)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var background: Color {
        switch kind {
        case .primary:   return isEnabled ? theme.accent : theme.fieldBackground
        case .secondary: return theme.fieldBackground
        case .tertiary:  return .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary:   return isEnabled ? .white : theme.textSecondary
        case .secondary: return theme.textPrimary
        case .tertiary:  return theme.accent
        }
    }
}

/// A full-width action button with a built-in loading state.
public struct JackpotButton: View {
    private let title: String
    private let kind: JackpotButtonStyle.Kind
    private let isEnabled: Bool
    private let isLoading: Bool
    private let action: () -> Void

    public init(_ title: String,
                kind: JackpotButtonStyle.Kind = .primary,
                isEnabled: Bool = true,
                isLoading: Bool = false,
                action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.white) }
            }
        }
        .buttonStyle(JackpotButtonStyle(kind, isEnabled: isEnabled))
        .disabled(!isEnabled || isLoading)
    }
}
