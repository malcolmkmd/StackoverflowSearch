import XCTest
@testable import JackpotForms

final class FormDecodingTests: XCTestCase {

    private func loadRegistration() throws -> FormSchema {
        try StubFormRepository.decode(BundledForms.json(named: "registration"))
    }

    func testDecodesTheRealRegistrationSchema() throws {
        let form = try loadRegistration()
        XCTAssertEqual(form.id, 1052)
        XCTAssertEqual(form.codeName, .registration)
        XCTAssertEqual(form.regionCode, "JZA")
        XCTAssertEqual(form.sections.count, 2)
        XCTAssertEqual(form.allFields.count, 12)
    }

    func testSectionsAndRowsAreOrdered() throws {
        let form = try loadRegistration()
        XCTAssertEqual(form.sections.map(\.order), [1, 2])
        XCTAssertEqual(form.sections[0].rows.map(\.number), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(form.sections[0].fields.map(\.identifier),
                       ["username", "password", "firstname", "lastname", "email", "referralCode"])
    }

    /// The three types registration uses are the three this build renders.
    func testFieldTypesMapCorrectly() throws {
        let form = try loadRegistration()
        XCTAssertEqual(Set(form.allFields.map(\.type)), [.input, .dropdown, .checkbox])
        XCTAssertEqual(form.field(identifiedBy: "username")?.type, .input)
        XCTAssertEqual(form.field(identifiedBy: "username")?.inputType, .number)
        XCTAssertEqual(form.field(identifiedBy: "username")?.prefix, "+27")
        XCTAssertEqual(form.field(identifiedBy: "password")?.inputType, .password)
        XCTAssertEqual(form.field(identifiedBy: "email")?.inputType, .email)
        XCTAssertEqual(form.field(identifiedBy: "dateOfBirth")?.inputType, .calendar)
        XCTAssertEqual(form.field(identifiedBy: "idNumberType")?.type, .dropdown)
        XCTAssertEqual(form.field(identifiedBy: "terms")?.type, .checkbox)
    }

    /// The schema spells it "Calender". If the backend ever fixes the typo we must not silently
    /// downgrade the date picker to a text box.
    func testCalendarInputTypeAcceptsBothSpellings() {
        XCTAssertEqual(InputType(raw: "Calender"), .calendar)
        XCTAssertEqual(InputType(raw: "Calendar"), .calendar)
        XCTAssertEqual(InputType(raw: "date"), .calendar)
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
        let form = try StubFormRepository.decode(json)
        XCTAssertEqual(form.allFields.count, 2)
        XCTAssertEqual(form.field(identifiedBy: "a")?.type, .unknown("HolographicSlider"))
        XCTAssertEqual(form.field(identifiedBy: "b")?.type, .input)
    }

    func testMissingOptionalKeysFallBackSafely() throws {
        let json = Data("""
        {"formId":2,"formCodeName":"y","sections":[{"formSectionId":1,"rows":[
          {"rowNumber":1,"fields":[{"fieldId":9,"fieldIdentifier":"solo","fieldType":"Input"}]}]}]}
        """.utf8)
        let field = try XCTUnwrap(StubFormRepository.decode(json).field(identifiedBy: "solo"))
        XCTAssertEqual(field.labelKey, "solo")
        XCTAssertEqual(field.validationMessageKey, "regex")
        XCTAssertFalse(field.isRequired)     // unspecified must not block submission
        XCTAssertTrue(field.isVisible)
        XCTAssertNil(field.regex)
    }

    func testDropdownOptionsCarryValueTextAndRegex() throws {
        let form = try loadRegistration()
        let options = try XCTUnwrap(form.field(identifiedBy: "idNumberType")?.dropdownOptions)
        XCTAssertEqual(options.map(\.value), ["idNumber", "passport"])
        XCTAssertEqual(options[0].textKey, "jpc-reg-idnumber")
        XCTAssertEqual(options[0].regex, "idNumberRegex")
    }

    func testTheBundledSchemaIsRegistration() throws {
        XCTAssertEqual(Set(BundledForms.all.keys), [.registration])
        let form = try StubFormRepository.decode(try XCTUnwrap(BundledForms.all[.registration]))
        XCTAssertEqual(form.codeName, .registration)
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
}
