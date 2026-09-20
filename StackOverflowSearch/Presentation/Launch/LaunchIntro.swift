import SwiftUI

/// Everything the intro animates, as one snapshot per moment. The defaults are the first frame;
/// `timeline` is the design's keyframes, track for track, so `value(time:)` is any frame of it.
struct LaunchIntro {
    var logoOpacity = 0.0
    var logoBrightness = 0.35
    /// 0 is the logo large in the middle of the screen, 1 is its resting place under the welcome line.
    var logoRise = 0.0

    var orbOpacity = 0.0
    var orbScale = 0.55

    var horizonOpacity = 0.06

    var cityOpacity = 0.0
    var cityContrast = 1.9
    var cityBrightness = 0.42
    var citySaturation = 0.65
    var cityZoom = 1.0

    var bloomOpacity = 0.0
    var haloOpacity = 0.0
    var flareScale = 1.0
    var streakOpacity = 0.0
    var streakScale = 0.5

    var welcome = 0.0
    var question = 0.0

    /// The design's `cubic-bezier(.16, 1, .3, 1)`. CSS eases between each pair of keyframes, not across
    /// the whole animation, so every keyframe below carries it.
    static let ease = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.16, y: 1),
                                       endControlPoint: UnitPoint(x: 0.3, y: 1))

    @MainActor static let timeline = KeyframeTimeline(initialValue: LaunchIntro()) {
        // jpc-power 1.2s: the sign flickers on.
        KeyframeTrack(\.logoOpacity) {
            LinearKeyframe(0.9, duration: 0.132, timingCurve: ease)
            LinearKeyframe(0.1, duration: 0.072, timingCurve: ease)
            LinearKeyframe(0.85, duration: 0.12, timingCurve: ease)
            LinearKeyframe(0.22, duration: 0.084, timingCurve: ease)
            LinearKeyframe(1, duration: 0.168, timingCurve: ease)
        }
        KeyframeTrack(\.logoBrightness) {
            LinearKeyframe(2, duration: 0.132, timingCurve: ease)
            LinearKeyframe(0.5, duration: 0.072, timingCurve: ease)
            LinearKeyframe(1.7, duration: 0.12, timingCurve: ease)
            LinearKeyframe(0.6, duration: 0.084, timingCurve: ease)
            LinearKeyframe(1.35, duration: 0.168, timingCurve: ease)
            LinearKeyframe(1.08, duration: 0.264, timingCurve: ease)
            LinearKeyframe(1, duration: 0.36, timingCurve: ease)
        }
        // jpc-rise 2.2s: holds until the sign is lit, then climbs.
        KeyframeTrack(\.logoRise) {
            LinearKeyframe(0, duration: 1.199)
            LinearKeyframe(1, duration: 1.001, timingCurve: ease)
        }

        // jpc-orb 3.2s
        KeyframeTrack(\.orbOpacity) {
            LinearKeyframe(0.95, duration: 0.512, timingCurve: ease)
            LinearKeyframe(0.8, duration: 0.832, timingCurve: ease)
            LinearKeyframe(0.5, duration: 1.024, timingCurve: ease)
            LinearKeyframe(0.26, duration: 0.832, timingCurve: ease)
        }
        KeyframeTrack(\.orbScale) {
            LinearKeyframe(1, duration: 0.512, timingCurve: ease)
            LinearKeyframe(1.02, duration: 0.832, timingCurve: ease)
            LinearKeyframe(1.05, duration: 1.024, timingCurve: ease)
            LinearKeyframe(1.08, duration: 0.832, timingCurve: ease)
        }

        // jpc-horizon 3.4s
        KeyframeTrack(\.horizonOpacity) {
            LinearKeyframe(0.06, duration: 2.38)
            LinearKeyframe(0.4, duration: 0.544, timingCurve: ease)
            LinearKeyframe(0.28, duration: 0.476, timingCurve: ease)
        }

        // jpc-city 3s: out of the dark, hard and grey, through an overshoot, to the picture as it is.
        KeyframeTrack(\.cityOpacity) {
            LinearKeyframe(0, duration: 1.2)
            LinearKeyframe(0.25, duration: 0.999, timingCurve: ease)
            LinearKeyframe(1, duration: 0.441, timingCurve: ease)
        }
        KeyframeTrack(\.cityContrast) {
            LinearKeyframe(1.9, duration: 1.2)
            LinearKeyframe(1.85, duration: 0.999, timingCurve: ease)
            LinearKeyframe(1.12, duration: 0.441, timingCurve: ease)
            LinearKeyframe(1, duration: 0.36, timingCurve: ease)
        }
        KeyframeTrack(\.cityBrightness) {
            LinearKeyframe(0.42, duration: 1.2)
            LinearKeyframe(0.5, duration: 0.999, timingCurve: ease)
            LinearKeyframe(1.3, duration: 0.441, timingCurve: ease)
            LinearKeyframe(1, duration: 0.36, timingCurve: ease)
        }
        KeyframeTrack(\.citySaturation) {
            LinearKeyframe(0.65, duration: 1.2)
            LinearKeyframe(0.72, duration: 0.999, timingCurve: ease)
            LinearKeyframe(1.45, duration: 0.441, timingCurve: ease)
            LinearKeyframe(1, duration: 0.36, timingCurve: ease)
        }
        // jpc-zoom 3s
        KeyframeTrack(\.cityZoom) {
            LinearKeyframe(1, duration: 1.2)
            LinearKeyframe(1.18, duration: 1.8, timingCurve: ease)
        }

        // jpc-bloom, jpc-halo, jpc-flarescale, jpc-streak 4.4s: the lights flare as the city arrives.
        KeyframeTrack(\.bloomOpacity) {
            LinearKeyframe(0, duration: 2.2)
            LinearKeyframe(0.34, duration: 0.528, timingCurve: ease)
            LinearKeyframe(0.16, duration: 0.704, timingCurve: ease)
            LinearKeyframe(0.09, duration: 0.968, timingCurve: ease)
        }
        KeyframeTrack(\.haloOpacity) {
            LinearKeyframe(0, duration: 2.2)
            LinearKeyframe(0.22, duration: 0.704, timingCurve: ease)
            LinearKeyframe(0.11, duration: 0.704, timingCurve: ease)
            LinearKeyframe(0.07, duration: 0.792, timingCurve: ease)
        }
        KeyframeTrack(\.flareScale) {
            LinearKeyframe(1, duration: 2.2)
            LinearKeyframe(1.015, duration: 0.528, timingCurve: ease)
            LinearKeyframe(1.002, duration: 1.672, timingCurve: ease)
        }
        KeyframeTrack(\.streakOpacity) {
            LinearKeyframe(0, duration: 2.288)
            LinearKeyframe(0.3, duration: 0.528, timingCurve: ease)
            LinearKeyframe(0, duration: 1.584, timingCurve: ease)
        }
        KeyframeTrack(\.streakScale) {
            LinearKeyframe(0.5, duration: 2.288)
            LinearKeyframe(1, duration: 0.528, timingCurve: ease)
            LinearKeyframe(1.08, duration: 1.584, timingCurve: ease)
        }

        // jpc-down 0.85s after 2.3s, jpc-up 0.7s after 3s
        KeyframeTrack(\.welcome) {
            LinearKeyframe(0, duration: 2.3)
            LinearKeyframe(1, duration: 0.85, timingCurve: ease)
        }
        KeyframeTrack(\.question) {
            LinearKeyframe(0, duration: 3)
            LinearKeyframe(1, duration: 0.7, timingCurve: ease)
        }
    }
}

