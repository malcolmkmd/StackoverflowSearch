import SwiftUI

/// Placeholder rows while content loads.
public struct JackpotSkeleton: View {
    private let rows: Int
    @Environment(\.jackpotTheme) private var theme

    public init(rows: Int = 5) { self.rows = rows }

    public var body: some View {
        VStack(spacing: theme.spacing) {
            ForEach(0..<rows, id: \.self) { _ in
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.fieldBackground)
                    .frame(height: theme.controlHeight)
            }
        }
        .redacted(reason: .placeholder)
    }
}

/// Something went wrong, with a retry.
public struct JackpotErrorView: View {
    private let title: String
    private let message: String
    private let retryTitle: String
    private let retry: () -> Void
    @Environment(\.jackpotTheme) private var theme

    public init(title: String = "Something went wrong",
                message: String,
                retryTitle: String = "Retry",
                retry: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(theme.textSecondary)
            Text(title).font(.headline).foregroundColor(theme.textPrimary)
            Text(message).font(.footnote).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
            JackpotButton(retryTitle, action: retry).frame(width: 160)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
