import Foundation

/// Fetch is `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`; submit posts to `{cron}/forms/submit`.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
}
