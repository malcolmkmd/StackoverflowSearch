import Foundation

/// Serves the bundled registration schema and fakes the submit, so the feature runs before the endpoint is reachable.
public struct StubFormRepository: FormRepository {
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.35) {
        self.delay = delay
    }

    public func form(named name: FormName) async throws -> FormSchema {
        try await pause()
        guard name == .registration else { throw FormError.notFound(name) }
        return try JSONDecoder().decode(FormDTO.self, from: Self.registrationJSON).schema
    }

    /// Succeeds with a fake account; fails for mobile `"0000000000"`, so the error path can be demoed.
    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        try await pause()
        let mobile = submission["username"].stringValue
        if mobile == "0000000000" {
            throw FormError.server(message: "That mobile number is already registered. Try logging in instead.")
        }
        return FormSubmitResult(accountId: "27\(mobile)", message: "User Created Successfully.")
    }

    /// `registration.json` is the CRM's response saved verbatim.
    static let registrationJSON = try! Data(contentsOf: Bundle.module.url(forResource: "registration", withExtension: "json")!)

    private func pause() async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
