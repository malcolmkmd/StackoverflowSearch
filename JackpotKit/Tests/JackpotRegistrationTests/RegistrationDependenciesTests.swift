import XCTest
@testable import JackpotRegistration
import JackpotForms

/// The engine ships with no cross-field links and no date cap; registration adds both, whatever
/// repository the host passes in.
final class RegistrationRulesTests: XCTestCase {
    func testRegistrationLinksIDNumberToItsType() {
        let dependencies = RegistrationDependencies.mock()
        XCTAssertEqual(dependencies.forms.regexDependencies, ["idNumber": "idNumberType"])
    }

    func testDateOfBirthIsCappedAtEighteenYearsAgo() throws {
        let now = Date(timeIntervalSince1970: 1_757_203_200)     // 2025-09-07
        let rules = FormDependencies.mock().applyingRegistrationRules(now: now)
        let cap = try XCTUnwrap(rules.maximumDate)
        let years = Calendar(identifier: .gregorian).dateComponents([.year], from: cap, to: now).year
        XCTAssertEqual(years, 18)
    }

    func testTheGenericEngineHasNeither() {
        let plain = FormDependencies.mock()
        XCTAssertTrue(plain.regexDependencies.isEmpty)
        XCTAssertNil(plain.maximumDate)
    }
}
