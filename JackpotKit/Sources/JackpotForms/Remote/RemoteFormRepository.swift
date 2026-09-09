import Foundation
import JackpotNetworking

public struct RemoteFormRepository: FormRepository {
    private let apiClient: any ApiClient
    private let brand: String
    private let region: String
    private let translate: @Sendable (String) -> String

    public init(apiClient: any ApiClient,
                brand: String = "jackpotcity",
                region: String = "JZA",
                translate: @escaping @Sendable (String) -> String = { $0 }) {
        self.apiClient = apiClient
        self.brand = brand
        self.region = region
        self.translate = translate
    }

    public func form(named name: FormName) async throws -> FormSchema {
        do {
            let dto: FormDTO = try await apiClient.request(FormRequest(brand: brand, region: region, formName: name))
            return dto.schema
        } catch {
            throw userFacing(error, formName: name)
        }
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        do {
            let data = try await apiClient.requestData(FormSubmitRequest(submission))
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
    /// The real thing; swap `.mock()` for this at the call site. `baseURL` is the config host, the one app-data
    /// uses; `region` is `wmsNavigationRegionCode`; `translate` is the app's translation function, `{ getTranslation(Key: $0) }`.
    static func live(baseURL: URL,
                     brand: String = "jackpotcity",
                     region: String = "JZA",
                     translate: @escaping @Sendable (String) -> String) -> FormDependencies {
        let client = RemoteApiClient(environment: APIEnvironment(baseURL: baseURL))
        return FormDependencies(
            repository: RemoteFormRepository(apiClient: client, brand: brand, region: region, translate: translate),
            translate: translate
        )
    }
}
