import Foundation

/// Contract for form data operations: fetch a definition, submit it, and (when the
/// backend supports it) persist a draft.
///
/// Fetch-by-name and fetch-by-id share one URL:
/// `GET {cron}/forms/{brand}/{region}/{identifier}?api-version=2.0`.
/// Submit posts a `FormSubmission` to `{cron}/forms/submit`. Drafts exist on the
/// protocol because the production repository declares them; the current backend
/// stubs `saveDraft` as always-ok and `loadDraft` as empty.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func form(id: String) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
    func saveDraft(_ submission: FormSubmission) async throws -> Bool
    func loadDraft(formId: String) async throws -> FormSubmission?
}

public extension FormRepository {
    func form(id: String) async throws -> FormSchema {
        throw FormLoadError.notFound(FormName(id))
    }

    /// Production stub: always succeeds. Override to persist.
    func saveDraft(_ submission: FormSubmission) async throws -> Bool { true }

    /// Production stub: no draft. Override to return one.
    func loadDraft(formId: String) async throws -> FormSubmission? { nil }
}
