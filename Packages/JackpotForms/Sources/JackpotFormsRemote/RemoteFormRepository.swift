import Foundation
import JackpotNetworking
import JackpotFormsData
import JackpotFormsDomain

public struct RemoteFormRepository: FormRepository {
    private let apiClient: any ApiClient
    private let brand: String
    private let region: String
    /// Resolves error codes to localised copy. Optional: without it, errors fall back to the
    /// server's own message.
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
            let dto: FormDTO = try await apiClient.request(
                FormRequest(brand: brand, region: region, formName: name)
            )
            return FormMapper.map(dto)
        } catch {
            // Translate here, at the layer boundary — the UI can't see APIError.
            throw FormErrorMapper.map(error, formName: name, localizer: localizer)
        }
    }
}
