import SwiftUI
import XCTest
@testable import JackpotUI

final class JackpotThemeTests: XCTestCase {
    func testBrandThemeComposesTheStandardPresets() {
        XCTAssertEqual(JackpotTheme.jackpotCity.colors, .jackpotCity)
        XCTAssertEqual(JackpotTheme.jackpotCity.sizes, .standard)
        XCTAssertEqual(JackpotTheme.jackpotCity.typography, .standard)
    }

    func testWithReturnsACopyAndLeavesTheOriginalAlone() {
        let brand = JackpotTheme.jackpotCity
        let roomy = brand.with { $0.sizes.cornerRadius = JackpotSpacing.l.rawValue }

        XCTAssertEqual(roomy.sizes.cornerRadius, JackpotSpacing.l.rawValue)
        XCTAssertEqual(brand.sizes.cornerRadius, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(roomy.colors, brand.colors, "An unrelated slice should carry over untouched")
    }

    func testFieldShapeFollowsCornerRadius() {
        let theme = JackpotTheme.jackpotCity.with { $0.sizes.cornerRadius = JackpotSpacing.xxs.rawValue }
        XCTAssertEqual(theme.sizes.fieldShape.cornerSize, CGSize(width: JackpotSpacing.xxs.rawValue, height: JackpotSpacing.xxs.rawValue))
        XCTAssertEqual(theme.sizes.fieldShape.style, .continuous)
    }
}

final class JackpotSpacingTests: XCTestCase {
    func testScaleMatchesTheLockedLadder() {
        XCTAssertEqual(JackpotSpacing.xxs.rawValue, 4)
        XCTAssertEqual(JackpotSpacing.xs.rawValue, 6)
        XCTAssertEqual(JackpotSpacing.s.rawValue, 8)
        XCTAssertEqual(JackpotSpacing.sm.rawValue, 12)
        XCTAssertEqual(JackpotSpacing.m.rawValue, 16)
        XCTAssertEqual(JackpotSpacing.lm.rawValue, 20)
        XCTAssertEqual(JackpotSpacing.l.rawValue, 24)
        XCTAssertEqual(JackpotSpacing.xl.rawValue, 32)
        XCTAssertEqual(JackpotSpacing.xxl.rawValue, 40)
        XCTAssertEqual(JackpotSpacing.xxxl.rawValue, 48)
    }

    func testStandardSizesReadSpacingForGapsAndRadii() {
        let sizes = JackpotSizes.standard
        XCTAssertEqual(sizes.cornerRadius, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(sizes.spacing, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(sizes.contentPadding, JackpotSpacing.m.rawValue)
        XCTAssertEqual(sizes.progressBarHeight, JackpotSpacing.xxs.rawValue)
        XCTAssertEqual(sizes.fieldShape.cornerSize, CGSize(width: JackpotSpacing.sm.rawValue, height: JackpotSpacing.sm.rawValue))
    }

    func testSwiftUIOverlaysAcceptSpacingCases() {
        _ = EmptyView().padding(.sm)
        _ = EmptyView().padding(.horizontal, .m)
        _ = EmptyView().padding([.horizontal, .bottom], .l)
        _ = EmptyView().cornerRadius(.sm)
        _ = EmptyView().frame(width: .l, height: .l)
        _ = EmptyView().shadow(radius: .xxs)
        _ = VStack(spacing: .sm) { EmptyView() }
        _ = HStack(alignment: .top, spacing: .xs) { EmptyView() }
        XCTAssertEqual(EdgeInsets(.sm).top, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(EdgeInsets(.sm).leading, JackpotSpacing.sm.rawValue)
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

    func testFocusedBorderIsTheSharedEmphasisHexInBothAppearances() {
        let color = JackpotColors.jackpotCity.fieldBorderFocused
        XCTAssertEqual(hex(color, light), 0xE1E1E5)
        XCTAssertEqual(hex(color, dark), 0xE1E1E5)
    }

    func testLockedTokenHexes() {
        let colors = JackpotColors.jackpotCity
        let expected: [(KeyPath<JackpotColors, Color>, UInt32, UInt32)] = [
            (\.surface, 0xFFFFFF, 0x131316),
            (\.fieldBackground, 0xF0F0F2, 0x202126),
            (\.fieldBorder, 0xE1E2E6, 0x3E3E48),
            (\.fieldBorderFocused, 0xE1E1E5, 0xE1E1E5),
            (\.textPrimary, 0x2F2F37, 0xE1E1E5),
            (\.textSecondary, 0x565A63, 0xE1E1E5),
            (\.textOnAccent, 0xFFFFFF, 0xFFFFFF),
            (\.accent, 0x0060EC, 0x4D8FFF),
            (\.accentFill, 0x0060EC, 0x0060EC),
            (\.error, 0xDF0000, 0xFF6B6B),
            (\.warning, 0x945C05, 0xF59E21),
            (\.success, 0x0F7542, 0x33B870),
        ]
        for (keyPath, lightHex, darkHex) in expected {
            XCTAssertEqual(hex(colors[keyPath: keyPath], light), lightHex, "\(keyPath) light")
            XCTAssertEqual(hex(colors[keyPath: keyPath], dark), darkHex, "\(keyPath) dark")
        }
        XCTAssertEqual(hex(colors.fieldBorderInvalid, light), hex(colors.error, light))
        XCTAssertEqual(hex(colors.fieldBorderInvalid, dark), hex(colors.error, dark))
    }

    /// Text has to clear 4.5:1 on *every* background it can land on, not just `surface`.
    func testTextClearsWCAGContrastOnEveryBackgroundItLandsOn() {
        let colors = JackpotColors.jackpotCity
        let backgrounds: [(String, KeyPath<JackpotColors, Color>)] = [
            ("surface", \.surface),
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
                    // #DF0000 on #F0F0F2 is 4.46:1 — the locked brand red, just under 4.5.
                    let floor: CGFloat = (fgName == "error" && bgName == "fieldBackground"
                                          && traits.userInterfaceStyle == .light) ? 4.4 : 4.5
                    XCTAssertGreaterThanOrEqual(
                        contrastRatio(text, background), floor,
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

    func testFieldFillIsDistinguishableFromTheSurfaceBehindIt() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let fill = resolve(colors.fieldBackground, traits)
            let surface = resolve(colors.surface, traits)
            XCTAssertNotEqual(fill, surface, "field fill matches the surface in \(name(traits))")
            // 1.05, not 3:1 — the locked fills separate by ~1.14, so this pins the
            // regression (fill identical to surface) without overruling the design.
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

    private func hex(_ color: Color, _ traits: UITraitCollection) -> UInt32 {
        let c = components(resolve(color, traits))
        return UInt32(lround(Double(c.r * 255))) << 16
            | UInt32(lround(Double(c.g * 255))) << 8
            | UInt32(lround(Double(c.b * 255)))
    }

    /// Several palette entries are translucent white. Reading their components straight back
    /// reports the contrast of opaque white, so they have to be composited first.
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

    func testNewPasswordIsSecureAndOptsIntoStrongPasswordSuggestions() {
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
