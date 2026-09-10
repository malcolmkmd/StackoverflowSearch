#if DEBUG
import SwiftUI
import JackpotUI
import JackpotForms

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
            Page(dependencies: .init(forms: .mock(delay: 3600)))
                .preferredColorScheme(.dark)
                .previewDisplayName("Loading")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
