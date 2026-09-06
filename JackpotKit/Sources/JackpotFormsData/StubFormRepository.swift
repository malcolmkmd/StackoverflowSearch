import Foundation
import JackpotFormsDomain

/// Serves forms from bundled JSON. Backs the demo harness and previews, and lets the
/// whole feature be built and reviewed before the endpoint is reachable from the app.
public struct StubFormRepository: FormRepository {
    private let forms: [FormName: Data]
    /// Seconds. (`Duration` is iOS 16 — this package targets 15.)
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
        return FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
    }

    public func form(id: String) async throws -> FormSchema {
        try await prepare()
        for data in forms.values {
            let form = FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
            if String(form.id) == id { return form }
        }
        throw FormLoadError.notFound(FormName(id))
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        try await prepare()
        return FormSubmitResult()
    }

    /// Decodes raw JSON straight to a `form` — handy in tests and previews.
    public static func decode(_ data: Data) throws -> FormSchema {
        FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
    }

    private func prepare() async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let error { throw error }
    }
}
