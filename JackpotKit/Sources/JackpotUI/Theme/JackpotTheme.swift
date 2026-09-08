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
    /// The base layer: what screens and components draw on, and what a control resting on a
    /// `surface` band is filled with — a panel's close button, the "Already have an account?" row.
    public var background = Palette.background
    /// The raised layer: a sheet's header and footer bands, a presented picker.
    public var surface = Palette.surface

    /// Field fill. Shares `surface`'s pair today; its own role so a theme can separate them.
    public var fieldBackground = Palette.surface
    public var fieldBorder = Palette.fieldBorder
    /// The brand blue in both appearances, so the ring is visible on the light field fill too.
    public var fieldBorderFocused = Palette.accentFill
    public var fieldBorderInvalid = Palette.error

    public var textPrimary = Palette.textPrimary
    public var textSecondary = Palette.textSecondary
    public var textOnAccent = Palette.textOnAccent

    public var accent = Palette.accent
    public var accentFill = Palette.accentFill
    /// A primary button that cannot be tapped yet, under `textPrimary`.
    public var accentFillDisabled = Palette.accentFillDisabled

    public var error = Palette.error
    public var warning = Palette.warning
    public var success = Palette.success

    public static let jackpotCity = JackpotColors()
}

/// Held as shared constants rather than inline literals so two separately built `JackpotColors`
/// still compare equal — a dynamic `Color` compares by identity.
///
/// Same hex is one entry. A role gets its own name when it can diverge from the others on its
/// pair: `surface` and `fieldBackground` are both `Palette.surface` today, but a theme may want a
/// field to stand out on the shell. Roles that never diverge (`link` / selected shell =
/// `accent`, track / divider = `fieldBorder`) are not given a second name.
enum Palette {
    /// #FFFFFF / #131316. The base layer: screens and components draw on it, and controls on a
    /// `surface` band fill with it. (Android names it `formBackground`, after its first
    /// consumer; the role is wider than that.)
    static let background = Color.adaptive(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x131316))

    /// #F0F0F2 / #202126. The raised layer: the sheet shell — the Sign Up header band with its
    /// close button, the footer band, a presented picker — and, on the same pair, the field
    /// fill and the checklist. (Android `surface`.)
    static let surface = Color.adaptive(light: Color(hex: 0xF0F0F2), dark: Color(hex: 0x202126))

    /// #E1E2E6 / #3E3E48. Hairline, progress track, divider, secondary button.
    static let fieldBorder = Color.adaptive(light: Color(hex: 0xE1E2E6), dark: Color(hex: 0x3E3E48))

    /// #E1E1E5. Android's dark-mode text / icon value; it once served as the focused border too,
    /// but at 1.1:1 on the light field fill that ring was invisible, so focus now uses
    /// `accentFill`. Light-mode paste also dumped body copy, `primary`, `onPrimary` and `link`
    /// here — unreadable on #F0F0F2, so light text uses its own values.
    static let emphasis = Color(hex: 0xE1E1E5)

    /// #2F2F37 / #E1E1E5. Android `titleText` (Text Priority); dark body shares `emphasis`.
    static let textPrimary = Color.adaptive(light: Color(hex: 0x2F2F37), dark: emphasis)

    /// #565A63 / #E1E1E5. Labels and placeholders. Light keeps the existing readable gray —
    /// Android's #E1E1E5 body/label/placeholder is 1.15:1 on the field fill.
    static let textSecondary = Color.adaptive(light: Color(hex: 0x565A63), dark: emphasis)

    /// Sits on `accentFill`, never on the surface, so it does not invert. Android `onPrimary`
    /// was #E1E1E5 on a #E1E1E5 fill — an unfinished placeholder.
    static let textOnAccent = Color.white

    /// Accent as *text* and tint: the raised label of a focused field, ticked boxes, checklist
    /// ticks and the system tint. This is the Android `link` role; the token is not named
    /// `link`. Light #E1E1E5 is unreadable, so the isolated brand blue stays. Dark stays the
    /// lighter blue so a ticked state does not collapse into `textSecondary` (both would
    /// otherwise be #E1E1E5).
    static let accent = Color.adaptive(light: Color(hex: 0x0060EC), dark: Color(hex: 0x4D8FFF))

    /// #0060EC. Carries `textOnAccent` at 5.4:1 in both appearances. Android `primary` was
    /// the same unfinished #E1E1E5 as `onPrimary`.
    static let accentFill = Color(hex: 0x0060EC)

    /// #D4E4F8 / #262B3B. How the app draws Next until the section validates: pale blue in
    /// light, a muted slate in dark. Not the accent at an opacity — over the dark page that
    /// lands on a saturated navy the app never shows. Both values are read from screenshots;
    /// replace them with the Android pair.
    static let accentFillDisabled = Color.adaptive(light: Color(hex: 0xD4E4F8), dark: Color(hex: 0x262B3B))

    /// Brand error #DF0000. Dark lightens to #FF6B6B so captions still clear 4.5:1 on
    /// #131316 / #202126 — #DF0000 itself reads at ~3.2:1 there.
    static let error = Color.adaptive(light: Color(hex: 0xDF0000), dark: Color(hex: 0xFF6B6B))

    /// Not in the Android dialog paste; the checklist still needs both states.
    static let warning = Color.adaptive(light: Color(hex: 0x945C05), dark: Color(hex: 0xF59E21))
    static let success = Color.adaptive(light: Color(hex: 0x0F7542), dark: Color(hex: 0x33B870))
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

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
    /// The shell a feature is presented in (`JackpotPanel`).
    public var panelCornerRadius: CGFloat = JackpotSpacing.lm.rawValue

    public static let standard = JackpotSizes()

    public var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Typography

public struct JackpotTypography: Equatable, Sendable {
    /// A panel's title: Sign Up.
    public var title = Font.title2.weight(.bold)
    public var fieldText = Font.body
    public var label = Font.footnote
    public var error = Font.caption
    public var rowLabel = Font.subheadline
    public var sectionTitle = Font.subheadline.weight(.semibold)
    public var button = Font.headline

    public static let standard = JackpotTypography()
}
