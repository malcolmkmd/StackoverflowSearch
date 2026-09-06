import Foundation
import JackpotNetworking
import JackpotAppData

public protocol TranslationsRepository: Sendable {
    func translations(region: String, tenant: String, locale: String) async throws -> Translations
}

public struct RemoteTranslationsRepository: TranslationsRepository {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) {
        self.apiClient = apiClient
    }

    /// Fetches the whole bootstrap payload and keeps only the strings. Once more than one
    /// feature needs it, one caller should fetch `AppDataResponse` and hand it round instead.
    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        let data = try await apiClient.requestData(
            AppDataRequest(region: region, tenant: tenant, locale: locale)
        )
        return Translations(try AppDataResponse(data: data).locales, regionCode: region)
    }
}

/// Fixed table, for previews and tests.
public struct StubTranslationsRepository: TranslationsRepository {
    private let table: Translations

    public init(_ table: Translations) {
        self.table = table
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        table
    }
}
