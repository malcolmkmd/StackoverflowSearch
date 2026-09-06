import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsUI
import JackpotForms

/// Everything the feature needs, supplied by the app at the one place it's presented.
public struct RegistrationDependencies {
    /// How the schema is fetched and localised. `.mock(localizer:)` until networking lands,
    /// `.live(baseURL:localizer:)` after.
    public var forms: FormDependencies
    /// What to do with the values once they validate.
    public var service: any RegistrationService
    public var theme: JackpotTheme

    public init(forms: FormDependencies,
                service: any RegistrationService,
                theme: JackpotTheme = .jackpotCity) {
        self.forms = forms
        self.service = service
        self.theme = theme
    }

    /// Bundled schema, mock service. Works with no backend and no app — the state of the
    /// feature at the end of PR 2, and what the app's final PR replaces with `.live`.
    ///
    /// - Parameter localizer: the app's existing translation function, wrapped:
    ///   `ClosureLocalizer { key in … getTranslation(Key: key) … }`. Nil → bundled placeholder copy.
    public static func mock(localizer: (any FormLocalizing)? = nil) -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock(localizer: localizer), service: MockRegistrationService())
    }
}

/// The registration screen. Two-page schema-driven form; on success reports the result.
public struct RegistrationView: View {
    private let dependencies: RegistrationDependencies
    private let onComplete: (RegistrationResult) -> Void

    public init(dependencies: RegistrationDependencies, onComplete: @escaping (RegistrationResult) -> Void) {
        self.dependencies = dependencies
        self.onComplete = onComplete
    }

    public var body: some View {
        DynamicFormView(formName: .registration) { submission in
            // Thrown errors render above the Sign Up button; the form stays filled in.
            let result = try await dependencies.service.register(submission)
            await MainActor.run { onComplete(result) }
        }
        .formDependencies(dependencies.forms)
        .jackpotTheme(dependencies.theme)
    }
}
