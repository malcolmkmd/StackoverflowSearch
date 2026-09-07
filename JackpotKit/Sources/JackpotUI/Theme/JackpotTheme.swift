import SwiftUI
import UIKit

public struct JackpotTheme: Equatable, Sendable {
    public var colors: JackpotColors = .jackpotCity
    public var sizes: JackpotSizes = .standard
    public var typography: JackpotTypography = .standard

    public static let jackpotCity = JackpotTheme()

    public func with(_ transform: (inout JackpotTheme) -> Void) -> JackpotTheme {
        var copy = self
        transform(&copy)
        return copy
    }
}

// MARK: - Colours

public struct JackpotColors: Equatable, Sendable {
    public var surface = Palette.surface

    public var fieldBackground = Palette.fieldBackground
    public var fieldBorder = Palette.fieldBorder
    public var fieldBorderFocused = Palette.accent
    public var fieldBorderInvalid = Palette.error

    public var textPrimary = Palette.textPrimary
    public var textSecondary = Palette.textSecondary
    public var textOnAccent = Palette.textOnAccent

    public var accent = Palette.accent
    public var accentFill = Palette.accentFill

    public var error = Palette.error
    public var warning = Palette.warning
    public var success = Palette.success

    public static let jackpotCity = JackpotColors()
}

/// Held as shared constants rather than inline literals so two separately built `JackpotColors`
/// still compare equal — a dynamic `Color` compares by identity.
enum Palette {
    static let surface = Color.adaptive(light: Color(red: 1.00, green: 1.00, blue: 1.00),
                                        dark: Color(red: 0.07, green: 0.08, blue: 0.09))

    /// #F7F8FA. A tint off the surface, not white on white — the fill is what identifies a
    /// field, a secondary button and a checklist panel.
    static let fieldBackground = Color.adaptive(light: Color(red: 0.969, green: 0.973, blue: 0.980),
                                                dark: Color(red: 0.13, green: 0.14, blue: 0.16))

    /// #E4E5EA. A hairline by design: the fill carries identification, and the focused and
    /// invalid borders carry state.
    static let fieldBorder = Color.adaptive(light: Color(red: 0.894, green: 0.898, blue: 0.918),
                                            dark: Color.white.opacity(0.32))

    /// #22252C.
    static let textPrimary = Color.adaptive(light: Color(red: 0.133, green: 0.145, blue: 0.173),
                                            dark: .white)

    /// #565A63. Measured against `fieldBackground`, the tighter of its two backgrounds.
    static let textSecondary = Color.adaptive(light: Color(red: 0.337, green: 0.353, blue: 0.388),
                                              dark: Color.white.opacity(0.6))

    /// Sits on the accent and action fills, never on the surface, so it does not invert.
    static let textOnAccent = Color.white

    /// Accent as *text* — the tertiary button label. It cannot share a value with `accentFill`:
    /// white on a fill needs the fill at or below 0.18 luminance, while a label on the dark
    /// surface needs 0.20 up.
    static let accent = Color.adaptive(light: Color(red: 0.000, green: 0.376, blue: 0.925),
                                       dark: Color(red: 0.302, green: 0.561, blue: 1.000))

    /// #0060EC. Carries `textOnAccent` at 5.4:1, which is why the same brand blue serves as a
    /// fill in both appearances.
    static let accentFill = Color(red: 0.000, green: 0.376, blue: 0.925)

    /// #BC1A1A.
    static let error = Color.adaptive(light: Color(red: 0.737, green: 0.102, blue: 0.102),
                                      dark: Color(red: 0.98, green: 0.45, blue: 0.35))

    static let warning = Color.adaptive(light: Color(red: 0.58, green: 0.36, blue: 0.02),
                                        dark: Color(red: 0.96, green: 0.62, blue: 0.13))

    static let success = Color.adaptive(light: Color(red: 0.06, green: 0.46, blue: 0.26),
                                        dark: Color(red: 0.20, green: 0.72, blue: 0.44))
}

extension Color {
    /// Resolves against the trait collection, so one palette serves both appearances and
    /// honours a `preferredColorScheme` override anywhere in the hierarchy.
    static func adaptive(light: Color, dark: Color) -> Color {
        let light = UIColor(light)
        let dark = UIColor(dark)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Spacing

/// Layout scale for gaps, insets, and corner radii. Component sizes that are not
/// spacing (control height, hit targets) live on `JackpotSizes`.
///
/// Cases are `CGFloat`-backed so SwiftUI overloads can take `.sm` like a native inset.
public enum JackpotSpacing: CGFloat, CaseIterable, Sendable {
    case xxs = 4
    case xs = 6
    case s = 8
    case sm = 12
    case m = 16
    case lm = 20
    case l = 24
    case xl = 32
    case xxl = 40
    case xxxl = 48
}

// MARK: - Sizes

public struct JackpotSizes: Equatable, Sendable {
    public var cornerRadius: CGFloat = JackpotSpacing.sm.rawValue
    public var controlHeight: CGFloat = 52
    public var spacing: CGFloat = JackpotSpacing.sm.rawValue
    public var contentPadding: CGFloat = JackpotSpacing.m.rawValue
    public var borderWidth: CGFloat = 1
    public var emphasizedBorderWidth: CGFloat = 2
    public var minimumHitTarget: CGFloat = 44
    public var progressBarHeight: CGFloat = JackpotSpacing.xxs.rawValue
    public var textAreaMinHeight: CGFloat = 110
    public var cardMinHeight: CGFloat = 140

    public static let standard = JackpotSizes()

    public var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Typography

public struct JackpotTypography: Equatable, Sendable {
    public var fieldText = Font.body
    public var label = Font.footnote
    public var error = Font.caption
    public var rowLabel = Font.subheadline
    public var sectionTitle = Font.subheadline.weight(.semibold)
    public var button = Font.headline

    public static let standard = JackpotTypography()
}
