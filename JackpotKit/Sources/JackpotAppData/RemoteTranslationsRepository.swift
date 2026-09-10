import Foundation
import JackpotNetworking
import JackpotLocalization

/// Adopt locales from a bootstrap payload the app already has. Do not fetch app-data a second time.
public struct RemoteTranslationsRepository: TranslationsRepository {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) {
        self.apiClient = apiClient
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        let data = try await apiClient.data(for: AppDataRequest(region: region, tenant: tenant, locale: locale))
        return Translations(try AppDataResponse(data: data).locales, regionCode: region)
    }
}
