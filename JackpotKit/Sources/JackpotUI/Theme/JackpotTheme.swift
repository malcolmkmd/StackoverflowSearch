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
    public var background = Palette.background
    public var surface = Palette.surface

    /// Same pair as `surface` today; its own role so a theme can separate them.
    public var fieldBackground = Palette.surface
    public var fieldBorder = Palette.fieldBorder
    /// The brand blue in both appearances; #E1E1E5 was invisible on the light field fill.
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

/// Each hex once, as shared constants so two `JackpotColors` compare equal; roles that share a pair point at one entry.
enum Palette {
    static let background = Color.adaptive(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x131316))
    static let surface = Color.adaptive(light: Color(hex: 0xF0F0F2), dark: Color(hex: 0x202126))
    static let fieldBorder = Color.adaptive(light: Color(hex: 0xE1E2E6), dark: Color(hex: 0x3E3E48))

    /// Android's dark text value. Light text uses readable greys instead.
    static let emphasis = Color(hex: 0xE1E1E5)
    static let textPrimary = Color.adaptive(light: Color(hex: 0x2F2F37), dark: emphasis)
    static let textSecondary = Color.adaptive(light: Color(hex: 0x565A63), dark: emphasis)
    static let textOnAccent = Color.white

    static let accent = Color.adaptive(light: Color(hex: 0x0060EC), dark: Color(hex: 0x4D8FFF))
    static let accentFill = Color(hex: 0x0060EC)
    /// Read from the app's screens; replace with the Android pair.
    static let accentFillDisabled = Color.adaptive(light: Color(hex: 0xD4E4F8), dark: Color(hex: 0x262B3B))

    static let error = Color.adaptive(light: Color(hex: 0xDF0000), dark: Color(hex: 0xFF6B6B))
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

    /// Resolves through the trait collection, so a `preferredColorScheme` override applies.
    static func adaptive(light: Color, dark: Color) -> Color {
        let light = UIColor(light)
        let dark = UIColor(dark)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Spacing

/// `CGFloat`-backed so SwiftUI overloads take `.sm` like a native inset.
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
    public var panelCornerRadius: CGFloat = JackpotSpacing.lm.rawValue

    public static let standard = JackpotSizes()

    public var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Typography

public struct JackpotTypography: Equatable, Sendable {
    public var title = Font.title2.weight(.bold)
    public var fieldText = Font.body
    public var label = Font.footnote
    public var error = Font.caption
    public var rowLabel = Font.subheadline
    public var sectionTitle = Font.subheadline.weight(.semibold)
    public var button = Font.headline

    public static let standard = JackpotTypography()
}
