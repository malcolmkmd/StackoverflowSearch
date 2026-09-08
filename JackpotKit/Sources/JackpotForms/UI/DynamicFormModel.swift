import Foundation
import Combine

@MainActor
/// Owns the fetched schema, every value, touched state, errors and the visible section.
/// `ObservableObject` rather than `@Observable` because the floor is iOS 15.
public final class DynamicFormModel: ObservableObject {
    public enum ViewState: Equatable {
        case loading
        case loaded(FormSchema)
        case failed(String)
    }

    public enum PagingDirection: Equatable, Sendable {
        case forward
        case backward
    }

    // MARK: Published state
    @Published public private(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var errors: [String: String] = [:]
    @Published public private(set) var sectionIndex: Int = 0
    /// Set before `sectionIndex` changes, so the section transition slides the right way wherever the bar is.
    @Published public private(set) var pagingDirection: PagingDirection = .forward
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

    /// Types the schema asked for that this build cannot render; non-fatal, surfaced for QA.
    @Published public private(set) var unsupportedFields: [String] = []

    /// `@Published` so the reveal renders in the same update, not one late.
    @Published private var touched: Set<String> = []

    private let formName: FormName
    private let dependencies: FormDependencies

    public init(formName: FormName, dependencies: FormDependencies) {
        self.formName = formName
        self.dependencies = dependencies
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

    /// Fraction of required fields that validate; drives the progress bar.
    public var progress: Double {
        guard let form else { return 0 }
        let required = form.allFields.filter { $0.isVisible && $0.isRequired }
        guard !required.isEmpty else { return 1 }
        return Double(required.filter(isValid).count) / Double(required.count)
    }

    public var isCurrentSectionValid: Bool {
        guard let section = currentSection else { return false }
        return section.fields.filter(\.isVisible).allSatisfy(isValid)
    }

    public var isFormValid: Bool {
        guard let form else { return false }
        return form.allFields.filter(\.isVisible).allSatisfy(isValid)
    }

    public func value(for field: FormField) -> FormValue {
        values[field.identifier] ?? defaultValue(for: field)
    }

    /// Nil while the field is untouched.
    public func error(for field: FormField) -> String? {
        touched.contains(field.identifier) ? errors[field.identifier] : nil
    }

    public func localized(_ key: String) -> String { dependencies.localizer.display(key) }

    public func passwordRules(for field: FormField) -> [PasswordRule] {
        dependencies.passwordPolicy.rules(for: field)
    }

    public var maximumDate: Date { dependencies.maximumDate ?? Date() }

    // MARK: Loading

    /// A no-op once loaded, so re-appearing cannot reset a half-filled form; a failed load runs again.
    public func load() async {
        if case .loaded = viewState { return }
        viewState = .loading
        do {
            let form = try await dependencies.repository.form(named: formName)
            guard !Task.isCancelled else { return }
            apply(form)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            viewState = .failed(Self.message(for: error))
        }
    }

    private func apply(_ form: FormSchema) {
        viewState = .loaded(form)
        sectionIndex = 0
        touched = []
        errors = [:]
        values = Dictionary(uniqueKeysWithValues:
            form.allFields.filter(\.isVisible).map { ($0.identifier, defaultValue(for: $0)) }
        )
        unsupportedFields = form.allFields.compactMap {
            if case .unknown(let raw) = $0.type { return "\($0.identifier) (\(raw))" }
            return nil
        }
        revalidateAll()
    }

    private func defaultValue(for field: FormField) -> FormValue {
        switch field.type {
        case .checkbox:        return .bool(false)
        case .dropdown:        return .option("")
        case .input, .unknown: return field.inputType == .calendar ? .empty : .text("")
        }
    }

    // MARK: Editing

    public func setValue(_ value: FormValue, for field: FormField) {
        values[field.identifier] = value
        validate(field)
        // ID type → ID number: a dropdown can change another field's rule.
        if field.type == .dropdown { revalidateDependents(of: field) }
    }

    /// Call on blur. Re-touching is a no-op rather than another render.
    public func markTouched(_ field: FormField) {
        guard !touched.contains(field.identifier) else { return }
        touched.insert(field.identifier)
    }

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
        form?.allFields.filter(\.isVisible).forEach { validate($0) }
    }

    private func revalidateDependents(of field: FormField) {
        guard let form else { return }
        let dependents = form.allFields.filter { candidate in
            candidate.isVisible && regexDriver(for: candidate)?.id == field.id
        }
        dependents.forEach { validate($0) }
    }

    /// The dropdown that drives `field`'s regex, from `regexDependencies`.
    private func regexDriver(for field: FormField) -> FormField? {
        guard let form,
              let driverIdentifier = dependencies.regexDependencies.first(where: { $0.value == field.identifier })?.key,
              let driver = form.field(identifiedBy: driverIdentifier),
              driver.type == .dropdown
        else { return nil }
        return driver
    }

    /// Only *named* option regexes redirect; a literal pattern describes the selection itself.
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

    @discardableResult
    /// Advances if the section validates; otherwise reveals its errors.
    public func advance() -> Bool {
        guard let section = currentSection else { return false }
        touched.formUnion(section.fields.filter(\.isVisible).map(\.identifier))
        revalidateAll()
        guard isCurrentSectionValid else { return false }
        if !isLastSection {
            pagingDirection = .forward
            sectionIndex += 1
        }
        return true
    }

    public func goBack() {
        guard sectionIndex > 0 else { return }
        pagingDirection = .backward
        sectionIndex -= 1
    }

    // MARK: Submitting

    public func submit(_ handler: @escaping @MainActor (FormSubmission) async throws -> Void) async {
        guard let form else { return }
        touched.formUnion(form.allFields.filter(\.isVisible).map(\.identifier))
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

    private static func message(for error: any Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription { return localized }
        return "Something went wrong. Please try again."
    }
}

#if DEBUG
// Here because `private` is file-scoped, so previews can call `apply(_:)`.
public extension DynamicFormModel {
    /// A model already holding `schema`, so previews render without a fetch.
    static func preview(schema: FormSchema,
                        dependencies: FormDependencies = .mock(delay: 0),
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

    static func previewLoading() -> DynamicFormModel {
        DynamicFormModel(formName: FormName("preview"), dependencies: .mock(delay: 3600))
    }

    static func previewFailed(_ message: String = "The network connection was lost.") -> DynamicFormModel {
        let model = DynamicFormModel(formName: FormName("preview"), dependencies: .mock(delay: 0))
        model.viewState = .failed(message)
        return model
    }
}
#endif
