import SwiftUI

public extension View {
    /// Presents `panel` the way the app presents Sign Up and Login: over this view, which dims
    /// behind a scrim, inset from the edges and pinned below the host's header. Not a system
    /// sheet — there is no grabber and no drag to dismiss; the panel's own close button ends it.
    ///
    ///     page.jackpotPopup(isPresented: $showsSignUp, topInset: headerHeight) {
    ///         RegistrationView(dependencies: deps, onClose: { showsSignUp = false }, …)
    ///     }
    ///
    /// - Parameter topInset: how far below the top of this view the panel starts, so a page
    ///   header stays visible, dimmed, above it. Defaults to the standard inset.
    func jackpotPopup<Panel: View>(isPresented: Binding<Bool>,
                                   topInset: CGFloat = JackpotSpacing.m.rawValue,
                                   @ViewBuilder panel: @escaping () -> Panel) -> some View {
        modifier(JackpotPopup(isPresented: isPresented, topInset: topInset, panel: panel))
    }
}

private struct JackpotPopup<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    let topInset: CGFloat
    let panel: () -> Panel

    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    ZStack(alignment: .top) {
                        // `background` at 60%: a white wash over the light page, a darkening of
                        // the dark one — the same dimming the app applies behind its panels.
                        theme.colors.background.opacity(0.6)
                            .ignoresSafeArea()
                            .accessibilityHidden(true)

                        panel()
                            .padding([.horizontal, .bottom], .m)
                            .padding(.top, topInset)
                            .accessibilityAddTraits(.isModal)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: isPresented)
    }
}
