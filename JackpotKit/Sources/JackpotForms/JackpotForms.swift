import Foundation
import JackpotNetworking
import JackpotFormsDomain
import JackpotFormsUI
import JackpotLocalization
import JackpotFormsData
import JackpotFormsRemote

// The composition target: the one place that knows both how forms are fetched (Data) and how
// they are rendered (UI). Every other dependency stays one-directional.

public extension FormDependencies {

    /// Serves the bundled `registration` schema, captured from
    /// `config.jpc.africa/cron/forms/jackpotcity/JZA/registration?api-version=2.0`, so the
    /// feature is buildable and reviewable before the API is reachable from the app.
    ///
    ///     DynamicFormView(formName: .registration) { ... }
    ///         .formDependencies(.mock())
    ///
    /// - Parameters:
    ///   - delay: fake latency, so loading states are visible in the sandbox.
    ///   - error: set to exercise the failure state.
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     translations: Translations? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: FormPreviewData.bundledForms, delay: delay, error: error),
            localizer: localizer
                ?? translations.map(TranslationsLocalizer.init)
                ?? ComposedKeyLocalizer.jpcRegistration
        )
    }

    /// The real thing. Swap `.mock()` for this at the call site — nothing else changes, because
    /// `DynamicFormView` only ever sees the `FormRepository` protocol.
    ///
    ///     .formDependencies(.live(baseURL: URL(string: "https://config.jpc.africa/crm")!))
    ///
    /// `baseURL` may be the historical CRM URL; fetch and submit both run on the sibling cron
    /// service. `region` should be `AppSetupData.wmsNavigationRegionCode`.
    /// - Parameter translations: the session's locale table, from the once-per-session app-data
    ///   call. Supplying it resolves labels, placeholders and dropdown options through the real
    ///   CRM copy, and turns API error *codes* into localised sentences.
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

public extension FormSandboxView {
    /// The sandbox, wired to the bundled schemas.
    static func mocked() -> FormSandboxView {
        FormSandboxView(
            samples: [
                .init(id: .registration, title: "Registration"),
                .init(id: .kitchenSink, title: "All field types"),
            ],
            dependencies: .mock()
        )
    }
}
