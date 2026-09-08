import XCTest
@testable import JackpotRegistration
import JackpotForms

/// The engine ships with no cross-field links and no date cap; registration adds both, whatever
/// repository the host passes in.
final class RegistrationRulesTests: XCTestCase {
    func testRegistrationLinksIDTypeToIDNumber() {
        let dependencies = RegistrationDependencies.mock()
        XCTAssertEqual(dependencies.forms.regexDependencies, ["idNumberType": "idNumber"])
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

    /// The contract the app's `LegacyTranslationLocalizer` relies on: `getTranslation` returns the key
    /// on a miss, and mapping that to nil is what lets the engine fall back to humanised copy.
    func testKeyOnMissMappedToNilFallsBackToHumanisedCopy() {
        let legacyGetTranslation: @Sendable (String) -> String = {
            $0 == "username" ? "Enter Mobile Number" : $0
        }
        let localizer = ClosureLocalizer { key in
            let value = legacyGetTranslation(key)
            return value == key ? nil : value
        }
        XCTAssertEqual(localizer.string(forKey: "username"), "Enter Mobile Number")
        XCTAssertNil(localizer.string(forKey: "dateOfBirth"))
        XCTAssertEqual(localizer.display("dateOfBirth"), "Date Of Birth")
    }
}
