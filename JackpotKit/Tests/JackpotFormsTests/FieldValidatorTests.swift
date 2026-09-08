import XCTest
@testable import JackpotForms

final class FieldValidatorTests: XCTestCase {
    private let validator = FieldValidator()

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
        XCTAssertTrue(validator.validate(.text("849134302"), against: mobile))
        XCTAssertTrue(validator.validate(.text("0849134302"), against: mobile))
        XCTAssertTrue(validator.validate(.text("27849134302"), against: mobile))
        XCTAssertFalse(validator.validate(.text("049134302"), against: mobile))   // leading 0 after prefix
        XCTAssertFalse(validator.validate(.text("12345"), against: mobile))
    }

    func testPasswordLengthPattern() {
        let password = field("password", inputType: .password, regex: "^(.){8,20}$")
        XCTAssertFalse(validator.validate(.text("short"), against: password))
        XCTAssertTrue(validator.validate(.text("longenough"), against: password))
        XCTAssertFalse(validator.validate(.text(String(repeating: "a", count: 21)), against: password))
    }

    func testSouthAfricanIdPattern() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        XCTAssertTrue(validator.validate(.text("9001015800089"), against: id))
        XCTAssertFalse(validator.validate(.text("900101580008"), against: id))
    }

    // MARK: Required / optional

    func testRequiredEmptyFails() {
        XCTAssertFalse(validator.validate(.text(""), against: field("a", regex: "^.+$")))
        XCTAssertFalse(validator.validate(.text("   "), against: field("a", regex: "^.+$")))
    }

    func testOptionalEmptyPassesEvenWhenTheRegexWouldNot() {
        // referralCode's own regex allows empty, but many optional fields' won't —
        // the empty short-circuit is what makes "optional" mean optional.
        let optional = field("referralCode", required: false, regex: "^[a-zA-Z0-9]{3,25}$")
        XCTAssertTrue(validator.validate(.text(""), against: optional))
        XCTAssertFalse(validator.validate(.text("ab"), against: optional))
        XCTAssertTrue(validator.validate(.text("WELCOME50"), against: optional))
    }

    // MARK: Checkboxes validate as strings

    func testRequiredCheckboxMustBeTicked() {
        let terms = field("terms", type: .checkbox, regex: "^true$")
        XCTAssertFalse(validator.validate(.bool(false), against: terms))
        XCTAssertTrue(validator.validate(.bool(true), against: terms))
    }

    // MARK: Server-supplied patterns are untrusted input

    func testMalformedServerPatternDoesNotBlockTheUser() {
        let broken = field("oops", regex: "^[a-z")     // will not compile
        XCTAssertTrue(validator.validate(.text("anything"), against: broken))
    }

    func testMissingPatternIsNoConstraint() {
        XCTAssertTrue(validator.validate(.text("anything"), against: field("a", regex: nil)))
        XCTAssertTrue(validator.validate(.text("anything"), against: field("a", regex: "")))
    }

    func testReadOnlyAndInvisibleFieldsAreNeverInvalid() {
        let hidden = FormField(id: 1, identifier: "a", isRequired: true, isVisible: false, regex: "^impossible$")
        XCTAssertTrue(validator.validate(.text(""), against: hidden))

        let readOnly = FormField(id: 2, identifier: "b", isRequired: true, isReadOnly: true, regex: "^impossible$")
        XCTAssertTrue(validator.validate(.text(""), against: readOnly))
    }

    // MARK: Named regexes (the ID-type → ID-number dependency)

    func testNamedRegexResolvesFromTheCatalogue() {
        XCTAssertEqual(FormDependencies.jpcPatterns["idNumberRegex"], "^[0-9]{13}$")
        XCTAssertEqual(FormDependencies.jpcPatterns["passportNumberRegex"], "^.{5,20}$")
    }

    /// Passport is a length rule, not a character class. Too short fails; any 5–20
    /// characters pass — including punctuation the old alphanumeric guess would have rejected.
    func testPassportPatternIsACharacterCount() {
        let pattern = FormDependencies.jpcPatterns["passportNumberRegex"]!
        let expression = try! NSRegularExpression(pattern: pattern)
        func matches(_ value: String) -> Bool {
            expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        }
        XCTAssertTrue(matches("A1234567"))
        XCTAssertTrue(matches("123456789"))
        XCTAssertTrue(matches("!!!!!!!!"))
        XCTAssertFalse(matches(""))
        XCTAssertFalse(matches("abc"))
        XCTAssertFalse(matches(String(repeating: "x", count: 21)))
    }

    func testOverrideRegexReplacesTheFieldRule() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        // Passport selected → 13-digit rule no longer applies.
        XCTAssertTrue(validator.validate(.text("A1234567"), against: id,
                                        overrideRegex: "^[a-zA-Z0-9]{6,12}$"))
        XCTAssertFalse(validator.validate(.text("A1234567"), against: id))
    }

    // MARK: Password policy parsing

    func testPasswordRulesAreDerivedFromTheQuantifier() {
        let password = field("password", inputType: .password, regex: "^(.){8,20}$")
        let short = PasswordPolicy.rules(for: password, password: "short")
        XCTAssertEqual(short.map(\.description), ["Minimum of 8 characters", "Maximum of 20 characters"])
        XCTAssertEqual(short.map(\.isSatisfied), [false, true])
        XCTAssertTrue(PasswordPolicy.rules(for: password, password: "longenough")[0].isSatisfied)
        XCTAssertFalse(PasswordPolicy.rules(for: password, password: String(repeating: "a", count: 21))[1].isSatisfied)
    }

    func testDateSerialisesToTheIso8601ShapeTheSchemaExpects() {
        let pattern = "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$"
        let dob = field("dateOfBirth", inputType: .calendar, regex: pattern)
        XCTAssertTrue(validator.validate(.date(Date(timeIntervalSince1970: 631152000)), against: dob))
    }
}
