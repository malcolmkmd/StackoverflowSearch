import SwiftUI
import Testing
@testable import StackOverflowSearch

@MainActor
struct LaunchIntroTests {
    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0001 }

    @Test("The first frame shows nothing but the dark, with the logo waiting mid-screen")
    func firstFrame() {
        let intro = LaunchIntro.timeline.value(time: 0)
        #expect(intro.logoOpacity == 0)
        #expect(intro.logoRise == 0)
        #expect(intro.cityOpacity == 0)
        #expect(intro.bloomOpacity == 0)
        #expect(intro.welcome == 0)
        #expect(intro.question == 0)
        #expect(LaunchEntrance.timeline.value(time: 0).opacity == 0)
    }

    @Test("The intro runs the design's 4.4 seconds and rests on the design's final frame")
    func restingFrame() {
        #expect(close(LaunchIntro.timeline.duration, 4.4))
        let intro = LaunchIntro.timeline.value(time: LaunchIntro.timeline.duration)
        #expect(close(intro.logoOpacity, 1))
        #expect(close(intro.logoBrightness, 1))
        #expect(close(intro.logoRise, 1))
        #expect(close(intro.orbOpacity, 0.26))
        #expect(close(intro.orbScale, 1.08))
        #expect(close(intro.horizonOpacity, 0.28))
        #expect(close(intro.cityOpacity, 1))
        // `filter: none`: the picture as it is.
        #expect(close(intro.cityContrast, 1))
        #expect(close(intro.cityBrightness, 1))
        #expect(close(intro.citySaturation, 1))
        #expect(close(intro.cityZoom, 1.18))
        #expect(close(intro.bloomOpacity, 0.09))
        #expect(close(intro.haloOpacity, 0.07))
        #expect(close(intro.flareScale, 1.002))
        #expect(close(intro.streakOpacity, 0))
        #expect(close(intro.welcome, 1))
        #expect(close(intro.question, 1))
    }

    @Test("Long after the intro the screen is still the resting frame")
    func holdsAfterTheEnd() {
        let later = LaunchIntro.timeline.value(time: 600)
        #expect(close(later.cityZoom, 1.18))
        #expect(close(later.bloomOpacity, 0.09))
        #expect(close(later.logoRise, 1))
    }

    @Test("The logo holds mid-screen until the sign is lit, and the city stays dark meanwhile")
    func holds() {
        let lit = LaunchIntro.timeline.value(time: 1.19)
        #expect(close(lit.logoRise, 0))
        #expect(close(lit.logoOpacity, 1))
        #expect(close(lit.cityOpacity, 0))
        #expect(close(lit.cityZoom, 1))
    }

    @Test("A button springs past its place and settles on it")
    func entrance() {
        #expect(close(LaunchEntrance.timeline.duration, 0.72))
        let overshoot = LaunchEntrance.timeline.value(time: 0.3744)
        #expect(close(overshoot.offset, -6))
        #expect(close(overshoot.scale, 1.014))
        #expect(close(overshoot.opacity, 1))
        let settled = LaunchEntrance.timeline.value(time: 0.72)
        #expect(close(settled.offset, 0))
        #expect(close(settled.scale, 1))
    }

    @Test("An ambient loop waits at 0, peaks after half a period and returns")
    func ambientWave() {
        #expect(LaunchAmbient.wave(-2.6, halfPeriod: 1.7) == 0)
        #expect(close(LaunchAmbient.wave(0, halfPeriod: 1.7), 0))
        #expect(close(LaunchAmbient.wave(1.7, halfPeriod: 1.7), 1))
        #expect(close(LaunchAmbient.wave(3.4, halfPeriod: 1.7), 0))
        // Out and back mirror each other.
        #expect(close(LaunchAmbient.wave(0.5, halfPeriod: 1.7), LaunchAmbient.wave(2.9, halfPeriod: 1.7)))
    }

    @Test("The design's artboard maps one to one onto a 390 × 845 screen and scales to others by their tighter side")
    func metrics() {
        let artboard = LaunchMetrics(size: CGSize(width: 390, height: 845))
        #expect(artboard.unit == 1)
        #expect(artboard.bandTop == 152)
        let pro = LaunchMetrics(size: CGSize(width: 402, height: 874))
        #expect(close(pro.unit, 402.0 / 390))
        let pad = LaunchMetrics(size: CGSize(width: 820, height: 1180))
        #expect(close(pad.unit, 1180.0 / 845))
        #expect(pad.columnWidth < 820)
    }
}
