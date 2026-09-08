//
//  RegistrationSandbox.swift
//  StackOverflowSearch
//

import SwiftUI
import JackpotRegistration
import JackpotUI

/// On-device harness for the JackpotKit Sign Up panel; `SearchView` presents it with
/// `.jackpotPopup`, the way the app presents its own.
///
/// The schema comes from the JSON bundled in `JackpotForms` and the service is the mock, so
/// the whole panel runs and validates without any endpoint being reachable. Submitting shows
/// what the callback received.
struct RegistrationSandbox: View {
    let onClose: () -> Void

    /// Built once: the stub repository holds the decoded JSON, and rebuilding it on every body
    /// pass would re-read the bundle behind the loading delay.
    private static let dependencies = RegistrationDependencies.mock()

    @State private var result: RegistrationResult?

    var body: some View {
        // `RegistrationView` applies the Jackpot theme and tint itself, which is what keeps the
        // form blue although this app's asset catalogue sets an orange `AccentColor`.
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
