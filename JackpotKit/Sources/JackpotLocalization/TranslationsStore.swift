import Foundation
import Combine

/// Owns the session's translation table.
///
/// `Translations` is a value type with no home; something has to hold it for the life of the
/// session. Not a singleton: it is created by the composition root and injected, so tests and
/// previews can have their own.
///
/// `ObservableObject` rather than `@Observable` because this package targets iOS 15.
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

    /// Fetches once per session. A call made while one is already in flight is a no-op.
    public func load(region: String, tenant: String, locale: String) {
        guard loadTask == nil else { return }
        isLoading = true
        loadTask = Task { [weak self] in
            guard let self else { return }
            defer {
                loadTask = nil
                isLoading = false
            }
            do {
                translations = try await repository.translations(region: region, tenant: tenant, locale: locale)
                lastError = nil
            } catch is CancellationError {
            } catch {
                // A missing table is degraded, not fatal: every lookup falls back to its key,
                // so the app stays usable and QA can see which strings are missing.
                lastError = error
            }
        }
    }

    /// Adopts a table someone else fetched — the seam for hosts that already pull app-data
    /// themselves and shouldn't fetch it twice.
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
