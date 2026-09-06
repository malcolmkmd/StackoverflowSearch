import SwiftUI

/// Visual tokens. Defaults match the JackpotCity panel: near-black surfaces, blue actions,
/// gold for money, red for errors. Override per brand through the environment.
public struct JackpotTheme: Equatable {
    public var surface: Color
    public var surfaceElevated: Color
    public var fieldBackground: Color
    public var fieldBorder: Color
    public var fieldBorderFocused: Color
    public var fieldBorderInvalid: Color
    public var textPrimary: Color
    public var textSecondary: Color
    public var accent: Color
    public var actionPrimary: Color
    public var currency: Color
    public var error: Color
    public var success: Color
    public var cornerRadius: CGFloat
    public var controlHeight: CGFloat
    public var spacing: CGFloat

    public init(surface: Color = Color(red: 0.07, green: 0.08, blue: 0.09),
                surfaceElevated: Color = Color(red: 0.11, green: 0.12, blue: 0.14),
                fieldBackground: Color = Color(red: 0.13, green: 0.14, blue: 0.16),
                fieldBorder: Color = Color.white.opacity(0.18),
                fieldBorderFocused: Color = Color(red: 0.16, green: 0.47, blue: 0.96),
                fieldBorderInvalid: Color = Color(red: 0.94, green: 0.28, blue: 0.16),
                textPrimary: Color = .white,
                textSecondary: Color = Color.white.opacity(0.6),
                accent: Color = Color(red: 0.16, green: 0.47, blue: 0.96),
                actionPrimary: Color = Color(red: 0.96, green: 0.71, blue: 0.13),
                currency: Color = Color(red: 0.96, green: 0.71, blue: 0.13),
                error: Color = Color(red: 0.94, green: 0.28, blue: 0.16),
                success: Color = Color(red: 0.20, green: 0.72, blue: 0.44),
                cornerRadius: CGFloat = 10,
                controlHeight: CGFloat = 52,
                spacing: CGFloat = 12) {
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.fieldBackground = fieldBackground
        self.fieldBorder = fieldBorder
        self.fieldBorderFocused = fieldBorderFocused
        self.fieldBorderInvalid = fieldBorderInvalid
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.actionPrimary = actionPrimary
        self.currency = currency
        self.error = error
        self.success = success
        self.cornerRadius = cornerRadius
        self.controlHeight = controlHeight
        self.spacing = spacing
    }

    public static let jackpotCity = JackpotTheme()
}

private struct JackpotThemeKey: EnvironmentKey {
    static let defaultValue = JackpotTheme.jackpotCity
}

public extension EnvironmentValues {
    var jackpotTheme: JackpotTheme {
        get { self[JackpotThemeKey.self] }
        set { self[JackpotThemeKey.self] = newValue }
    }
}

public extension View {
    func jackpotTheme(_ theme: JackpotTheme) -> some View {
        environment(\.jackpotTheme, theme)
    }
}
