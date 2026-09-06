import Foundation

/// Anything that names a row in the localisation table.
///
/// The app already declares its keys as string-backed enums:
///
/// ```swift
/// enum FixedJackpotTranslationsKeys: String {
///     case startsIn = "jpc-fixed-jackpots-starts-in"
///     case cityJackpots = "city-jackpots"
/// }
/// ```
///
/// Those were good — the raw strings were already centralised. What they lacked was a way to
/// *use* them without going through the global function. Add the conformance and nothing else
/// changes:
///
/// ```swift
/// extension FixedJackpotTranslationsKeys: LocalizationKey {}
///
/// label.text = translations(FixedJackpotTranslationsKeys.startsIn)
/// ```
///
/// The `RawRepresentable` default below means the conformance is genuinely empty.
public protocol LocalizationKey {
    var localizationKey: String { get }
}

public extension LocalizationKey where Self: RawRepresentable, RawValue == String {
    var localizationKey: String { rawValue }
}
