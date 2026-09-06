import SwiftUI
import XCTest
@testable import JackpotUI

final class JackpotThemeTests: XCTestCase {
    func testBrandThemeComposesTheStandardPresets() {
        XCTAssertEqual(JackpotTheme.jackpotCity.colors, .jackpotCity)
        XCTAssertEqual(JackpotTheme.jackpotCity.metrics, .standard)
        XCTAssertEqual(JackpotTheme.jackpotCity.typography, .standard)
    }

    func testWithReturnsACopyAndLeavesTheOriginalAlone() {
        let brand = JackpotTheme.jackpotCity
        let roomy = brand.with { $0.metrics.cornerRadius = 24 }

        XCTAssertEqual(roomy.metrics.cornerRadius, 24)
        XCTAssertEqual(brand.metrics.cornerRadius, 10)
        XCTAssertEqual(roomy.colors, brand.colors, "An unrelated slice should carry over untouched")
    }

    func testFieldShapeFollowsCornerRadius() {
        let theme = JackpotTheme.jackpotCity.with { $0.metrics.cornerRadius = 4 }
        XCTAssertEqual(theme.metrics.fieldShape.cornerSize, CGSize(width: 4, height: 4))
        XCTAssertEqual(theme.metrics.fieldShape.style, .continuous)
    }
}

final class JackpotColorSchemeTests: XCTestCase {
    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    func testSurfaceAndTextInvertBetweenAppearances() {
        let colors = JackpotColors.jackpotCity
        for keyPath in [\JackpotColors.surface, \.fieldBackground, \.textPrimary, \.textSecondary] {
            let color = UIColor(colors[keyPath: keyPath])
            XCTAssertNotEqual(color.resolvedColor(with: light),
                              color.resolvedColor(with: dark),
                              "\(keyPath) should differ per appearance")
        }
    }

    func testTextOnAccentDoesNotInvert() {
        let color = UIColor(JackpotColors.jackpotCity.textOnAccent)
        XCTAssertEqual(color.resolvedColor(with: light), color.resolvedColor(with: dark))
    }

    /// Text has to clear 4.5:1 on *every* background it can land on. Measuring only
    /// against `surface` is what let a pure-white `fieldBackground` ship: the field, the
    /// secondary button and the checklist panel were all white on white in light mode.
    func testTextClearsWCAGContrastOnEveryBackgroundItLandsOn() {
        let colors = JackpotColors.jackpotCity
        let backgrounds: [(String, KeyPath<JackpotColors, Color>)] = [
            ("surface", \.surface),
            ("surfaceElevated", \.surfaceElevated),
            ("fieldBackground", \.fieldBackground),
        ]
        let foregrounds: [(String, KeyPath<JackpotColors, Color>)] = [
            ("textPrimary", \.textPrimary),
            ("textSecondary", \.textSecondary),
            ("accent", \.accent),
            ("error", \.error),
            ("warning", \.warning),
            ("success", \.success),
        ]

        for traits in [light, dark] {
            for (bgName, bg) in backgrounds {
                let background = resolve(colors[keyPath: bg], traits)
                for (fgName, fg) in foregrounds {
                    let text = flatten(resolve(colors[keyPath: fg], traits), over: background)
                    XCTAssertGreaterThanOrEqual(
                        contrastRatio(text, background), 4.5,
                        "\(fgName) on \(bgName) in \(name(traits)) is unreadable")
                }
            }
        }
    }

    func testButtonLabelClearsContrastOnItsFill() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let fill = resolve(colors.accentFill, traits)
            let label = flatten(resolve(colors.textOnAccent, traits), over: fill)
            XCTAssertGreaterThanOrEqual(contrastRatio(label, fill), 4.5,
                                        "textOnAccent on accentFill in \(name(traits))")
        }
    }

    /// The regression: light mode had both at pure white, so a field was identifiable only
    /// by a border that itself sat at 1.5:1.
    func testFieldFillIsDistinguishableFromTheSurfaceBehindIt() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let fill = resolve(colors.fieldBackground, traits)
            let surface = resolve(colors.surface, traits)
            XCTAssertNotEqual(fill, surface, "field fill matches the surface in \(name(traits))")
            // 1.05, not 3:1. The reference sheet's own fill separates by 1.06, so this pins
            // the regression — fill identical to surface — without overruling the design.
            XCTAssertGreaterThan(contrastRatio(fill, surface), 1.05,
                                 "field fill is too close to the surface in \(name(traits))")
        }
    }

    // MARK: Helpers

    private func name(_ traits: UITraitCollection) -> String {
        traits.userInterfaceStyle == .dark ? "dark" : "light"
    }

    private func resolve(_ color: Color, _ traits: UITraitCollection) -> UIColor {
        UIColor(color).resolvedColor(with: traits)
    }

    /// Several palette entries are translucent white. Reading their components straight
    /// back reports the contrast of opaque white, so they have to be composited first.
    private func flatten(_ color: UIColor, over background: UIColor) -> UIColor {
        let fg = components(color), bg = components(background)
        return UIColor(red: fg.r * fg.a + bg.r * (1 - fg.a),
                       green: fg.g * fg.a + bg.g * (1 - fg.a),
                       blue: fg.b * fg.a + bg.b * (1 - fg.a),
                       alpha: 1)
    }

    /// WCAG 2.1 relative luminance.
    private func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let lighter = max(luminance(a), luminance(b))
        let darker = min(luminance(a), luminance(b))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        let c = components(color)
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }
}

final class JackpotFieldKindTests: XCTestCase {
    func testEmailOptsOutOfCapitalisationAndAutocorrection() {
        XCTAssertEqual(JackpotFieldKind.email.keyboard, .emailAddress)
        XCTAssertEqual(JackpotFieldKind.email.contentType, .emailAddress)
        XCTAssertTrue(JackpotFieldKind.email.disablesAutocorrection)
        XCTAssertFalse(JackpotFieldKind.email.isSecure)
    }

    func testPasswordKindsAreSecure() {
        XCTAssertTrue(JackpotFieldKind.password.isSecure)
        XCTAssertTrue(JackpotFieldKind.newPassword.isSecure)
        XCTAssertEqual(JackpotFieldKind.newPassword.contentType, .newPassword)
    }

    func testWithOverridesASingleTrait() {
        let kind = JackpotFieldKind.text.with { $0.capitalization = .words }
        XCTAssertEqual(kind.capitalization, .words)
        XCTAssertEqual(kind.keyboard, JackpotFieldKind.text.keyboard)
    }
}

final class JackpotOptionTests: XCTestCase {
    func testOptionsAreIdentifiedByTheirStoredValue() {
        let option = JackpotOption(id: "SalaryOrWages", label: "Salary or Wages")
        XCTAssertEqual(option.id, "SalaryOrWages")
    }

    func testChecklistItemEquatable() {
        let a = JackpotChecklistItem(id: "min", text: "Minimum of 8", isSatisfied: false)
        XCTAssertEqual(a, JackpotChecklistItem(id: "min", text: "Minimum of 8", isSatisfied: false))
        XCTAssertNotEqual(a, JackpotChecklistItem(id: "min", text: "Minimum of 8", isSatisfied: true))
    }
}