/// jpc-spring 0.72s: how a button arrives. Login plays it 3.14s in, Sign Up 3.28s.
struct LaunchEntrance {
    var opacity = 0.0
    var offset = 28.0
    var scale = 0.975

    @MainActor static let timeline = KeyframeTimeline(initialValue: LaunchEntrance()) {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3744, timingCurve: LaunchIntro.ease)
        }
        KeyframeTrack(\.offset) {
            LinearKeyframe(-6, duration: 0.3744, timingCurve: LaunchIntro.ease)
            LinearKeyframe(2, duration: 0.1728, timingCurve: LaunchIntro.ease)
            LinearKeyframe(0, duration: 0.1728, timingCurve: LaunchIntro.ease)
        }
        KeyframeTrack(\.scale) {
            LinearKeyframe(1.014, duration: 0.3744, timingCurve: LaunchIntro.ease)
            LinearKeyframe(0.997, duration: 0.1728, timingCurve: LaunchIntro.ease)
            LinearKeyframe(1, duration: 0.1728, timingCurve: LaunchIntro.ease)
        }
    }
}

/// The design's endless loops as functions of the clock, so a frame depends on nothing but the time.
enum LaunchAmbient {
    /// 0 → 1 → 0 on CSS `ease-in-out`, `halfPeriod` seconds each way. Still at 0 before `time` reaches 0.
    static func wave(_ time: TimeInterval, halfPeriod: TimeInterval) -> Double {
        let phase = (max(time, 0) / halfPeriod).truncatingRemainder(dividingBy: 2)
        return UnitCurve.easeInOut.value(at: phase <= 1 ? phase : 2 - phase)
    }
}
