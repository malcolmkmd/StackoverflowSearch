import Foundation
import JackpotNetworking

public struct RemoteFormRepository: FormRepository {
    private let apiClient: any ApiClient
    private let brand: String
    private let region: String
    /// Resolves error codes to localised copy; without it, the server's message.
    private let localizer: (any FormLocalizing)?

    public init(apiClient: any ApiClient,
                brand: String = "jackpotcity",
                region: String = "JZA",
                localizer: (any FormLocalizing)? = nil) {
        self.apiClient = apiClient
        self.brand = brand
        self.region = region
        self.localizer = localizer
    }

    public func form(named name: FormName) async throws -> FormSchema {
        do {
            let dto: FormDTO = try await apiClient.request(FormRequest(brand: brand, region: region, formName: name))
            return FormMapper.map(dto)
        } catch {
            throw FormErrorMapper.map(error, formName: name, localizer: localizer)
        }
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        do {
            let data = try await apiClient.requestData(FormSubmitRequest(submission))
            switch FormSubmitParser.parse(data) {
            case .accepted(let result):
                return result
            case .rejected(let error):
                let message = FormErrorMapper.message(code: error?.code ?? error?.displayCode,
                                                      server: error?.message, localizer: localizer)
                throw FormError.server(message: message ?? "We couldn't submit the form. Please try again.")
            }
        } catch {
            throw FormErrorMapper.map(error, formName: submission.formCodeName, localizer: localizer)
        }
    }
}
