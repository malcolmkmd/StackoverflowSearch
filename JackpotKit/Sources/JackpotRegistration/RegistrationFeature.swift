import SwiftUI
import JackpotUI
import JackpotForms

public typealias RegistrationResult = FormSubmitResult

public struct RegistrationDependencies {
    public let forms: FormDependencies
    public let theme: JackpotTheme

    public init(forms: FormDependencies, theme: JackpotTheme = .jackpotCity, appSettings: AppSettings? = nil) {
        self.forms = forms.applyingRegistrationRules(devConfig: appSettings?.devConfig)
        self.theme = theme
    }

    public static func mock() -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock())
    }
}

extension FormDependencies {
    func applyingRegistrationRules(now: Date = Date(), devConfig: DevConfig? = nil) -> FormDependencies {
        var rules = self
        rules.regexDependencies = ["idNumber": "idNumberType"]
        rules.maximumDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: -18, to: now)
        if let devConfig {
            rules.passwordConfig = .init(devConfig)
        }
        return rules
    }
}

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
        JackpotPanel(model.translate("sign-up"), onClose: onClose) {
            DynamicFormContent(model: model)
        } footer: {
            VStack(spacing: .sm) {
                JackpotLinkRow(model.translate("already-have-account"),
                               link: model.translate("login"),
                               action: onLogin)
                FormNavigationBar(model: model, onComplete: onComplete)
            }
        }
        .jackpotTheme(theme)
        .environment(\.jackpotTranslate, model.translate)
        .task { await model.load() }
    }
}
