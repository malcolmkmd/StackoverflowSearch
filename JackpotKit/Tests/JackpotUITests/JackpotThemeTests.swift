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

    func testBodyTextClearsWCAGContrastInBothAppearances() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let text = UIColor(colors.textPrimary).resolvedColor(with: traits)
            let background = UIColor(colors.surface).resolvedColor(with: traits)
            XCTAssertGreaterThan(contrastRatio(text, background), 4.5,
                                 "textPrimary on surface, \(traits.userInterfaceStyle.rawValue)")

            let secondary = UIColor(colors.textSecondary).resolvedColor(with: traits)
            XCTAssertGreaterThan(contrastRatio(secondary, background), 4.5,
                                 "textSecondary on surface, \(traits.userInterfaceStyle.rawValue)")
        }
    }

    /// WCAG 2.1 relative luminance.
    private func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let lighter = max(luminance(a), luminance(b))
        let darker = min(luminance(a), luminance(b))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
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
