
import SwiftUI
import JackpotForms
import JackpotRegistration
import JackpotUI

struct RegistrationSandbox: View {
    let onClose: () -> Void

    private static let dependencies = RegistrationDependencies.bundled()

    @State private var result: RegistrationResult?

    var body: some View {
        RegistrationView(dependencies: Self.dependencies, onClose: onClose, onLogin: onClose) { result in
            self.result = result
        }
        .alert("Registered", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("OK") {}
        } message: {
            Text([result?.message, result?.accountId.map { "Account \($0)" }].compactMap { $0 }.joined(separator: "\n"))
        }
    }
}

#if DEBUG
private struct SandboxPage: View {
    @State private var isPresented = true

    var body: some View {
        VStack {
            Text("Page content").font(.title)
            Button("Sign Up") { isPresented = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .jackpotPopup(isPresented: $isPresented) {
            RegistrationSandbox(onClose: { isPresented = false })
        }
    }
}

#Preview("Registration popup") {
    SandboxPage()
}

#Preview("Registration popup — dark") {
    SandboxPage().preferredColorScheme(.dark)
}
#endif
