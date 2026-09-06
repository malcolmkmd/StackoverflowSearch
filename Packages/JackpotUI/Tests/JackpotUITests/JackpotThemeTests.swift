import XCTest
@testable import JackpotUI

final class JackpotThemeTests: XCTestCase {
    func testDefaultThemeIsTheBrand() {
        XCTAssertEqual(JackpotTheme(), .jackpotCity)
    }

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
