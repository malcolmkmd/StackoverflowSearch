import Foundation

/// Everything `DynamicFormView` needs besides the form name and the callback. Defaults are generic; a
/// feature adds its rules on top.
public struct FormDependencies {
    public var repository: any FormRepository
    public var validator: FieldValidator
    public var localizer: any FormLocalizing
    public var passwordPolicy: any PasswordPolicyProviding
    /// "This dropdown drives this field's regex", by identifier. Declared, never inferred from row order.
    public var regexDependencies: [String: String]
    /// Latest date a calendar field may select; nil means today.
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
    /// The bundled registration schema behind fake latency, so loading states are visible.
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: BundledForms.all, delay: delay, error: error),
            localizer: localizer ?? ComposedKeyLocalizer.jpcRegistration
        )
    }
}
