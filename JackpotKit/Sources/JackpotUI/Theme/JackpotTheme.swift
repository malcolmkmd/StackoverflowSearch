import SwiftUI
import UIKit

public struct JackpotTheme: Equatable, Sendable {
    public var colors: JackpotColors = .jackpotCity
    public var metrics: JackpotMetrics = .standard
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
    public var surfaceElevated = Palette.surfaceElevated

    public var fieldBackground = Palette.fieldBackground
    public var fieldBorder = Palette.fieldBorder
    public var fieldBorderFocused = Palette.accent
    public var fieldBorderInvalid = Palette.error

    public var textPrimary = Palette.textPrimary
    public var textSecondary = Palette.textSecondary
    public var textOnAccent = Palette.textOnAccent

    public var accent = Palette.accent
    public var actionPrimary = Palette.actionPrimary
    public var currency = Palette.actionPrimary

    public var error = Palette.error
    public var warning = Palette.warning
    public var success = Palette.success

    public static let jackpotCity = JackpotColors()
}

/// Held as shared constants rather than inline literals so two separately built
/// `JackpotColors` still compare equal — a dynamic `Color` compares by identity.
enum Palette {
    static let surface = Color.adaptive(light: Color(red: 1.00, green: 1.00, blue: 1.00),
                                        dark: Color(red: 0.07, green: 0.08, blue: 0.09))

    static let surfaceElevated = Color.adaptive(light: Color(red: 0.96, green: 0.97, blue: 0.98),
                                                dark: Color(red: 0.11, green: 0.12, blue: 0.14))

    static let fieldBackground = Color.adaptive(light: Color(red: 1.00, green: 1.00, blue: 1.00),
                                                dark: Color(red: 0.13, green: 0.14, blue: 0.16))

    static let fieldBorder = Color.adaptive(light: Color(red: 0.80, green: 0.82, blue: 0.85),
                                            dark: Color.white.opacity(0.18))

    static let textPrimary = Color.adaptive(light: Color(red: 0.07, green: 0.09, blue: 0.12),
                                            dark: .white)

    static let textSecondary = Color.adaptive(light: Color(red: 0.42, green: 0.45, blue: 0.50),
                                              dark: Color.white.opacity(0.6))

    /// Sits on the accent and action fills, never on the surface, so it does not invert.
    static let textOnAccent = Color.white

    static let accent = Color.adaptive(light: Color(red: 0.13, green: 0.40, blue: 0.87),
                                       dark: Color(red: 0.16, green: 0.47, blue: 0.96))

    static let actionPrimary = Color.adaptive(light: Color(red: 0.85, green: 0.60, blue: 0.05),
                                              dark: Color(red: 0.96, green: 0.71, blue: 0.13))

    static let error = Color.adaptive(light: Color(red: 0.80, green: 0.16, blue: 0.10),
                                      dark: Color(red: 0.94, green: 0.28, blue: 0.16))

    static let warning = Color.adaptive(light: Color(red: 0.72, green: 0.45, blue: 0.02),
                                        dark: Color(red: 0.96, green: 0.62, blue: 0.13))

    static let success = Color.adaptive(light: Color(red: 0.10, green: 0.55, blue: 0.32),
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

// MARK: - Metrics

public struct JackpotMetrics: Equatable, Sendable {
    public var cornerRadius: CGFloat = 10
    public var controlHeight: CGFloat = 52
    public var spacing: CGFloat = 12
    public var contentPadding: CGFloat = 14
    public var borderWidth: CGFloat = 1
    public var emphasizedBorderWidth: CGFloat = 2
    public var minimumHitTarget: CGFloat = 44
    public var progressBarHeight: CGFloat = 4
    public var textAreaMinHeight: CGFloat = 110
    public var cardMinHeight: CGFloat = 140

    public static let standard = JackpotMetrics()

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
