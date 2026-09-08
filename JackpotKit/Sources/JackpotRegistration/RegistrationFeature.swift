import SwiftUI
import JackpotUI
import JackpotForms

/// What Sign Up hands back: the account id, the session token under `compliance`, and `isPartial` when FICA
/// still needs a manual upload.
public typealias RegistrationResult = FormSubmitResult

/// Everything the feature needs, supplied by the app where it's presented.
public struct RegistrationDependencies {
    /// `.mock(localizer:)` until networking lands, `.live(baseURL:localizer:)` after; registration's rules are applied on top.
    public let forms: FormDependencies
    public let theme: JackpotTheme

    public init(forms: FormDependencies, theme: JackpotTheme = .jackpotCity) {
        self.forms = forms.applyingRegistrationRules()
        self.theme = theme
    }

    /// Bundled schema and a faked submit: no backend, no app.
    public static func mock(localizer: (any FormLocalizing)? = nil) -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock(localizer: localizer))
    }
}

extension FormDependencies {
    /// The ID-type dropdown decides the ID-number regex, and the date-of-birth picker cannot select an under-18 date.
    func applyingRegistrationRules(now: Date = Date()) -> FormDependencies {
        var rules = self
        rules.regexDependencies = ["idNumberType": "idNumber"]
        rules.maximumDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: -18, to: now)
        return rules
    }
}

/// The Sign Up sheet: the two-page form inside `JackpotPanel`, the login row and navigation in the footer.
/// The shell's copy is fixed here, like the Next / Previous labels, until the app-data keys are known.
public struct RegistrationView: View {
    private let theme: JackpotTheme
    private let onClose: () -> Void
    private let onLogin: () -> Void
    private let onComplete: (RegistrationResult) -> Void
    @StateObject private var model: DynamicFormModel

    public init(dependencies: RegistrationDependencies,
                onClose: @escaping () -> Void,
                onLogin: @escaping () -> Void,
                onComplete: @escaping (RegistrationResult) -> Void) {
        self.theme = dependencies.theme
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
                FormNavigationBar(model: model, onComplete: onComplete)
            }
        }
        .jackpotTheme(theme)
        .task { await model.load() }
    }
}
