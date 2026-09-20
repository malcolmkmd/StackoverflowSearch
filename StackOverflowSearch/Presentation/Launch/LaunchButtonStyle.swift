import SwiftUI

/// The launch screen's two buttons: the lit royal-blue one and the glass one under it.
struct LaunchButtonStyle: ButtonStyle {
    enum Kind { case primary, glass }

    let kind: Kind
    /// Points per design pixel, from `LaunchMetrics`.
    let unit: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16 * unit, style: .continuous)
        configuration.label
            .font(LaunchFont.bold.size(18 * unit, relativeTo: .headline))
            .foregroundStyle(.white)
            .padding(.vertical, 8 * unit)
            .frame(maxWidth: .infinity, minHeight: 56 * unit)
            .background {
                switch kind {
                case .primary: primary(shape, isPressed: configuration.isPressed)
                case .glass: glass(shape, isPressed: configuration.isPressed)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private func primary(_ shape: RoundedRectangle, isPressed: Bool) -> some View {
        ZStack {
            // The design's glow is a shadow pulled in by its spread; SwiftUI shadows have none, so draw it.
            shape.fill(LaunchPalette.blue.opacity(isPressed ? 0.6 : 0.55))
                .padding((isPressed ? 6 : 8) * unit)
                .blur(radius: (isPressed ? 7 : 17) * unit)
                .offset(y: (isPressed ? 4 : 12) * unit)

            shape.fill(
                LinearGradient(colors: [Color(red: 59 / 255, green: 123 / 255, blue: 1),
                                        Color(red: 11 / 255, green: 63 / 255, blue: 216 / 255)],
                               startPoint: .top, endPoint: .bottom)
                    .shadow(.inner(color: .white.opacity(0.45), radius: 0, y: unit))
            )
            LinearGradient(colors: [.clear, .black.opacity(0.28)],
                           startPoint: UnitPoint(x: 0.5, y: 0.68), endPoint: .bottom)
                .clipShape(shape)

            LaunchGloss()
                .fill(LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.05)],
                                     startPoint: .top, endPoint: .bottom))
                .padding([.horizontal, .top], unit)
                .clipShape(shape)

            shape.inset(by: -unit)
                .strokeBorder(Color(red: 150 / 255, green: 185 / 255, blue: 1).opacity(0.55), lineWidth: unit)
        }
    }

    private func glass(_ shape: RoundedRectangle, isPressed: Bool) -> some View {
        ZStack {
            shape.fill(
                Color(red: 150 / 255, green: 140 / 255, blue: 190 / 255).opacity(isPressed ? 0.12 : 0.16)
                    .shadow(.inner(color: .white.opacity(0.18), radius: 0, y: unit))
            )
            shape.strokeBorder(.white.opacity(0.2), lineWidth: unit)
        }
    }
}

/// The highlight across the top 44% of the primary button: flat on top, its lower corners wide quarter-ellipses.
private struct LaunchGloss: Shape {
    func path(in rect: CGRect) -> Path {
        let height = rect.height * 0.44
        let radius = CGSize(width: rect.width * 0.248, height: height * 0.62)
        // Control-point distance for a cubic that follows a quarter-ellipse.
        let k = 0.5523
        let bottom = rect.minY + height
        var path = Path()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom - radius.height))
        path.addCurve(to: CGPoint(x: rect.maxX - radius.width, y: bottom),
                      control1: CGPoint(x: rect.maxX, y: bottom - radius.height * (1 - k)),
                      control2: CGPoint(x: rect.maxX - radius.width * (1 - k), y: bottom))
        path.addLine(to: CGPoint(x: rect.minX + radius.width, y: bottom))
        path.addCurve(to: CGPoint(x: rect.minX, y: bottom - radius.height),
                      control1: CGPoint(x: rect.minX + radius.width * (1 - k), y: bottom),
                      control2: CGPoint(x: rect.minX, y: bottom - radius.height * (1 - k)))
        path.closeSubpath()
        return path
    }
}
