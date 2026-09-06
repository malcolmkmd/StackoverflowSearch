import Foundation
import Combine
import JackpotFormsDomain

/// The engine. Owns the fetched schema, every field's value, touched state and errors,
/// and which section (page) is showing.
///
/// `ObservableObject` rather than `@Observable` because this package targets iOS 15.
/// The upgrade is mechanical when the app moves to 17 — see the guide, "iOS 15 seams".
@MainActor
public final class DynamicFormModel: ObservableObject {

    public enum ViewState: Equatable {
        case loading
        case loaded(FormSchema)
        case failed(String)
    }

    // MARK: Published state
    @Published public internal(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var errors: [String: String] = [:]
    @Published public internal(set) var sectionIndex: Int = 0
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

    /// Field types the schema asked for that this build cannot render. Non-fatal by
    /// design (see `FieldType.unknown`); surfaced so QA and logs can see them.
    @Published public private(set) var unsupportedFields: [String] = []

    /// Published: `objectWillChange` has to fire *before* the set changes, or the error it
    /// reveals lands a render late.
    @Published private var touched: Set<String> = []

    // MARK: Inputs
    private let formName: FormName
    private var dependencies: FormDependencies
    private var isConfigured: Bool
    private var loadTask: Task<Void, Never>?

    /// - Parameter isConfigured: true when the caller supplied real dependencies. The
    ///   two-argument `DynamicFormView.init` passes false and lets `configureIfNeeded`
    ///   swap in the environment's copy on first appearance — `@StateObject` cannot
    ///   read `@Environment` from an initializer.
    public init(formName: FormName, dependencies: FormDependencies, isConfigured: Bool = true) {
        self.formName = formName
        self.dependencies = dependencies
        self.isConfigured = isConfigured
    }

    /// Adopts environment-provided dependencies exactly once. No-op afterwards, so a
    /// re-render never resets a half-filled form.
    public func configureIfNeeded(with dependencies: FormDependencies) {
        guard !isConfigured else { return }
        self.dependencies = dependencies
        isConfigured = true
    }

    // MARK: Derived

    public var form: FormSchema? {
        if case .loaded(let form) = viewState { return form }
        return nil
    }

    public var sections: [FormSection] { form?.sections ?? [] }
    public var currentSection: FormSection? {
        sections.indices.contains(sectionIndex) ? sections[sectionIndex] : nil
    }
    public var isFirstSection: Bool { sectionIndex == 0 }
    public var isLastSection: Bool { sectionIndex >= sections.count - 1 }

    /// Fraction of all required fields across the whole form that currently validate.
    /// Drives the progress bar at the top of the panel.
    public var progress: Double {
        guard let form else { return 0 }
        let required = form.allFields.filter { $0.carriesValue && $0.isRequired }
        guard !required.isEmpty else { return isLastSection ? 1 : 0 }
        let satisfied = required.filter { isValid($0) }.count
        return Double(satisfied) / Double(required.count)
    }

    /// Whether the visible section can be advanced past / submitted.
    public var isCurrentSectionValid: Bool {
        guard let section = currentSection else { return false }
        return section.fields.filter(\.carriesValue).allSatisfy(isValid)
    }

    public var isFormValid: Bool {
        guard let form else { return false }
        return form.allFields.filter(\.carriesValue).allSatisfy(isValid)
    }

    public func value(for field: FormField) -> FormValue {
        values[field.identifier] ?? defaultValue(for: field)
    }

    /// Error text for a field, or nil while it is untouched.
    public func error(for field: FormField) -> String? {
        touched.contains(field.identifier) ? errors[field.identifier] : nil
    }

    public func localized(_ key: String) -> String { dependencies.localizer.display(key) }

    public func passwordRules(for field: FormField) -> [PasswordRule] {
        dependencies.passwordPolicy.rules(for: field)
    }

    public var maximumDateOfBirth: Date { dependencies.maximumDateOfBirth }

    // MARK: Loading

    public func load() {
        loadTask?.cancel()
        viewState = .loading
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let form = try await dependencies.repository.form(named: formName)
                guard !Task.isCancelled else { return }
                self.apply(form)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                self.viewState = .failed(Self.message(for: error))
            }
        }
    }

    private func apply(_ form: FormSchema) {
        viewState = .loaded(form)
        sectionIndex = 0
        touched = []
        errors = [:]
        values = Dictionary(uniqueKeysWithValues:
            form.allFields.filter(\.carriesValue).map { ($0.identifier, defaultValue(for: $0)) }
        )
        unsupportedFields = form.allFields.compactMap {
            if case .unknown(let raw) = $0.type { return "\($0.identifier) (\(raw))" }
            return nil
        }
        revalidateAll()
    }

    private func defaultValue(for field: FormField) -> FormValue {
        switch field.type {
        case .checkbox, .toggle: return .bool(false)
        case .dropdown, .radio, .radioGroup: return .option("")
        default: return field.inputType == .calendar ? .empty : .text("")
        }
    }

    // MARK: Editing

    public func setValue(_ value: FormValue, for field: FormField) {
        values[field.identifier] = value
        validate(field)
        // A dropdown can change a dependent field's rule (ID type → ID number), so
        // anything downstream of it has to be re-checked, not just this field.
        if field.type == .dropdown, dependencies.appliesOptionRegexToDependentField {
            revalidateDependents(of: field)
        }
    }

    /// Call on blur, or on first edit, so errors don't appear before the user has typed.
    /// Re-touching is a no-op rather than another render — the return key marks a field on
    /// submit and then again on the blur that follows.
    public func markTouched(_ field: FormField) {
        guard !touched.contains(field.identifier) else { return }
        touched.insert(field.identifier)
    }

    /// Focus navigation only carries identifiers.
    public func markTouched(identifiedBy identifier: String) {
        guard let field = form?.field(identifiedBy: identifier) else { return }
        markTouched(field)
    }

    // MARK: Validation

    private func isValid(_ field: FormField) -> Bool {
        errors[field.identifier] == nil
    }

    @discardableResult
    private func validate(_ field: FormField) -> Bool {
        let result = dependencies.validator.validate(
            value(for: field),
            against: field,
            overrideRegex: overrideRegex(for: field)
        )
        switch result {
        case .valid:
            errors[field.identifier] = nil
            return true
        case .invalid:
            errors[field.identifier] = dependencies.localizer.validationMessage(for: field)
            return false
        }
    }

    private func revalidateAll() {
        form?.allFields.filter(\.carriesValue).forEach { validate($0) }
    }

    private func revalidateDependents(of field: FormField) {
        guard let form else { return }
        let dependents = form.allFields.filter { candidate in
            candidate.carriesValue && regexDriver(for: candidate)?.id == field.id
        }
        dependents.forEach { validate($0) }
    }

    /// The dropdown that drives `field`'s regex, if any.
    ///
    /// Links are declared in `FormDependencies.regexDependencies`, never inferred from field
    /// order. An earlier version fell back to "the dropdown immediately before this field",
    /// which worked for the current schema but would have re-enabled silent breakage on a
    /// reorder — the exact fragility declaring the link was meant to remove.
    private func regexDriver(for field: FormField) -> FormField? {
        guard dependencies.appliesOptionRegexToDependentField,
              let form,
              let driverIdentifier = dependencies.regexDependencies.first(where: { $0.value == field.identifier })?.key,
              let driver = form.field(identifiedBy: driverIdentifier),
              driver.type == .dropdown
        else { return nil }
        return driver
    }

    /// The pattern a dropdown's current selection imposes on `field`, if any.
    ///
    /// Only *named* regexes redirect. `idNumberType`'s options carry `"idNumberRegex"` /
    /// `"passportNumberRegex"` — names — while `sourceOfFunds`'s carry `"[a-zA-Z]"`, a literal
    /// pattern that describes the selection itself and must not leak onto another field.
    private func overrideRegex(for field: FormField) -> String? {
        guard let driver = regexDriver(for: field),
              case .option(let selected) = value(for: driver),
              !selected.isEmpty,
              let option = driver.dropdownOptions.first(where: { $0.value == selected }),
              let raw = option.regex,
              !raw.looksLikeRegexPattern
        else { return nil }

        return dependencies.validator.optionPattern(raw)
    }

    // MARK: Paging

    /// Advances if the visible section validates; otherwise reveals its errors.
    @discardableResult
    public func advance() -> Bool {
        guard let section = currentSection else { return false }
        touched.formUnion(section.fields.filter(\.carriesValue).map(\.identifier))
        revalidateAll()
        guard isCurrentSectionValid else { return false }
        if !isLastSection { sectionIndex += 1 }
        return true
    }

    public func goBack() {
        guard sectionIndex > 0 else { return }
        sectionIndex -= 1
    }

    // MARK: Submitting

    public func submit(_ handler: @escaping (FormSubmission) async throws -> Void) async {
        guard let form else { return }
        touched.formUnion(form.allFields.filter(\.carriesValue).map(\.identifier))
        revalidateAll()
        guard isFormValid else { return }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            try await handler(FormSubmission(
                formCodeName: form.codeName,
                values: values,
                formId: String(form.id)
            ))
        } catch is CancellationError {
        } catch {
            submitError = Self.message(for: error)
        }
    }

    deinit { loadTask?.cancel() }

    private static func message(for error: any Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription { return localized }
        return "Something went wrong. Please try again."
    }
}

