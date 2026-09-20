import SwiftUI

/// The skyline and its light: everything behind the logo and the buttons.
struct LaunchBackdrop: View {
    let intro: LaunchIntro
    let ambientTime: TimeInterval
    let metrics: LaunchMetrics

    var body: some View {
        let u = metrics.unit
        let width = metrics.size.width
        let band = CGSize(width: width, height: 486 * u)
        let bandCentre = CGPoint(x: width / 2, y: metrics.bandTop + 243 * u)
        let drift = LaunchAmbient.wave(ambientTime, halfPeriod: 30)
        let shimmerSlide = LaunchAmbient.wave(ambientTime, halfPeriod: 9)
        let shimmerGlow = LaunchAmbient.wave(ambientTime, halfPeriod: 4.5)

        ZStack {
            EllipticalGradient(stops: [
                .init(color: LaunchPalette.violet.opacity(0.5), location: 0),
                .init(color: LaunchPalette.deepViolet.opacity(0.18), location: 0.52),
                .init(color: LaunchPalette.deepViolet.opacity(0), location: 0.76),
            ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            .frame(width: 1.44 * width, height: 460 * u)
            .opacity(intro.horizonOpacity)
            .position(x: width / 2, y: metrics.bandTop + 368 * u)

            skyline(size: band, drift: CGSize(width: (2 * drift - 1) * 0.011 * band.width,
                                              height: -drift * 0.004 * band.height))
                .contrast(intro.cityContrast)
                .cssBrightness(intro.cityBrightness)
                .saturation(intro.citySaturation)
                .mask(fade([(.clear, 0), (.black, 0.13), (.black, 0.64), (.black.opacity(0.35), 0.88), (.clear, 0.99)]))
                .opacity(intro.cityOpacity)
                .position(bandCentre)

            // Two copies of the picture, blurred and pushed until only the lights survive, screened back
            // over it. CSS `brightness(1.7) contrast(2.3)` is the one line 3.91c − 0.65, which SwiftUI's
            // added brightness and contrast about mid-grey rebuild exactly; likewise 1.9 and 2.6 below.
            skyline(size: band)
                .blur(radius: 14 * u)
                .brightness(0.206).contrast(3.91).saturation(1.3)
                .mask(fade([(.clear, 0), (.black, 0.13), (.black, 0.64), (.clear, 0.98)]))
                .scaleEffect(intro.flareScale)
                .opacity(intro.bloomOpacity)
                .blendMode(.screen)
                .position(bandCentre)

            skyline(size: CGSize(width: 1.16 * width, height: 506 * u))
                .blur(radius: 56 * u)
                .brightness(0.237).contrast(4.94).saturation(1.45)
                .mask(fade([(.clear, 0.02), (.black, 0.18), (.black, 0.62), (.clear, 0.96)]))
                .scaleEffect(intro.flareScale)
                .opacity(intro.haloOpacity)
                .blendMode(.screen)
                .position(bandCentre)

            LinearGradient(stops: [
                .init(color: LaunchPalette.magenta.opacity(0), location: 0),
                .init(color: LaunchPalette.magenta.opacity(0.4), location: 0.22),
                .init(color: Color(red: 1, green: 225 / 255, blue: 1).opacity(0.7), location: 0.5),
                .init(color: LaunchPalette.blue.opacity(0.4), location: 0.78),
                .init(color: LaunchPalette.blue.opacity(0), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: 1.28 * width, height: 3 * u)
            .blur(radius: 4 * u)
            .scaleEffect(x: intro.streakScale)
            .opacity(intro.streakOpacity)
            .blendMode(.screen)
            .position(x: width / 2, y: metrics.bandTop + 321.5 * u)

            // Hairlines of light standing on the water.
            Canvas { context, size in
                var x = 3 * u
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: 0, width: u, height: size.height)),
                                 with: .color(LaunchPalette.magenta.opacity(0.55)))
                    x += 9 * u
                }
            }
            .frame(width: 1.12 * width, height: 150 * u)
            .mask(fade([(.black, 0), (.clear, 1)]))
            .offset(x: (2 * shimmerSlide - 1) * 0.03 * 1.12 * width)
            .opacity(0.08 + 0.12 * shimmerGlow)
            .blendMode(.screen)
            .position(x: width / 2, y: metrics.bandTop + 453 * u)

            fade([(LaunchPalette.background.opacity(0), 0), (LaunchPalette.background.opacity(0.72), 0.46),
                  (LaunchPalette.background, 0.88)])
                .frame(width: width, height: 300 * u)
                .position(x: width / 2, y: metrics.size.height - 150 * u)

            fade([(LaunchPalette.background.opacity(0.92), 0), (LaunchPalette.background.opacity(0.55), 0.6),
                  (LaunchPalette.background.opacity(0), 1)])
                .frame(width: width, height: 200 * u)
                .position(x: width / 2, y: 100 * u)
        }
    }

    /// The city picture filling `size`, zoomed by the intro and cropped. Only the picture itself drifts.
    private func skyline(size: CGSize, drift: CGSize = .zero) -> some View {
        Image(.launchCity)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .offset(drift)
            .scaleEffect(intro.cityZoom)
            .clipped()
    }

    private func fade(_ stops: [(Color, CGFloat)]) -> LinearGradient {
        LinearGradient(stops: stops.map { .init(color: $0.0, location: $0.1) }, startPoint: .top, endPoint: .bottom)
    }
}

enum LaunchPalette {
    static let background = Color(.launchBackground)
    static let magenta = Color(red: 224 / 255, green: 36 / 255, blue: 195 / 255)
    static let violet = Color(red: 138 / 255, green: 43 / 255, blue: 226 / 255)
    static let deepViolet = Color(red: 80 / 255, green: 20 / 255, blue: 150 / 255)
    static let blue = Color(red: 29 / 255, green: 99 / 255, blue: 1)
}

extension View {
    /// CSS `brightness()` multiplies where SwiftUI's `brightness` adds. Below 1 that is a colour multiply;
    /// above 1, an added bias and a contrast about mid-grey multiply out to the same line, m·c.
    func cssBrightness(_ amount: Double) -> some View {
        let over = max(amount, 1)
        return brightness(0.5 - 0.5 / over)
            .contrast(over)
            .colorMultiply(Color(white: min(amount, 1)))
    }
}
