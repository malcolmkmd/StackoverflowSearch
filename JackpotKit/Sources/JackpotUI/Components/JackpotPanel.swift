import SwiftUI

/// The shell a feature is presented in: a header band with a title and a close button, the
/// content on `background`, and an optional footer band. Header and footer draw on `surface`,
/// which is what separates them from the content between them; the close button rests on the
/// band in `background`.
///
///     JackpotPanel("Sign Up", onClose: dismiss) {
///         RegistrationView(dependencies: deps) { result in … }
///     } footer: {
///         Button("Already have an account? Login") { showLogin() }
///     }
public struct JackpotPanel<Content: View, Footer: View>: View {
    private let title: String
    private let onClose: () -> Void
    private let content: Content
    private let footer: Footer

    @Environment(\.jackpotTheme) private var theme

    public init(_ title: String,
                onClose: @escaping () -> Void,
                @ViewBuilder content: () -> Content,
                @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.onClose = onClose
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            content
                .frame(maxWidth: .infinity)
                .jackpotBackground(\.background)

            if Footer.self != EmptyView.self {
                footer
                    .padding(theme.sizes.contentPadding)
                    .frame(maxWidth: .infinity)
                    .jackpotBackground(\.surface)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.sizes.panelCornerRadius, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: theme.sizes.spacing) {
            Text(title).jackpotTextStyle(\.title)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .jackpotForegroundStyle(\.textPrimary)
                    .frame(width: theme.sizes.minimumHitTarget, height: theme.sizes.minimumHitTarget)
                    .jackpotBackground(\.background, in: theme.sizes.fieldShape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, theme.sizes.contentPadding)
        .padding(.vertical, .sm)
        .frame(maxWidth: .infinity)
        .jackpotBackground(\.surface)
    }
}

public extension JackpotPanel where Footer == EmptyView {
    init(_ title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(title, onClose: onClose, content: content, footer: { EmptyView() })
    }
}
