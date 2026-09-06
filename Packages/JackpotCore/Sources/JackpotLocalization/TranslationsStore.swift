import Foundation
import Combine

/// Owns the session's translation table.
///
/// `Translations` is a value type with no home; something has to hold it for the life of the
/// session. This is that something — and, deliberately, **not** a singleton: it is created by
/// the composition root and injected, so tests and previews can have their own.
///
/// `ObservableObject` rather than `@Observable` because JackpotCore targets iOS 15. When the app
/// moves to 17 the change is mechanical — see the migration notes in the README.
@MainActor
public final class TranslationsStore: ObservableObject {

    @Published public private(set) var translations = Translations()
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: (any Error)?

    private let repository: any TranslationsRepository
    private var loadTask: Task<Void, Never>?

    public init(repository: any TranslationsRepository) {
        self.repository = repository
    }

    /// Whether the table has arrived. Screens can render placeholder copy until it has.
    public var isLoaded: Bool { !translations.isEmpty }

    /// Fetches once per session. Coalesced: concurrent callers share one request.
    public func load(region: String, tenant: String, locale: String) {
        guard loadTask == nil else { return }
        isLoading = true
        loadTask = Task { [weak self] in
            defer {
                self?.loadTask = nil
                self?.isLoading = false
            }
            guard let self else { return }
            do {
                self.translations = try await repository.translations(region: region, tenant: tenant, locale: locale)
                self.lastError = nil
            } catch is CancellationError {
            } catch {
                // A missing table is degraded, not fatal: every lookup falls back to its key,
                // so the app stays usable and QA can see which strings are missing.
                self.lastError = error
            }
        }
    }

    /// Adopts a table someone else fetched.
    ///
    /// This is the incremental-adoption seam. The legacy app already pulls app-data into
    /// `GlobalData.shareData.configData?.locale`; rather than fetching it twice during the
    /// migration, hand the existing dictionary over:
    ///
    /// ```swift
    /// translationsStore.adopt(
    ///     Translations(GlobalData.shareData.configData?.locale ?? [:],
    ///                  regionCode: GlobalData.shareData.AppSetupData.wmsNavigationRegionCode)
    /// )
    /// ```
    ///
    /// One call, at the point the legacy fetch completes. Nothing else in the old code changes.
    public func adopt(_ translations: Translations) {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        self.translations = translations
    }


    public func clear() {
        loadTask?.cancel()
        loadTask = nil
        translations = Translations()
    }

    deinit { loadTask?.cancel() }
}
