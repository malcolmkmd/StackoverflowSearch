import XCTest
@testable import JackpotFormsData
import JackpotFormsDomain

final class FieldValidatorTests: XCTestCase {

    private let validator = FieldValidator()

    private func field(_ identifier: String,
                       type: FieldType = .input,
                       inputType: InputType = .text,
                       required: Bool = true,
                       regex: String?) -> FormField {
        FormField(id: 1, identifier: identifier, name: identifier, labelKey: identifier,
                  type: type, inputType: inputType, textStyle: "Regular",
                  validationMessageKey: "regex", isRequired: required, isVisible: true, isReadOnly: false,
                  regex: regex, prefix: "", suffix: "", placeholderKey: identifier,
                  dropdownOptions: [], radioOptions: [])
    }

    // MARK: Real patterns from the registration schema

    func testMobileNumberPattern() {
        let mobile = field("username", inputType: .number, regex: "^(27|0)?[1-9][0-9]{8}$")
        XCTAssertTrue(validator.validate(.text("849134302"), against: mobile).isValid)
        XCTAssertTrue(validator.validate(.text("0849134302"), against: mobile).isValid)
        XCTAssertTrue(validator.validate(.text("27849134302"), against: mobile).isValid)
        XCTAssertFalse(validator.validate(.text("049134302"), against: mobile).isValid)   // leading 0 after prefix
        XCTAssertFalse(validator.validate(.text("12345"), against: mobile).isValid)
    }

    func testPasswordLengthPattern() {
        let password = field("password", inputType: .password, regex: "^(.){8,20}$")
        XCTAssertFalse(validator.validate(.text("short"), against: password).isValid)
        XCTAssertTrue(validator.validate(.text("longenough"), against: password).isValid)
        XCTAssertFalse(validator.validate(.text(String(repeating: "a", count: 21)), against: password).isValid)
    }

    func testSouthAfricanIdPattern() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        XCTAssertTrue(validator.validate(.text("9001015800089"), against: id).isValid)
        XCTAssertFalse(validator.validate(.text("900101580008"), against: id).isValid)
    }

    // MARK: Required / optional

    func testRequiredEmptyFails() {
        XCTAssertFalse(validator.validate(.text(""), against: field("a", regex: "^.+$")).isValid)
        XCTAssertFalse(validator.validate(.text("   "), against: field("a", regex: "^.+$")).isValid)
    }

    func testOptionalEmptyPassesEvenWhenTheRegexWouldNot() {
        // referralCode's own regex allows empty, but many optional fields' won't —
        // the empty short-circuit is what makes "optional" mean optional.
        let optional = field("referralCode", required: false, regex: "^[a-zA-Z0-9]{3,25}$")
        XCTAssertTrue(validator.validate(.text(""), against: optional).isValid)
        XCTAssertFalse(validator.validate(.text("ab"), against: optional).isValid)
        XCTAssertTrue(validator.validate(.text("WELCOME50"), against: optional).isValid)
    }

    // MARK: Checkboxes validate as strings

    func testRequiredCheckboxMustBeTicked() {
        let terms = field("terms", type: .checkbox, regex: "^true$")
        XCTAssertFalse(validator.validate(.bool(false), against: terms).isValid)
        XCTAssertTrue(validator.validate(.bool(true), against: terms).isValid)
    }

    // MARK: Server-supplied patterns are untrusted input

    func testMalformedServerPatternDoesNotBlockTheUser() {
        let broken = field("oops", regex: "^[a-z")     // will not compile
        XCTAssertTrue(validator.validate(.text("anything"), against: broken).isValid)
    }

    func testMissingPatternIsNoConstraint() {
        XCTAssertTrue(validator.validate(.text("anything"), against: field("a", regex: nil)).isValid)
        XCTAssertTrue(validator.validate(.text("anything"), against: field("a", regex: "")).isValid)
    }

    func testReadOnlyAndInvisibleFieldsAreNeverInvalid() {
        var f = field("a", regex: "^impossible$")
        f = FormField(id: f.id, identifier: f.identifier, name: f.name, labelKey: f.labelKey,
                      type: f.type, inputType: f.inputType, textStyle: f.textStyle,
                      validationMessageKey: f.validationMessageKey, isRequired: true,
                      isVisible: false, isReadOnly: false, regex: f.regex,
                      prefix: "", suffix: "", placeholderKey: "", dropdownOptions: [], radioOptions: [])
        XCTAssertTrue(validator.validate(.text(""), against: f).isValid)
    }

    // MARK: Named regexes (the ID-type → ID-number dependency)

    func testNamedRegexResolvesFromTheCatalogue() {
        XCTAssertEqual(validator.optionPattern("idNumberRegex"), "^[0-9]{13}$")
        XCTAssertEqual(validator.optionPattern("passportNumberRegex"), "^.{5,20}$")
    }

    /// Passport is a length rule, not a character class. Too short fails; any 5–20
    /// characters pass — including punctuation the old alphanumeric guess would have rejected.
    func testPassportPatternIsACharacterCount() {
        let pattern = validator.optionPattern("passportNumberRegex")!
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

    func testLiteralPatternIsUsedAsIs() {
        XCTAssertEqual(validator.optionPattern("[a-zA-Z]"), "[a-zA-Z]")
    }

    func testOverrideRegexReplacesTheFieldRule() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        // Passport selected → 13-digit rule no longer applies.
        XCTAssertTrue(validator.validate(.text("A1234567"), against: id,
                                        overrideRegex: "^[a-zA-Z0-9]{6,12}$").isValid)
        XCTAssertFalse(validator.validate(.text("A1234567"), against: id).isValid)
    }

    // MARK: Password policy parsing

    func testPasswordRulesAreDerivedFromTheQuantifier() {
        let rules = PasswordPolicy().rules(for: field("password", inputType: .password, regex: "^(.){8,20}$"))
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0].description, "Minimum of 8 characters")
        XCTAssertEqual(rules[1].description, "Maximum of 20 characters")
        XCTAssertFalse(rules[0].isSatisfied(by: "short"))
        XCTAssertTrue(rules[0].isSatisfied(by: "longenough"))
        XCTAssertFalse(rules[1].isSatisfied(by: String(repeating: "a", count: 21)))
    }

    func testDateSerialisesToTheIso8601ShapeTheSchemaExpects() {
        let pattern = "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$"
        let dob = field("dateOfBirth", inputType: .calendar, regex: pattern)
        XCTAssertTrue(validator.validate(.date(Date(timeIntervalSince1970: 631152000)), against: dob).isValid)
    }
}
