import Foundation
import JackpotNetworking
import JackpotLocalization

public extension FormDependencies {

    /// The real thing. Swap `.mock()` for this at the call site and nothing else changes,
    /// because `DynamicFormView` only ever sees the `FormRepository` protocol.
    ///
    ///     DynamicFormView(formName: .registration,
    ///                     dependencies: .live(baseURL: URL(string: "https://config.jpc.africa/crm")!)) { … }
    ///
    /// `baseURL` may be the historical CRM URL; fetch and submit both run on the sibling cron
    /// service. `region` should be `AppSetupData.wmsNavigationRegionCode`.
    /// - Parameter translations: the session's locale table, from the once-per-session app-data
    ///   call. Supplying it resolves labels and dropdown options through the real CRM copy, and
    ///   turns API error *codes* into localised sentences.
    /// - Parameter localizer: overrides the table-derived localizer. During the migration the
    ///   app passes a `ClosureLocalizer` over its existing `getTranslation`; once
    ///   `JackpotLocalization` is adopted, omit it and pass `translations` instead.
    static func live(baseURL: URL,
                     translations: Translations = Translations(),
                     brand: String = "jackpotcity",
                     region: String = "JZA",
                     bearerToken: (@Sendable () async -> String?)? = nil,
                     localizer explicitLocalizer: (any FormLocalizing)? = nil) -> FormDependencies {
        let interceptors: [any RequestInterceptor] = bearerToken.map { [BearerTokenInterceptor(token: $0)] } ?? []
        let client = RemoteApiClient(
            environment: .cron(baseURL: APIEnvironment.cronBaseURL(fromCRM: baseURL)),
            interceptors: interceptors
        )
        // An empty table means app-data hasn't landed yet; the bundled placeholder copy keeps
        // the form legible rather than rendering raw keys.
        let localizer: any FormLocalizing = explicitLocalizer
            ?? (translations.isEmpty ? ComposedKeyLocalizer.jpcRegistration : TranslationsLocalizer(translations))

        return FormDependencies(
            repository: RemoteFormRepository(apiClient: client, brand: brand, region: region,
                                             localizer: localizer),
            localizer: localizer
        )
    }
}
