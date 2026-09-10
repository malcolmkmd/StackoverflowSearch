import Foundation
import Combine

@MainActor
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

    @Published public private(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var sectionIndex: Int = 0
    @Published public private(set) var pagingDirection: PagingDirection = .forward
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

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

    public var progress: Double {
        guard let form else { return 0 }
        let required = form.allFields.filter { $0.isVisible && $0.isRequired }
        guard !required.isEmpty else { return 1 }
        return Double(required.filter(isValid).count) / Double(required.count)
    }

    public var isCurrentSectionValid: Bool {
        guard let section = currentSection else { return false }
        return section.fields.allSatisfy(isValid)
    }

    public var isFormValid: Bool {
        guard let form else { return false }
        return form.allFields.allSatisfy(isValid)
    }

    public func value(for field: FormField) -> FormValue {
        values[field.identifier] ?? defaultValue(for: field)
    }

    /// Nil while the field is untouched. Every field carries `validationMessage: "regex"`, so the key is composed:
    /// `jpc-reg-{identifier}-{key}`.
    public func error(for field: FormField) -> String? {
        guard touched.contains(field.identifier), !isValid(field) else { return nil }
        return translate("jpc-reg-\(field.identifier)-\(field.validationMessageKey)")
    }

    public var translate: @Sendable (String) -> String { dependencies.translate }

    public var maximumDate: Date { dependencies.maximumDate ?? Date() }

    public var passwordConfig: PasswordSuggestions.Config { dependencies.passwordConfig }

    /// A no-op once loaded, so re-appearing cannot reset a half-filled form.
    public func load() async {
        if case .loaded = viewState { return }
        viewState = .loading
        do {
            let form = try await dependencies.repository.form(named: formName)
            values = Dictionary(uniqueKeysWithValues:
                form.allFields.filter(\.isVisible).map { ($0.identifier, defaultValue(for: $0)) }
            )
            viewState = .loaded(form)
        } catch is CancellationError {
        } catch {
            viewState = .failed(Self.message(for: error))
        }
    }

    private func defaultValue(for field: FormField) -> FormValue {
        switch field.type {
        case .checkbox:                              return .bool(false)
        case .input, .dropdown, .recaptchaV3, .unknown:
            return field.inputType == .calendar ? .empty : .text("")
        }
    }

    public func setValue(_ value: FormValue, for field: FormField) {
        values[field.identifier] = value
    }

    public func markTouched(_ identifier: String) {
        guard !touched.contains(identifier) else { return }
        touched.insert(identifier)
    }

    private func isValid(_ field: FormField) -> Bool {
        field.accepts(value(for: field), overrideRegex: overrideRegex(for: field))
    }

    /// ID type → ID number: Passport relaxes the thirteen-digit rule.
    private func overrideRegex(for field: FormField) -> String? {
        guard let driver = dependencies.regexDependencies[field.identifier].flatMap({ form?.field(identifiedBy: $0) }),
              let option = driver.dropdownOptions.first(where: { $0.value == value(for: driver).stringValue }),
              let name = option.regex
        else { return nil }
        return dependencies.namedPatterns[name]
    }

    public func advance() {
        guard isCurrentSectionValid, !isLastSection else { return }
        pagingDirection = .forward
        sectionIndex += 1
    }

    public func goBack() {
        guard sectionIndex > 0 else { return }
        pagingDirection = .backward
        sectionIndex -= 1
    }

    public func submit() async -> FormSubmitResult? {
        guard let form, isFormValid else { return nil }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            var token: String?
            if form.hasRecaptcha {
                token = try await dependencies.recaptcha(form.codeName.recaptchaAction)
            }
            return try await dependencies.repository.submitForm(
                FormSubmission(formCodeName: form.codeName,
                               values: values,
                               recaptcha: token,
                               formId: String(form.id))
            )
        } catch is CancellationError {
        } catch {
            submitError = Self.message(for: error)
        }
        return nil
    }

    private static func message(for error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
    }
}
