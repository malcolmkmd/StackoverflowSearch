import Foundation

/// Serves bundled JSON and fakes the submit, so the feature runs before the endpoint is reachable.
public struct StubFormRepository: FormRepository {
    private let forms: [FormName: Data]
    private let delay: TimeInterval
    private let error: (any Error)?

    public init(forms: [FormName: Data], delay: TimeInterval = 0.35, error: (any Error)? = nil) {
        self.forms = forms
        self.delay = delay
        self.error = error
    }

    public func form(named name: FormName) async throws -> FormSchema {
        try await prepare()
        guard let data = forms[name] else { throw FormError.notFound(name) }
        return try Self.decode(data)
    }

    /// Succeeds with a fake account; fails for mobile `"0000000000"`, so the error path can be demoed.
    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        try await prepare()
        let mobile = submission["username"].stringValue
        if mobile == "0000000000" {
            throw FormError.server(message: "That mobile number is already registered. Try logging in instead.")
        }
        return FormSubmitResult(accountId: "27\(mobile)", message: "User Created Successfully.")
    }

    static func decode(_ data: Data) throws -> FormSchema {
        FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
    }

    private func prepare() async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let error { throw error }
    }
}
