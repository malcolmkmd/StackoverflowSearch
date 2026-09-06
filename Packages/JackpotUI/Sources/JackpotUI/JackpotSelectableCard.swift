import SwiftUI

/// A tile that can be selected from a set — provider logos, payment methods, welcome offers.
public struct JackpotSelectableCard<Content: View>: View {
    private let isSelected: Bool
    private let isEnabled: Bool
    private let action: () -> Void
    private let content: Content
    @Environment(\.jackpotTheme) private var theme

    public init(isSelected: Bool, isEnabled: Bool = true, action: @escaping () -> Void,
                @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(theme.fieldBackground)
                .cornerRadius(theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(isSelected ? theme.accent : theme.fieldBorder, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Dims content and overlays a message until a condition is met — the "Complete your
/// registration above to unlock" treatment.
public struct JackpotLockedOverlay: ViewModifier {
    private let isLocked: Bool
    private let message: String
    @Environment(\.jackpotTheme) private var theme

    public init(isLocked: Bool, message: String) {
        self.isLocked = isLocked
        self.message = message
    }

    public func body(content: Content) -> some View {
        ZStack {
            content.opacity(isLocked ? 0.35 : 1).allowsHitTesting(!isLocked)
            if isLocked {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .shadow(radius: 4)
            }
        }
    }
}

public extension View {
    func jackpotLocked(_ isLocked: Bool, message: String) -> some View {
        modifier(JackpotLockedOverlay(isLocked: isLocked, message: message))
    }
}
