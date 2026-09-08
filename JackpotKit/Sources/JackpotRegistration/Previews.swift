#if DEBUG
import SwiftUI
import JackpotUI
import JackpotForms

/// The Sign Up sheet over the page, as the app presents it.
struct RegistrationView_Previews: PreviewProvider {
    private struct Page: View {
        var dependencies: RegistrationDependencies = .mock()
        var body: some View {
            RegistrationView(dependencies: dependencies, onClose: {}, onLogin: {}) { _ in }
                .padding(.m)
                .frame(width: 390, height: 780)
                .jackpotTheme(.jackpotCity)
                .jackpotBackground(\.background)
        }
    }

    static var previews: some View {
        Group {
            Page().preferredColorScheme(.dark)
                .previewDisplayName("Sign Up — dark")
            Page().preferredColorScheme(.light)
                .previewDisplayName("Sign Up — light")

            // What the app does during the migration: its own translation function, wrapped.
            Page(dependencies: .mock(localizer: ClosureLocalizer { key in
                ["username": "Enter Mobile Number", "password": "Password", "email": "Email"][key]
            }))
            .preferredColorScheme(.dark)
            .previewDisplayName("Sign Up — app localizer")

            Page(dependencies: .init(forms: .mock(delay: 3600), service: MockRegistrationService()))
                .preferredColorScheme(.dark)
                .previewDisplayName("Loading")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
