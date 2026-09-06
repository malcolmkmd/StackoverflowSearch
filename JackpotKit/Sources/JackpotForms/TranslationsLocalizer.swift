import Foundation
import JackpotLocalization
import JackpotFormsDomain

/// Adapts the app's session-wide `Translations` table to the form engine's `FormLocalizing`
/// seam.
///
/// An adapter rather than `extension Translations: FormLocalizing`: both types belong to other
/// modules, so the conformance would be retroactive — which Swift 6 warns about, and which
/// breaks if either module later declares its own.
public struct TranslationsLocalizer: FormLocalizing {

    private let translations: Translations

    public init(_ translations: Translations) {
        self.translations = translations
    }

    /// `regional: true` covers both key shapes the schema uses: a plain key like `"username"`
    /// picks up its `-jza` override when one exists, and an already-suffixed key like
    /// `"receivePromotionalInformation-jza"` resolves directly.
    public func string(forKey key: String) -> String? {
        translations.string(forKey: key, regional: true)
    }

    public func message(forErrorCode code: Int) -> String? {
        translations.message(forErrorCode: code)
    }
}
