import Foundation

/// Contract for form data operations: fetch a definition and submit it.
///
/// Fetch-by-name and fetch-by-id share one URL:
/// `GET {cron}/forms/{brand}/{region}/{identifier}?api-version=2.0`.
/// Submit posts a `FormSubmission` to `{cron}/forms/submit`.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func form(id: String) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
}

public extension FormRepository {
    func form(id: String) async throws -> FormSchema {
        throw FormLoadError.notFound(FormName(id))
    }
}
