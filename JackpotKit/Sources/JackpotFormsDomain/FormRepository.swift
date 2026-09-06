import Foundation

/// Fetches a form definition by name.
/// Implementation lives in JackpotFormsData; the UI only ever sees this.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
}
