import XCTest
@testable import JackpotForms

final class FieldValidationTests: XCTestCase {
    private func field(_ identifier: String,
                       type: FieldType = .input,
                       inputType: InputType = .text,
                       required: Bool = true,
                       regex: String?) -> FormField {
        FormField(id: 1, identifier: identifier, type: type, inputType: inputType,
                  isRequired: required, regex: regex)
    }

    // MARK: Real patterns from the registration schema

    func testMobileNumberPattern() {
        let mobile = field("username", inputType: .number, regex: "^(27|0)?[1-9][0-9]{8}$")
        XCTAssertTrue(mobile.accepts(.text("849134302")))
        XCTAssertTrue(mobile.accepts(.text("0849134302")))
        XCTAssertTrue(mobile.accepts(.text("27849134302")))
        XCTAssertFalse(mobile.accepts(.text("049134302")))   // leading 0 after prefix
        XCTAssertFalse(mobile.accepts(.text("12345")))
    }

    func testPasswordLengthPattern() {
        let password = field("password", inputType: .password, regex: "^(.){8,20}$")
        XCTAssertFalse(password.accepts(.text("short")))
        XCTAssertTrue(password.accepts(.text("longenough")))
        XCTAssertFalse(password.accepts(.text(String(repeating: "a", count: 21))))
    }

    func testSouthAfricanIdPattern() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        XCTAssertTrue(id.accepts(.text("9001015800089")))
        XCTAssertFalse(id.accepts(.text("900101580008")))
    }

    // MARK: Required / optional

    func testRequiredEmptyFails() {
        XCTAssertFalse(field("a", regex: "^.+$").accepts(.text("")))
        XCTAssertFalse(field("a", regex: "^.+$").accepts(.text("   ")))
    }

    func testOptionalEmptyPassesEvenWhenTheRegexWouldNot() {
        // referralCode's own regex allows empty, but many optional fields' won't —
        // the empty short-circuit is what makes "optional" mean optional.
        let optional = field("referralCode", required: false, regex: "^[a-zA-Z0-9]{3,25}$")
        XCTAssertTrue(optional.accepts(.text("")))
        XCTAssertFalse(optional.accepts(.text("ab")))
        XCTAssertTrue(optional.accepts(.text("WELCOME50")))
    }

    // MARK: Checkboxes validate as strings

    func testRequiredCheckboxMustBeTicked() {
        let terms = field("terms", type: .checkbox, regex: "^true$")
        XCTAssertFalse(terms.accepts(.bool(false)))
        XCTAssertTrue(terms.accepts(.bool(true)))
    }

    // MARK: Server-supplied patterns are untrusted input

    func testMalformedServerPatternDoesNotBlockTheUser() {
        let broken = field("oops", regex: "^[a-z")     // will not compile
        XCTAssertTrue(broken.accepts(.text("anything")))
    }

    func testMissingPatternIsNoConstraint() {
        XCTAssertTrue(field("a", regex: nil).accepts(.text("anything")))
        XCTAssertTrue(field("a", regex: "").accepts(.text("anything")))
    }

    func testReadOnlyAndInvisibleFieldsAreNeverInvalid() {
        let hidden = FormField(id: 1, identifier: "a", isRequired: true, isVisible: false, regex: "^impossible$")
        XCTAssertTrue(hidden.accepts(.text("")))

        let readOnly = FormField(id: 2, identifier: "b", isRequired: true, isReadOnly: true, regex: "^impossible$")
        XCTAssertTrue(readOnly.accepts(.text("")))
    }

    // MARK: Named regexes (the ID-type → ID-number dependency)

    func testNamedRegexResolvesFromTheCatalogue() {
        XCTAssertEqual(FormDependencies.jpcPatterns["idNumberRegex"], "^[0-9]{13}$")
        XCTAssertEqual(FormDependencies.jpcPatterns["passportNumberRegex"], "^.{5,20}$")
    }

    /// Passport is a length rule, not a character class. Too short fails; any 5–20
    /// characters pass — including punctuation the old alphanumeric guess would have rejected.
    func testPassportPatternIsACharacterCount() {
        let passport = field("passport", regex: FormDependencies.jpcPatterns["passportNumberRegex"])
        XCTAssertTrue(passport.accepts(.text("A1234567")))
        XCTAssertTrue(passport.accepts(.text("123456789")))
        XCTAssertTrue(passport.accepts(.text("!!!!!!!!")))
        XCTAssertFalse(passport.accepts(.text("abc")))
        XCTAssertFalse(passport.accepts(.text(String(repeating: "x", count: 21))))
    }

    func testOverrideRegexReplacesTheFieldRule() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        // Passport selected → 13-digit rule no longer applies.
        XCTAssertTrue(id.accepts(.text("A1234567"), overrideRegex: "^[a-zA-Z0-9]{6,12}$"))
        XCTAssertFalse(id.accepts(.text("A1234567")))
    }

    func testDateSerialisesToTheIso8601ShapeTheSchemaExpects() {
        let pattern = "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$"
        let dob = field("dateOfBirth", inputType: .calendar, regex: pattern)
        XCTAssertTrue(dob.accepts(.date(Date(timeIntervalSince1970: 631152000))))
    }
}
