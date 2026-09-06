import Foundation
import JackpotLocalization
import JackpotFormsDomain

/// Adapts the app's session-wide `Translations` table to the form engine's `FormLocalizing`
/// seam.
///
/// An adapter rather than `extension Translations: FormLocalizing`, for two reasons:
///
/// 1. Neither type is ours — `Translations` lives in `JackpotLocalization`, `FormLocalizing` in
///    `JackpotFormsDomain` — so a conformance would be *retroactive*, which Swift 6 warns about and
///    which breaks if either module later declares its own.
/// 2. It makes the region policy explicit and visible in one place rather than buried in a
///    conformance somebody has to go looking for.
///
/// `JackpotFormsUI` still only ever sees the protocol, so the renderer stays previewable with a
/// fixed table.
public struct TranslationsLocalizer: FormLocalizing {

    private let translations: Translations

    public init(_ translations: Translations) {
        self.translations = translations
    }

    /// The schema hands the renderer keys, not text: `fieldLabel: "username"`,
    /// `fieldDropdowns[].text: "jpc-reg-idnumber"`, and — already region-suffixed —
    /// `fieldLabel: "receivePromotionalInformation-jza"`.
    ///
    /// `regional: true` covers both shapes: a plain key picks up its `-jza` override when one
    /// exists, and a pre-suffixed key resolves directly.
    public func string(forKey key: String) -> String? {
        translations.string(forKey: key, regional: true)
    }

    /// The table doubles as an error-code catalogue.
    public func message(forErrorCode code: Int) -> String? {
        translations.message(forErrorCode: code)
    }
}

public extension FormLocalizing where Self == TranslationsLocalizer {
    /// `.translations(session.translations)` at a call site expecting a localizer.
    static func translations(_ table: Translations) -> TranslationsLocalizer {
        TranslationsLocalizer(table)
    }
}
