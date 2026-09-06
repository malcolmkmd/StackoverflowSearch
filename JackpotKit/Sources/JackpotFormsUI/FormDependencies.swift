import SwiftUI
import JackpotFormsDomain

/// Everything `DynamicFormView` needs that isn't the form name or the callback.
///
/// Carried through the environment so the public call site stays at two arguments —
/// `DynamicFormView(formName: .registration) { submission in ... }` — while every dependency
/// is still injected explicitly at the composition root.
public struct FormDependencies {
    public var repository: any FormRepository
    public var validator: FieldValidator
    public var localizer: any FormLocalizing
    public var passwordPolicy: any PasswordPolicyProviding
    /// Whether a dropdown option's *named* regex overrides another field's rule. The ID Number
    /// Type dropdown selects SA ID vs passport, and ID Number must validate accordingly.
    public var appliesOptionRegexToDependentField: Bool

    /// Explicit "this dropdown drives this field's regex" links, keyed by driver identifier.
    /// Stated outright rather than inferred from row order, so a CRM reorder cannot silently
    /// relax validation on a regulated field.
    public var regexDependencies: [String: String]
    /// Latest date a `Calender` field allows. Defaults to 18 years ago: the form's only age gate
    /// today is the T&C checkbox, and a picker that cannot select an under-18 date is a cheap
    /// second line of defence.
    public var maximumDateOfBirth: Date

    public init(repository: any FormRepository,
                validator: FieldValidator = FieldValidator(),
                localizer: any FormLocalizing = ComposedKeyLocalizer(),
                passwordPolicy: any PasswordPolicyProviding = PasswordPolicy(),
                appliesOptionRegexToDependentField: Bool = true,
                regexDependencies: [String: String] = ["idNumberType": "idNumber"],
                maximumDateOfBirth: Date = Calendar(identifier: .gregorian)
                    .date(byAdding: .year, value: -18, to: Date()) ?? Date()) {
        self.repository = repository
        self.validator = validator
        self.localizer = localizer
        self.passwordPolicy = passwordPolicy
        self.appliesOptionRegexToDependentField = appliesOptionRegexToDependentField
        self.regexDependencies = regexDependencies
        self.maximumDateOfBirth = maximumDateOfBirth
    }
}

private struct FormDependenciesKey: EnvironmentKey {
    static var defaultValue: FormDependencies {
        FormDependencies(repository: UnavailableFormRepository(assertsWhenCalled: true))
    }
}

/// Never returns a form. Used wherever a repository is structurally required but must not be
/// called: the environment default (which asserts, because reaching it means the caller forgot
/// `.formDependencies(_:)`), the placeholder a two-argument `DynamicFormView` holds until
/// `.task` swaps in the environment's, and previews that seed a model directly.
struct UnavailableFormRepository: FormRepository {
    let assertsWhenCalled: Bool

    init(assertsWhenCalled: Bool = false) {
        self.assertsWhenCalled = assertsWhenCalled
    }

    func form(named name: FormName) async throws -> FormSchema {
        assertConfigured()
        throw CancellationError()
    }

    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        assertConfigured()
        throw CancellationError()
    }

    private func assertConfigured() {
        if assertsWhenCalled {
            assertionFailure("No FormDependencies in the environment. Call .formDependencies(_:) above DynamicFormView.")
        }
    }
}

public extension EnvironmentValues {
    var formDependencies: FormDependencies {
        get { self[FormDependenciesKey.self] }
        set { self[FormDependenciesKey.self] = newValue }
    }
}

public extension View {
    func formDependencies(_ dependencies: FormDependencies) -> some View {
        environment(\.formDependencies, dependencies)
    }
}

#if DEBUG
public extension FormDependencies {
    /// Never fetches — previews seed the schema directly — but carries the real localizer so
    /// the copy matches the designs.
    static var preview: FormDependencies {
        FormDependencies(repository: UnavailableFormRepository(),
                         localizer: ComposedKeyLocalizer.jpcRegistration)
    }
}
#endif
