import Foundation

/// Serves bundled JSON, so the feature runs before the endpoint is reachable.
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
        guard let data = forms[name] else { throw FormLoadError.notFound(name) }
        return try Self.decode(data)
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        try await prepare()
        return FormSubmitResult()
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
