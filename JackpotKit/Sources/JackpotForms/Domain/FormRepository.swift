import Foundation

/// Contract for form data operations: fetch a definition by name and submit it.
///
/// Fetch is `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`; submit posts a
/// `FormSubmission` to `{cron}/forms/submit`.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
}
