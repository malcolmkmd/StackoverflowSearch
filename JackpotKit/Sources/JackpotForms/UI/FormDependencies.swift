import Foundation

/// Everything `DynamicFormView` needs besides the form name and the submit callback.
///
/// Defaults are the generic engine's: no cross-field regex links and no date cap. A feature
/// adds its own rules on top — see `RegistrationDependencies`.
public struct FormDependencies {
    public var repository: any FormRepository
    public var validator: FieldValidator
    public var localizer: any FormLocalizing
    public var passwordPolicy: any PasswordPolicyProviding
    /// "This dropdown drives this field's regex", keyed by the dropdown's identifier. When the
    /// selected option carries a *named* regex it replaces the dependent field's rule. Declared
    /// outright rather than inferred from row order, so a CRM reorder cannot silently relax
    /// validation on a regulated field.
    public var regexDependencies: [String: String]
    /// Latest date a calendar field may select. Nil means today.
    public var maximumDate: Date?

    public init(repository: any FormRepository,
                validator: FieldValidator = FieldValidator(),
                localizer: any FormLocalizing = ComposedKeyLocalizer(),
                passwordPolicy: any PasswordPolicyProviding = PasswordPolicy(),
                regexDependencies: [String: String] = [:],
                maximumDate: Date? = nil) {
        self.repository = repository
        self.validator = validator
        self.localizer = localizer
        self.passwordPolicy = passwordPolicy
        self.regexDependencies = regexDependencies
        self.maximumDate = maximumDate
    }
}

public extension FormDependencies {

    /// Serves the bundled `registration` schema, captured from
    /// `config.jpc.africa/cron/forms/jackpotcity/JZA/registration?api-version=2.0`, so the
    /// feature is buildable and reviewable before the API is reachable from the app.
    ///
    ///     DynamicFormView(formName: .registration, dependencies: .mock()) { … }
    ///
    /// - Parameters:
    ///   - delay: fake latency, so loading states are visible in the sandbox.
    ///   - error: set to exercise the failure state.
    ///   - localizer: where copy comes from; the bundled placeholder table by default.
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: BundledForms.all, delay: delay, error: error),
            localizer: localizer ?? ComposedKeyLocalizer.jpcRegistration
        )
    }
}
