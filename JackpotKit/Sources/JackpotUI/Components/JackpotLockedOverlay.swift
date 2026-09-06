import SwiftUI

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
            content
                .opacity(isLocked ? 0.35 : 1)
                .allowsHitTesting(!isLocked)
                .accessibilityHidden(isLocked)

            if isLocked {
                Text(message)
                    .jackpotTextStyle(\.sectionTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .shadow(radius: 4)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isLocked)
    }
}

public extension View {
    func jackpotLocked(_ isLocked: Bool, message: String) -> some View {
        modifier(JackpotLockedOverlay(isLocked: isLocked, message: message))
    }
}
