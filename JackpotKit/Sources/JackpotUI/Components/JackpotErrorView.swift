import SwiftUI

public struct JackpotErrorView: View {
    private let message: String
    private let title: String
    private var retryAction: (() -> Void)?

    public init(_ message: String, title: String = "Something went wrong") {
        self.message = message
        self.title = title
    }

    /// Adds the retry button. Without it the view is message-only.
    public func onRetry(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.retryAction = action
        return copy
    }

    public var body: some View {
        VStack(spacing: .sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .jackpotForegroundStyle(\.textSecondary)
                .accessibilityHidden(true)

            Text(title).jackpotTextStyle(\.button)

            Text(message)
                .jackpotTextStyle(\.label, color: \.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let retryAction {
                Button("Retry", action: retryAction)
                    .buttonStyle(.jackpot)
                    .frame(width: 160)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.l)
    }
}
