//
//  RegistrationSandbox.swift
//  StackOverflowSearch
//

import SwiftUI
import JackpotFormsData
import JackpotFormsDomain
import JackpotFormsUI
import JackpotUI

/// On-device harness for the JackpotKit sign-up form.
///
/// The schema comes from the JSON bundled in `JackpotFormsUI`, so this renders and
/// validates the real registration form without the CRM endpoint being reachable.
/// Submitting does not post anywhere — the sandbox reads the callback payload back.
struct RegistrationSandbox: View {

    /// Built once: `StubFormRepository` holds the decoded JSON, and rebuilding it on
    /// every body pass would re-read the bundle behind the loading delay.
    private static let dependencies = FormDependencies(
        repository: StubFormRepository(forms: FormPreviewData.bundledForms),
        localizer: ComposedKeyLocalizer.jpcRegistration
    )

    var body: some View {
        FormSandboxView(
            samples: [
                .init(id: .registration, title: "Sign Up"),
                .init(id: .kitchenSink, title: "Registration fields"),
            ],
            dependencies: Self.dependencies
        )
        // Not decoration. This app's asset catalogue sets an orange `AccentColor`, which is
        // SwiftUI's app-wide tint and would otherwise colour the form's carets, selection
        // handles, segmented picker and date wheel. `jackpotTheme` also applies
        // `.tint(colors.accent)`, so the form keeps the Jackpot blue whatever hosts it.
        .jackpotTheme(.jackpotCity)
    }
}

#if DEBUG
#Preview("Registration sandbox") {
    RegistrationSandbox()
}

#Preview("Registration sandbox — dark") {
    RegistrationSandbox().preferredColorScheme(.dark)
}
#endif
