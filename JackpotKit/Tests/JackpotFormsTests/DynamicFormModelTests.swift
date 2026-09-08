import Combine
import XCTest
@testable import JackpotForms

/// End-to-end validation behaviour against the real registration schema: what the user
/// actually experiences, rather than the regexes in isolation.
@MainActor
final class DynamicFormModelTests: XCTestCase {
    private func loaded(regexDependencies: [String: String] = ["idNumberType": "idNumber"]) async -> DynamicFormModel {
        let model = DynamicFormModel(
            formName: .registration,
            dependencies: FormDependencies(
                repository: StubFormRepository(forms: BundledForms.all, delay: 0),
                regexDependencies: regexDependencies
            )
        )
        await model.load()
        return model
    }

    private func field(_ model: DynamicFormModel, _ id: String) throws -> FormField {
        try XCTUnwrap(model.form?.field(identifiedBy: id))
    }

    // MARK: Loading

    func testLoadsSchemaAndSeedsEveryField() async throws {
        let model = await loaded()
        XCTAssertEqual(model.sections.count, 2)
        XCTAssertEqual(model.sectionIndex, 0)
        XCTAssertTrue(model.isFirstSection)
        XCTAssertFalse(model.isLastSection)
        // Checkboxes start false, not empty — so `terms` is correctly invalid up front.
        XCTAssertEqual(model.value(for: try field(model, "terms")), .bool(false))
    }

    /// Re-appearing on screen calls `load()` again; it must not reset a half-filled form.
    func testLoadIsANoOpOnceLoaded() async throws {
        let model = await loaded()
        model.setValue(.text("849134302"), for: try field(model, "username"))
        await model.load()
        XCTAssertEqual(model.value(for: try field(model, "username")), .text("849134302"))
    }

    func testAFailedLoadCanBeRetried() async throws {
        let repository = FailOnceRepository()
        let model = DynamicFormModel(formName: .registration,
                                     dependencies: FormDependencies(repository: repository))
        await model.load()
        XCTAssertEqual(model.viewState, .failed(FormLoadError.offline.errorDescription!))

        await model.load()
        XCTAssertNotNil(model.form, "the retry should reach the schema")
    }

    // MARK: Errors appear only after the user has engaged

    func testUntouchedFieldsShowNoErrorEvenWhenInvalid() async throws {
        let model = await loaded()
        let mobile = try field(model, "username")
        XCTAssertNil(model.error(for: mobile))          // empty + required, but untouched
        model.markTouched(mobile)
        XCTAssertNotNil(model.error(for: mobile))
    }

    func testAdvancingRevealsEveryErrorInTheSection() async throws {
        let model = await loaded()
        XCTAssertFalse(model.advance())                  // blocked
        XCTAssertEqual(model.sectionIndex, 0)
        for id in ["username", "password", "firstname", "lastname", "email"] {
            XCTAssertNotNil(model.error(for: try field(model, id)), "\(id) should show an error")
        }
        // The optional referral code must NOT be flagged.
        XCTAssertNil(model.error(for: try field(model, "referralCode")))
    }

    // MARK: Section gating

    func testCannotAdvanceUntilSectionOneIsValid() async throws {
        let model = await loaded()
        XCTAssertFalse(model.isCurrentSectionValid)

        try fillSectionOne(model)

        XCTAssertTrue(model.isCurrentSectionValid)
        XCTAssertTrue(model.advance())
        XCTAssertEqual(model.sectionIndex, 1)
        XCTAssertTrue(model.isLastSection)

        model.goBack()
        XCTAssertEqual(model.sectionIndex, 0)
    }

    /// The navigation bar can live away from the pages, so the pages learn which way to slide
    /// from the model rather than from the button that was tapped.
    func testPagingDirectionFollowsTheLastMove() async throws {
        let model = await loaded()
        try fillSectionOne(model)
        XCTAssertTrue(model.advance())
        XCTAssertEqual(model.pagingDirection, .forward)
        model.goBack()
        XCTAssertEqual(model.pagingDirection, .backward)
    }

    // MARK: The ID-type → ID-number dependency

