import Foundation

public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
}
