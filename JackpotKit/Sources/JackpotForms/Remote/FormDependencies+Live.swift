import Foundation
import JackpotNetworking

public extension FormDependencies {
    /// The real thing; swap `.mock()` for this at the call site. `baseURL` may be the historical CRM URL and
    /// `region` is `wmsNavigationRegionCode`. `localizer` is the app's wrapped translation function, a
    /// `Translations.formLocalizer` once the app adopts `JackpotLocalization`.
    static func live(baseURL: URL,
                     brand: String = "jackpotcity",
                     region: String = "JZA",
                     bearerToken: (@Sendable () async -> String?)? = nil,
                     localizer: any FormLocalizing = ClosureLocalizer.jpcRegistration) -> FormDependencies {
        let interceptors: [any RequestInterceptor] = bearerToken.map { [BearerTokenInterceptor(token: $0)] } ?? []
        let client = RemoteApiClient(
            environment: .cron(baseURL: APIEnvironment.cronBaseURL(fromCRM: baseURL)),
            interceptors: interceptors
        )
        return FormDependencies(
            repository: RemoteFormRepository(apiClient: client, brand: brand, region: region,
                                             localizer: localizer),
            localizer: localizer
        )
    }
}
