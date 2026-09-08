import Foundation
import JackpotForms
import JackpotLocalization

/// Feeds the app's `Translations` table to the form engine. Lives here so neither module knows the other;
/// an adapter rather than a retroactive conformance.
public struct TranslationsLocalizer: FormLocalizing {
    private let translations: Translations

    public init(_ translations: Translations) {
        self.translations = translations
    }

    /// `regional: true` covers both key shapes the schema uses: plain keys pick up `-jza`, suffixed keys resolve directly.
    public func string(forKey key: String) -> String? {
        translations.string(forKey: key, regional: true)
    }

    public func message(forErrorCode code: Int) -> String? {
        translations.message(forErrorCode: code)
    }
}
