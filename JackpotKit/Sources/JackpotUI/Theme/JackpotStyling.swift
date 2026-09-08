import SwiftUI

public extension View {
    func jackpotForegroundStyle(_ color: KeyPath<JackpotColors, Color>) -> some View {
        modifier(JackpotForegroundStyle(color: color))
    }

    func jackpotBackground(_ color: KeyPath<JackpotColors, Color>) -> some View {
        modifier(JackpotBackgroundStyle(color: color, shape: Rectangle()))
    }

    func jackpotBackground<S: Shape>(_ color: KeyPath<JackpotColors, Color>, in shape: S) -> some View {
        modifier(JackpotBackgroundStyle(color: color, shape: shape))
    }

    func jackpotFont(_ font: KeyPath<JackpotTypography, Font>) -> some View {
        modifier(JackpotFontStyle(font: font))
    }

    func jackpotTextStyle(_ font: KeyPath<JackpotTypography, Font>,
                          color: KeyPath<JackpotColors, Color> = \.textPrimary) -> some View {
        jackpotFont(font).jackpotForegroundStyle(color)
    }

    func padding(_ spacing: JackpotSpacing) -> some View {
        padding(spacing.rawValue)
    }

    func padding(_ edges: Edge.Set, _ spacing: JackpotSpacing) -> some View {
        padding(edges, spacing.rawValue)
    }

    func frame(width: JackpotSpacing,
               height: JackpotSpacing,
               alignment: Alignment = .center) -> some View {
        frame(width: width.rawValue, height: height.rawValue, alignment: alignment)
    }
}

public extension VStack {
    init(alignment: HorizontalAlignment = .center,
         spacing: JackpotSpacing,
         @ViewBuilder content: () -> Content) {
        self.init(alignment: alignment, spacing: spacing.rawValue, content: content)
    }
}

public extension HStack {
    init(alignment: VerticalAlignment = .center,
         spacing: JackpotSpacing,
         @ViewBuilder content: () -> Content) {
        self.init(alignment: alignment, spacing: spacing.rawValue, content: content)
    }
}

public extension EdgeInsets {
    init(_ spacing: JackpotSpacing) {
        self.init(top: spacing.rawValue,
                  leading: spacing.rawValue,
                  bottom: spacing.rawValue,
                  trailing: spacing.rawValue)
    }
}

private struct JackpotForegroundStyle: ViewModifier {
    let color: KeyPath<JackpotColors, Color>
    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundStyle(theme.colors[keyPath: color])
    }
}

private struct JackpotBackgroundStyle<S: Shape>: ViewModifier {
    let color: KeyPath<JackpotColors, Color>
    let shape: S
    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content.background(theme.colors[keyPath: color], in: shape)
    }
}

private struct JackpotFontStyle: ViewModifier {
    let font: KeyPath<JackpotTypography, Font>
    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content.font(theme.typography[keyPath: font])
    }
}
