import XCTest
@testable import JackpotForms

final class FormDecodingTests: XCTestCase {
    private func decode(_ data: Data) throws -> FormSchema {
        try JSONDecoder().decode(FormDTO.self, from: data).schema
    }

    func testCalendarInputTypeAcceptsBothSpellings() {
        XCTAssertEqual(InputType(raw: "Calender"), .calendar)
        XCTAssertEqual(InputType(raw: "Calendar"), .calendar)
        XCTAssertEqual(InputType(raw: "date"), .calendar)
    }

    func testRecaptchaV3AcceptsTheWMSSpelling() {
        XCTAssertEqual(FieldType(raw: "recapcha v3"), .recaptchaV3)
        XCTAssertEqual(FieldType(raw: "recaptcha v3"), .recaptchaV3)
        XCTAssertEqual(FieldType(raw: "recaptchav3"), .recaptchaV3)
    }

    func testAVisibleRecaptchaRowIsStrippedAndFlagsTheSchema() throws {
        let json = Data("""
        {"formId":1,"formCodeName":"registration","sections":[{"formSectionId":1,"rows":[
          {"rowNumber":1,"fields":[{"fieldId":1,"fieldIdentifier":"email","fieldType":"Input"}]},
          {"rowNumber":2,"fields":[{"fieldId":2,"fieldIdentifier":"recaptcha","fieldType":"recapcha v3","isVisible":true}]}
        ]}]}
        """.utf8)
        let form = try decode(json)
        XCTAssertTrue(form.hasRecaptcha)
        XCTAssertEqual(form.allFields.map(\.identifier), ["email"])
    }

    func testAnInvisibleRecaptchaRowIsDroppedWithoutRequestingAToken() throws {
        let json = Data("""
        {"formId":1,"formCodeName":"x","sections":[{"formSectionId":1,"rows":[
          {"rowNumber":1,"fields":[{"fieldId":1,"fieldIdentifier":"recaptcha","fieldType":"recapcha v3","isVisible":false}]}
        ]}]}
        """.utf8)
        let form = try decode(json)
        XCTAssertFalse(form.hasRecaptcha)
        XCTAssertTrue(form.allFields.isEmpty)
    }

    /// The most important behaviour in the decoder: a field type this build has never heard of
    /// must not fail the decode, because product edits the schema in a CMS without shipping.
    func testUnknownFieldTypeDoesNotFailTheDecode() throws {
        let json = Data("""
        {"formId":1,"formCodeName":"x","sections":[{"formSectionId":1,"rows":[
          {"rowNumber":1,"fields":[{"fieldId":1,"fieldIdentifier":"a","fieldType":"HolographicSlider"}]},
          {"rowNumber":2,"fields":[{"fieldId":2,"fieldIdentifier":"b","fieldType":"Input"}]}
        ]}]}
        """.utf8)
        let form = try decode(json)
        XCTAssertEqual(form.allFields.count, 2)
        XCTAssertEqual(form.field(identifiedBy: "a")?.type, .unknown("HolographicSlider"))
        XCTAssertEqual(form.field(identifiedBy: "b")?.type, .input)
    }

    func testMissingOptionalKeysFallBackSafely() throws {
        let json = Data("""
        {"formId":2,"formCodeName":"y","sections":[{"formSectionId":1,"rows":[
          {"rowNumber":1,"fields":[{"fieldId":9,"fieldIdentifier":"solo","fieldType":"Input"}]}]}]}
        """.utf8)
        let field = try XCTUnwrap(decode(json).field(identifiedBy: "solo"))
        XCTAssertEqual(field.labelKey, "solo")
        XCTAssertEqual(field.validationMessageKey, "regex")
        XCTAssertFalse(field.isRequired)     // unspecified must not block submission
        XCTAssertTrue(field.isVisible)
        XCTAssertNil(field.regex)
    }
}

final class FormNameTests: XCTestCase {
    func testKnownNamesMapToTheirCodeNames() {
        XCTAssertEqual(FormName.registration.rawValue, "registration")
    }

    /// Forms are authored server-side, so a name this build has never heard of must still be
    /// constructible — that's why `FormName` isn't an enum.
    func testServerAuthoredNamesAreConstructible() {
        let deposit = FormName("deposit")
        XCTAssertEqual(deposit.rawValue, "deposit")
        XCTAssertNotEqual(deposit, .registration)
    }

    func testUsableAsADictionaryKey() {
        let forms: [FormName: Int] = [.registration: 1, FormName("deposit"): 2]
        XCTAssertEqual(forms[.registration], 1)
        XCTAssertEqual(forms[FormName("deposit")], 2)
        XCTAssertNil(forms[FormName("withdrawal")])
    }

    func testRoundTripsThroughRawValue() {
        XCTAssertEqual(FormName(rawValue: "registration"), .registration)
    }

    func testRecaptchaActionMirrorsTheWebMap() {
        XCTAssertEqual(FormName.registration.recaptchaAction, "register")
        XCTAssertEqual(FormName("login").recaptchaAction, "login")
    }
}
