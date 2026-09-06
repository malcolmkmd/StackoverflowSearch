import SwiftUI
import JackpotFormsDomain

/// Everything `DynamicFormView` needs that isn't the form name or the callback.
///
/// Passing this through the SwiftUI environment is what keeps the public call site at
/// the two arguments the ticket asks for:
///
///     DynamicFormView(formName: .registration) { submission in ... }
///
/// while still injecting every dependency explicitly at the composition root:
///
///     RootView().formDependencies(.live(repository: repo))
public struct FormDependencies {
    public var repository: any FormRepository
    public var validator: FieldValidator
    public var localizer: any FormLocalizing
    public var passwordPolicy: any PasswordPolicyProviding
    /// Whether a dropdown option's *named* regex overrides another field's rule.
    ///
    /// Confirmed behaviour: the ID Number Type dropdown selects whether the user is entering a
    /// South African ID or a passport, and the ID Number field must validate accordingly.
    public var appliesOptionRegexToDependentField: Bool

    /// Explicit "this dropdown drives this field's regex" links, keyed by field identifier.
    ///
    /// Without this the link is *positional* — the field immediately after the dropdown — which
    /// works for the current schema but breaks silently if the CRM reorders rows or inserts a
    /// field between them. On a regulated field (SA ID vs passport) silent breakage is the wrong
    /// failure mode, so the known link is stated outright and the positional rule is only a
    /// fallback for links we haven't been told about.
    public var regexDependencies: [String: String]
    /// Latest date a `Calender` field allows. Defaults to 18 years ago: the form's
    /// only age gate today is the T&C checkbox, and a picker that cannot select an
    /// under-18 date is a cheap second line of defence.
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

    public static func live(repository: any FormRepository,
                           localizer: any FormLocalizing = ComposedKeyLocalizer()) -> FormDependencies {
        FormDependencies(repository: repository, localizer: localizer)
    }
}

private struct FormDependenciesKey: EnvironmentKey {
    /// Deliberately fatal: a form with no repository is a wiring bug, and a silent
    /// empty form would be much harder to diagnose than a clear crash in development.
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
        if assertsWhenCalled {
            assertionFailure("No FormDependencies in the environment. Call .formDependencies(_:) above DynamicFormView.")
        }
        throw CancellationError()
    }

    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        if assertsWhenCalled {
            assertionFailure("No FormDependencies in the environment. Call .formDependencies(_:) above DynamicFormView.")
        }
        throw CancellationError()
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
    /// Dependencies for previews: never fetches (previews seed the schema directly),
    /// but carries the real localizer so the copy matches the designs.
    static var preview: FormDependencies {
        FormDependencies(repository: UnavailableFormRepository(),
                         localizer: ComposedKeyLocalizer.jpcRegistration)
    }
}

#endif
