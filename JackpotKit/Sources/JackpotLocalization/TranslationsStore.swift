import Foundation
import Combine

@MainActor
/// Owns the session's table. Created at the composition root and injected, never a singleton.
/// `ObservableObject` rather than `@Observable` because the floor is iOS 15.
public final class TranslationsStore: ObservableObject {
    @Published public private(set) var translations = Translations()
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: (any Error)?

    private let repository: any TranslationsRepository
    private var loadTask: Task<Void, Never>?

    public init(repository: any TranslationsRepository) {
        self.repository = repository
    }

    public var isLoaded: Bool { !translations.isEmpty }

    /// Once per session; a call made while one is in flight is a no-op.
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
                // Degraded, not fatal: lookups fall back to their keys.
                lastError = error
            }
        }
    }

    /// For hosts that already fetched app-data and shouldn't fetch it twice.
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
