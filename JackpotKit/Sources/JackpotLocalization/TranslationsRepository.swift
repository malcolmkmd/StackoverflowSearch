import Foundation

public protocol TranslationsRepository: Sendable {
    func translations(region: String, tenant: String, locale: String) async throws -> Translations
}

/// Fixed table, for previews and tests. The live implementation reads the app-data bootstrap
/// payload and lives in `JackpotAppData`.
public struct StubTranslationsRepository: TranslationsRepository {
    private let table: Translations

    public init(_ table: Translations) {
        self.table = table
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        table
    }
}
