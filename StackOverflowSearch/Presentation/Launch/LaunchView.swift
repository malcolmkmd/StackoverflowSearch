import SwiftUI
import JackpotUI

/// The app's first screen: the Jackpot City intro, then Login or Sign Up.
struct LaunchView: View {
    let onLogin: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var showsRegistration = false

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = start.map { context.date.timeIntervalSince($0) } ?? 0
            // Reduce Motion gets the finished screen, held still, faded in.
            LaunchScene(time: reduceMotion ? LaunchIntro.timeline.duration : elapsed,
                        ambientTime: reduceMotion ? 0 : elapsed,
                        onLogin: onLogin,
                        onSignUp: { showsRegistration = true })
        }
        .opacity(reduceMotion && start == nil ? 0 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.4) : nil, value: start)
        .onAppear { start = .now }
        // Inset past the logo, so the lockup stays in view above the panel, dimmed, as the search header does.
        .jackpotPopup(isPresented: $showsRegistration, topInset: 160) {
            RegistrationSandbox(onClose: { showsRegistration = false })
        }
        // The artwork is dark in either appearance; this keeps the status bar and the sign-up panel legible on it.
        .preferredColorScheme(.dark)
    }
}

/// One frame of the launch screen, decided entirely by the two clocks.
struct LaunchScene: View {
    let time: TimeInterval
    var ambientTime: TimeInterval = 0
    var onLogin: () -> Void = {}
    var onSignUp: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            let metrics = LaunchMetrics(size: proxy.size)
            let intro = LaunchIntro.timeline.value(time: time)
            ZStack {
                LaunchPalette.background
                LaunchBackdrop(intro: intro, ambientTime: ambientTime, metrics: metrics)
                    .accessibilityHidden(true)
                lockup(intro, metrics)
                actions(intro, metrics)
            }
        }
        .ignoresSafeArea()
    }

    /// "WELCOME TO" over the logo, which lights up mid-screen and rises to meet it.
    private func lockup(_ intro: LaunchIntro, _ metrics: LaunchMetrics) -> some View {
        let u = metrics.unit
        let logo = CGSize(width: metrics.columnWidth - 68 * u, height: (metrics.columnWidth - 68 * u) * 1022.53 / 3721.18)
        let logoCentre = 104 * u + logo.height / 2
        let pulse = LaunchAmbient.wave(ambientTime - 2.6, halfPeriod: 1.7)
        let breath = LaunchAmbient.wave(ambientTime, halfPeriod: 2.3)
        let tracking = (0.36 - 0.11 * intro.welcome) * 21 * u

        return ZStack {
            ZStack {
                Image(.launchLogoChevrons)
                    .resizable()
                    .shadow(color: LaunchPalette.magenta.opacity(0.5 + 0.45 * pulse), radius: (2.5 + 5 * pulse) * u)
                    .shadow(color: LaunchPalette.violet.opacity(0.5 * pulse), radius: 16 * pulse * u)
                Image(.launchLogoWordmark)
                    .resizable()
            }
            .shadow(color: Color(red: 160 / 255, green: 110 / 255, blue: 1).opacity(0.35), radius: 8 * u)
            .cssBrightness(intro.logoBrightness)
            .opacity(intro.logoOpacity)
            .frame(width: logo.width, height: logo.height)
            .background {
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: LaunchPalette.magenta.opacity(0.6), location: 0),
                        .init(color: LaunchPalette.violet.opacity(0.28), location: 0.56),
                        .init(color: LaunchPalette.violet.opacity(0), location: 1),
                    ], center: .center, startRadius: 0, endRadius: 250 * u))
                    .frame(width: 520 * u, height: 520 * u)
                    .blur(radius: 22 * u)
                    .scaleEffect((0.94 + 0.13 * breath) * intro.orbScale)
                    .opacity((0.78 + 0.22 * breath) * intro.orbOpacity)
            }
            // Read as one heading here, where the frame is the logo's and not the screen's.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Welcome to Jackpot City")
            .accessibilityAddTraits(.isHeader)
            .scaleEffect(1.176 - 0.176 * intro.logoRise)
            .offset(y: (1 - intro.logoRise) * (metrics.size.height / 2 - logoCentre))
            .position(x: metrics.size.width / 2, y: logoCentre)

            Text("WELCOME TO")
                .font(LaunchFont.heavy.fixed(21 * u))
                .tracking(tracking)
                // Tracking also follows the last letter; lead with as much so the line sits centred.
                .padding(.leading, tracking)
                .foregroundStyle(.white)
                .shadow(color: Color(red: 190 / 255, green: 140 / 255, blue: 1).opacity(0.5), radius: 11 * u)
                .shadow(color: .black.opacity(0.7), radius: 5 * u, y: 2 * u)
                .fixedSize()
                .opacity(intro.welcome)
                .offset(y: -16 * u * (1 - intro.welcome))
                .position(x: metrics.size.width / 2, y: 75 * u)
                .accessibilityHidden(true)
        }
    }

    private func actions(_ intro: LaunchIntro, _ metrics: LaunchMetrics) -> some View {
        let u = metrics.unit
        return VStack(spacing: 16 * u) {
            Text("What do you want to do?")
                .font(LaunchFont.semibold.size(19 * u, relativeTo: .title3))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 9 * u, y: 2 * u)
                .shadow(color: LaunchPalette.violet.opacity(0.45), radius: 17 * u)
                .opacity(intro.question)
                .offset(y: 16 * u * (1 - intro.question))
                .padding(.bottom, 30 * u)

            Button("Login", action: onLogin)
                .buttonStyle(LaunchButtonStyle(kind: .primary, unit: u))
                .launchEntrance(at: time - 3.14, unit: u)
            Button("Sign Up", action: onSignUp)
                .buttonStyle(LaunchButtonStyle(kind: .glass, unit: u))
                .launchEntrance(at: time - 3.28, unit: u)
        }
        .padding(.horizontal, 22 * u)
        .frame(width: metrics.columnWidth)
        .padding(.bottom, 54 * u)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

/// The design is a 390 × 845 artboard. `unit` is points per design pixel on this screen, so the numbers in
/// the launch views are the design's own.
struct LaunchMetrics {
    let size: CGSize
    let unit: CGFloat

    init(size: CGSize) {
        self.size = size
        unit = min(size.width / 390, size.height / 845)
    }

    /// Logo and buttons keep the artboard's width, centred; the backdrop bleeds to the screen's edges.
    var columnWidth: CGFloat { 390 * unit }

    /// Top of the city band. Any height the artboard does not account for is split above and below it.
    var bandTop: CGFloat { 152 * unit + (size.height - 845 * unit) / 2 }
}

/// The design is set in Montserrat, which the app does not ship; Avenir Next is the nearest face iOS has.
enum LaunchFont {
    case semibold, bold, heavy

    private var name: String {
        switch self {
        case .semibold: "AvenirNext-DemiBold"
        case .bold: "AvenirNext-Bold"
        case .heavy: "AvenirNext-Heavy"
        }
    }

    func size(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }

    func fixed(_ size: CGFloat) -> Font {
        .custom(name, fixedSize: size)
    }
}

private extension View {
    func launchEntrance(at time: TimeInterval, unit: CGFloat) -> some View {
        let entrance = LaunchEntrance.timeline.value(time: max(time, 0))
        return scaleEffect(entrance.scale)
            .offset(y: entrance.offset * unit)
            .opacity(entrance.opacity)
    }
}

#Preview("Launch") {
    LaunchView(onLogin: {})
}

#Preview("Lights flaring, 2.65s") {
    LaunchScene(time: 2.65)
}