    func testPassportSelectionRelaxesTheThirteenDigitIdRule() async throws {
        let model = await loaded()
        try fillSectionOne(model)
        _ = model.advance()

        let type = try field(model, "idNumberType")
        let number = try field(model, "idNumber")

        model.setValue(.option("idNumber"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNotNil(model.error(for: number), "SA ID must be 13 digits")

        model.setValue(.option("passport"), for: type)
        XCTAssertNil(model.error(for: number), "passport should accept an alphanumeric number")

        model.setValue(.option("idNumber"), for: type)
        XCTAssertNotNil(model.error(for: number), "switching back must re-apply the 13-digit rule")
    }

    // MARK: Submission

    func testSubmitIsBlockedWhileAnythingIsInvalid() async throws {
        let model = await loaded()
        var called = false
        await model.submit { _ in called = true }
        XCTAssertFalse(called)
    }

    func testSubmitDeliversEveryValueKeyedByFieldIdentifier() async throws {
        let model = await loaded()
        try fillSectionOne(model)
        _ = model.advance()
        try fillSectionTwo(model)

        XCTAssertTrue(model.isFormValid)

        var received: FormSubmission?
        await model.submit { received = $0 }

        let submission = try XCTUnwrap(received)
        XCTAssertEqual(submission.formCodeName, .registration)
        XCTAssertEqual(submission.formId, "1052")
        XCTAssertEqual(submission["username"].stringValue, "849134302")
        XCTAssertEqual(submission["firstname"].stringValue, "Malcolm")
        XCTAssertEqual(submission["idNumberType"].stringValue, "idNumber")
        XCTAssertEqual(submission["terms"].stringValue, "true")
        XCTAssertEqual(submission["receivePromotionalInformation"].stringValue, "false")
        // Untouched optional field still present, as an empty string.
        XCTAssertEqual(submission["referralCode"].stringValue, "")
    }

    func testSubmitSurfacesAThrownError() async throws {
        let model = await loaded()
        try fillSectionOne(model)
        _ = model.advance()
        try fillSectionTwo(model)

        struct Boom: LocalizedError { var errorDescription: String? { "Registration failed" } }
        await model.submit { _ in throw Boom() }
        XCTAssertEqual(model.submitError, "Registration failed")
    }

    // MARK: Progress

    func testProgressTracksSatisfiedRequiredFields() async throws {
        let model = await loaded()
        XCTAssertEqual(model.progress, 0, accuracy: 0.001)
        try fillSectionOne(model)
        XCTAssertGreaterThan(model.progress, 0.3)
        XCTAssertLessThan(model.progress, 1.0)
        _ = model.advance()
        try fillSectionTwo(model)
        XCTAssertEqual(model.progress, 1.0, accuracy: 0.001)
    }

    // MARK: Render scheduling

    /// The return key marks the field on submit and the blur that follows marks it again.
    /// A second render there is what made the error appear a beat after focus moved.
    func testReTouchingAFieldSchedulesNoFurtherRender() async throws {
        let model = await loaded()
        let mobile = try field(model, "username")
        var renders = 0
        let subscription = model.objectWillChange.sink { _ in renders += 1 }
        defer { subscription.cancel() }

        model.markTouched(mobile)
        XCTAssertEqual(renders, 1)
        model.markTouched(mobile)
        XCTAssertEqual(renders, 1)
    }

    func testTouchingByIdentifierRevealsTheErrorAndIgnoresUnknownFields() async throws {
        let model = await loaded()
        let mobile = try field(model, "username")
        model.setValue(.text("123"), for: mobile)
        XCTAssertNil(model.error(for: mobile), "untouched, so still silent")

        model.markTouched(identifiedBy: "username")
        XCTAssertNotNil(model.error(for: mobile))

        model.markTouched(identifiedBy: "notAField")   // must not trap
    }

    // MARK: Return-key focus order

    func testFocusOrderCoversOnlyTextEntryInSchemaOrder() async throws {
        let model = await loaded()
        XCTAssertEqual(model.focusableIdentifiers,
                       ["username", "password", "firstname", "lastname", "email", "referralCode"])
    }

    func testReturnWalksToTheNextFieldAndStopsAtTheEnd() async throws {
        let model = await loaded()
        XCTAssertEqual(model.fieldAfter("username"), "password")
        XCTAssertEqual(model.fieldAfter("email"), "referralCode")
        XCTAssertNil(model.fieldAfter("referralCode"), "The last field dismisses rather than wrapping")
    }

    func testFocusOrderIgnoresUnknownAndAbsentFields() async throws {
        let model = await loaded()
        XCTAssertNil(model.fieldAfter(nil))
        XCTAssertNil(model.fieldAfter("notAField"))
    }

    func testDateAndPickerFieldsAreNotKeyboardFocusable() async throws {
        let model = await loaded()
        for identifier in ["dateOfBirth", "idNumberType", "sourceOfFunds", "terms"] {
            XCTAssertFalse(try field(model, identifier).acceptsKeyboardFocus,
                           "\(identifier) opens a picker or toggles, so the return key should skip it")
        }
    }

    // MARK: Helpers

    private func fillSectionOne(_ model: DynamicFormModel) throws {
        model.setValue(.text("849134302"), for: try field(model, "username"))
        model.setValue(.text("Password1"), for: try field(model, "password"))
        model.setValue(.text("Malcolm"), for: try field(model, "firstname"))
        model.setValue(.text("Collin"), for: try field(model, "lastname"))
        model.setValue(.text("hi@example.com"), for: try field(model, "email"))
    }

    private func fillSectionTwo(_ model: DynamicFormModel) throws {
        model.setValue(.option("idNumber"), for: try field(model, "idNumberType"))
        model.setValue(.text("9001015800089"), for: try field(model, "idNumber"))
        model.setValue(.date(Date(timeIntervalSince1970: 631152000)), for: try field(model, "dateOfBirth"))
        model.setValue(.option("SalaryOrWages"), for: try field(model, "sourceOfFunds"))
        model.setValue(.bool(true), for: try field(model, "terms"))
    }
}

/// Offline on the first fetch, the bundled schema after that.
private final class FailOnceRepository: FormRepository, @unchecked Sendable {
    private var hasFailed = false

    func form(named name: FormName) async throws -> FormSchema {
        if !hasFailed {
            hasFailed = true
            throw FormLoadError.offline
        }
        return try await StubFormRepository(forms: BundledForms.all, delay: 0).form(named: name)
    }

    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult { FormSubmitResult() }
}

/// Confirmed behaviour: the ID Number Type dropdown selects whether the user is entering a South
/// African ID or a passport, and the ID Number field validates accordingly.
@MainActor
final class IDTypeRegexDependencyTests: XCTestCase {
    private func loadedSectionTwo(regexDependencies: [String: String] = ["idNumberType": "idNumber"]) async -> DynamicFormModel {
        let model = DynamicFormModel(
            formName: .registration,
            dependencies: FormDependencies(
                repository: StubFormRepository(forms: BundledForms.all, delay: 0),
                regexDependencies: regexDependencies
            )
        )
        await model.load()
        return model
    }

    private func field(_ model: DynamicFormModel, _ id: String) throws -> FormField {
        try XCTUnwrap(model.form?.field(identifiedBy: id))
    }

    func testSouthAfricanIDRequiresThirteenDigits() async throws {
        let model = await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("idNumber"), for: type)
        model.setValue(.text("9001015800089"), for: number)
        model.markTouched(number)
        XCTAssertNil(model.error(for: number))

        model.setValue(.text("A1234567"), for: number)
        XCTAssertNotNil(model.error(for: number), "a passport number is not a valid SA ID")
    }

    func testPassportAcceptsAnAlphanumericNumber() async throws {
        let model = await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("passport"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNil(model.error(for: number))
    }

    /// Switching type revalidates immediately — the user shouldn't have to re-type to see the
    /// rule change.
    func testSwitchingTypeRevalidatesWithoutRetyping() async throws {
        let model = await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("idNumber"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNotNil(model.error(for: number))

        model.setValue(.option("passport"), for: type)
        XCTAssertNil(model.error(for: number), "switching to passport must clear the error")

        model.setValue(.option("idNumber"), for: type)
        XCTAssertNotNil(model.error(for: number), "switching back must re-apply the 13-digit rule")
    }

    /// A literal pattern on a dropdown option describes the *selection*, not another field.
    /// `sourceOfFunds` options carry `"[a-zA-Z]"`; that must never leak onto its neighbour.
    func testLiteralOptionPatternsDoNotLeakOntoOtherFields() async throws {
        let model = await loadedSectionTwo()
        let source = try field(model, "sourceOfFunds")
        let promo = try field(model, "receivePromotionalInformation")

        model.setValue(.option("SalaryOrWages"), for: source)
        model.setValue(.bool(true), for: promo)
        model.markTouched(promo)
        XCTAssertNil(model.error(for: promo))
    }

    /// The engine's default is no links at all: without one, the field's own regex always
    /// applies, whatever the dropdown says.
    func testNoLinkMeansTheFieldsOwnRuleApplies() async throws {
        let model = await loadedSectionTwo(regexDependencies: [:])
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")
        model.setValue(.option("passport"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNotNil(model.error(for: number))
    }
}