#if DEBUG
// Preview support. Lives in this file because `apply(_:)` is private, and `private`
// in Swift is file-scoped — so an extension here can seed a model without widening
// the type's real API.
public extension DynamicFormModel {

    /// A model already holding `schema`, with no async load — previews render instantly
    /// and deterministically instead of flashing a skeleton.
    static func preview(schema: FormSchema,
                        dependencies: FormDependencies = .preview,
                        values: [String: FormValue] = [:],
                        touched: [String] = [],
                        sectionIndex: Int = 0) -> DynamicFormModel {
        let model = DynamicFormModel(formName: schema.codeName, dependencies: dependencies)
        model.apply(schema)
        for (identifier, value) in values {
            guard let field = schema.field(identifiedBy: identifier) else { continue }
            model.setValue(value, for: field)
        }
        for identifier in touched {
            guard let field = schema.field(identifiedBy: identifier) else { continue }
            model.markTouched(field)
        }
        model.sectionIndex = min(max(0, sectionIndex), max(0, schema.sections.count - 1))
        return model
    }

    /// Stuck on the loading state, for previewing the skeleton.
    static func previewLoading(dependencies: FormDependencies = .preview) -> DynamicFormModel {
        DynamicFormModel(formName: FormName("preview"), dependencies: dependencies)
    }

    /// Parked on the failure state.
    static func previewFailed(_ message: String = "The network connection was lost.") -> DynamicFormModel {
        let model = DynamicFormModel(formName: FormName("preview"), dependencies: .preview)
        model.viewState = .failed(message)
        return model
    }
}
#endif
