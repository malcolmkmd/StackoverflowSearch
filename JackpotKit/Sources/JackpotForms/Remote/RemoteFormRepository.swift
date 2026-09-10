import Foundation
import JackpotNetworking

public struct RemoteFormRepository: FormRepository {
    private let form: FormSchema
    private let apiClient: any ApiClient
    private let translate: @Sendable (String) -> String

    public init(form: FormSchema = FormSchema(id: 0, codeName: .registration, sections: []),
                apiClient: any ApiClient,
                translate: @escaping @Sendable (String) -> String = { $0 }) {
        self.form = form
        self.apiClient = apiClient
        self.translate = translate
    }

    public func form(named name: FormName) async throws -> FormSchema {
        guard name == form.codeName else { throw FormError.notFound(name) }
        return form
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        do {
            let data = try await apiClient.data(for: FormSubmitRequest(submission))
            // An empty 2xx is taken as accepted (an assumption); anything else must say `isSuccessful: true`.
            if data.isEmpty { return FormSubmitResult() }
            let envelope = try? JSONDecoder().decode(FormSubmitEnvelope.self, from: data)
            guard let envelope, envelope.isSuccessful == true else {
                let failure = envelope?.error
                throw FormError.server(message: message(code: failure?.code ?? failure?.displayCode, server: failure?.message)
                                       ?? "We couldn't submit the form. Please try again.")
            }
            return envelope.data ?? FormSubmitResult()
        } catch {
            throw userFacing(error, formName: submission.formCodeName)
        }
    }

    // MARK: Errors

    /// Where transport errors become something a person can read; the engine never sees `APIError`.
    func userFacing(_ error: any Error, formName: FormName) -> any Error {
        guard let apiError = error as? APIError else { return error }
        switch apiError {
        // A cancelled load is a navigation event, not a failure.
        case .cancelled:
            return CancellationError()
        case .transport where apiError.isOffline:
            return FormError.offline
        case .unexpectedStatus(404, _):
            return FormError.notFound(formName)
        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            return message(code: apiError.problem?.code, server: apiError.serverMessage)
                .map { FormError.server(message: $0) } ?? FormError.unexpected
        case .transport, .decoding, .invalidURL:
            return FormError.unexpected
        }
    }

    /// Error codes are translation keys, `jpc-reg-error.{code}` for registration and the bare number elsewhere;
    /// an untranslated key falls back to the server's wording.
    func message(code: Int?, server: String?) -> String? {
        for key in code.map({ ["jpc-reg-error.\($0)", String($0)] }) ?? [] {
            let copy = translate(key)
            if copy != key { return copy }
        }
        return server
    }
}

public extension FormDependencies {
    static func live(form: FormSchema,
                     baseURL: URL,
                     translate: @escaping @Sendable (String) -> String,
                     recaptcha: @escaping @Sendable (String) async throws -> String?) -> FormDependencies {
        let client = RemoteApiClient(environment: APIEnvironment(baseURL: baseURL))
        return FormDependencies(
            repository: RemoteFormRepository(form: form, apiClient: client, translate: translate),
            translate: translate,
            recaptcha: recaptcha
        )
    }

    static func live(formJSON: Data,
                     baseURL: URL,
                     translate: @escaping @Sendable (String) -> String,
                     recaptcha: @escaping @Sendable (String) async throws -> String?) throws -> FormDependencies {
        try live(form: FormSchema(json: formJSON), baseURL: baseURL, translate: translate, recaptcha: recaptcha)
    }
}
