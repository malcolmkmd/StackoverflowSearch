import Foundation
import JackpotNetworking
import JackpotLocalization

/// Fetches the whole bootstrap payload and keeps only the strings.
public struct RemoteTranslationsRepository: TranslationsRepository {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) {
        self.apiClient = apiClient
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        let data = try await apiClient.requestData(
            AppDataRequest(region: region, tenant: tenant, locale: locale)
        )
        return Translations(try AppDataResponse(data: data).locales, regionCode: region)
    }
}
