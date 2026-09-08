import SwiftUI
import JackpotUI
import JackpotForms

/// Everything the feature needs, supplied by the app at the one place it's presented.
public struct RegistrationDependencies {
    /// How the schema is fetched and localised — `.mock(localizer:)` until networking lands,
    /// `.live(baseURL:localizer:)` after — with registration's own rules applied on top.
    public let forms: FormDependencies
    /// What to do with the values once they validate.
    public let service: any RegistrationService
    public let theme: JackpotTheme

    public init(forms: FormDependencies,
                service: any RegistrationService,
                theme: JackpotTheme = .jackpotCity) {
        self.forms = forms.applyingRegistrationRules()
        self.service = service
        self.theme = theme
    }

    /// Bundled schema, mock service — works with no backend and no app.
    ///
    /// - Parameter localizer: the app's existing translation function, wrapped:
    ///   `ClosureLocalizer { key in … getTranslation(Key: key) … }`. Nil → bundled placeholder copy.
    public static func mock(localizer: (any FormLocalizing)? = nil) -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock(localizer: localizer), service: MockRegistrationService())
    }
}

extension FormDependencies {
    /// What registration adds to the generic engine: the ID-type dropdown decides which regex
    /// the ID-number field validates against, and the date-of-birth picker cannot select an
    /// under-18 date. The form's only other age gate is the terms checkbox, so the cap is a
    /// cheap second line of defence.
    func applyingRegistrationRules(now: Date = Date()) -> FormDependencies {
        var rules = self
        rules.regexDependencies = ["idNumberType": "idNumber"]
        rules.maximumDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: -18, to: now)
        return rules
    }
}

/// The Sign Up sheet as the app presents it: the two-page schema-driven form inside a
/// `JackpotPanel`, with the close button in the header and, in the footer, the login row with
/// Previous / Next / Sign Up beneath it.
///
/// The shell's copy ("Sign Up", "Already have an account?", "Login") is not in the CRM schema,
/// so it is fixed here like the Next / Previous labels are, until the app-data keys are known.
public struct RegistrationView: View {
    private let dependencies: RegistrationDependencies
    private let onClose: () -> Void
    private let onLogin: () -> Void
    private let onComplete: (RegistrationResult) -> Void
    @StateObject private var model: DynamicFormModel

    /// - Parameters:
    ///   - onClose: the header's close button.
    ///   - onLogin: the footer's "Already have an account? Login" row.
    ///   - onComplete: the account was created; route to OTP, login or home.
    public init(dependencies: RegistrationDependencies,
                onClose: @escaping () -> Void,
                onLogin: @escaping () -> Void,
                onComplete: @escaping (RegistrationResult) -> Void) {
        self.dependencies = dependencies
        self.onClose = onClose
        self.onLogin = onLogin
        self.onComplete = onComplete
        _model = StateObject(wrappedValue: DynamicFormModel(formName: .registration, dependencies: dependencies.forms))
    }

    public var body: some View {
        JackpotPanel("Sign Up", onClose: onClose) {
            DynamicFormContent(model: model)
        } footer: {
            VStack(spacing: .sm) {
                JackpotLinkRow("Already have an account?", link: "Login", action: onLogin)
                FormNavigationBar(model: model) { submission in
                    // Thrown errors render under the fields; the form stays filled in.
                    onComplete(try await dependencies.service.register(submission))
                }
            }
        }
        .jackpotTheme(dependencies.theme)
        .task { await model.load() }
    }
}
