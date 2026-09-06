#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsUI
import JackpotForms

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RegistrationView(dependencies: .mock()) { _ in }
                .previewDisplayName("Registration — mock, bundled copy")

            // What the app does during the migration: its own translation function, wrapped.
            RegistrationView(dependencies: .mock(localizer: ClosureLocalizer { key in
                ["username": "Enter Mobile Number", "password": "Password", "email": "Email"][key]
            })) { _ in }
            .previewDisplayName("Registration — mock, app localizer")

            RegistrationView(dependencies: .init(forms: .mock(delay: 3600), service: MockRegistrationService())) { _ in }
                .previewDisplayName("Loading")
        }
        .frame(height: 640)
        .background(JackpotTheme.jackpotCity.colors.surface)
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
#endif
