import XCTest
@testable import JackpotForms

/// The bundled payloads are what previews, the sandbox and every build without a backend run on,
/// and `FormFixtures` falls back to an empty schema rather than trapping when a resource is
/// missing. These tests are what make that fallback safe: a broken capture fails here, not on
/// screen. They also pin the fixture to the catalog, so the offline path and production cannot
/// disagree about what registration is.
final class BundledFormsTests: XCTestCase {
    private let schema = FormFixtures.registrationSchema

    func testTheCaptureDecodesThroughTheRealMapper() {
        XCTAssertEqual(schema.id, 1052)
        XCTAssertEqual(schema.codeName, .registration)
        XCTAssertEqual(schema.sections.count, 2)
        XCTAssertEqual(schema.allFields.map(\.identifier), [
            "username", "password", "firstname", "lastname", "email", "referralCode",
            "idNumberType", "idNumber", "dateOfBirth", "sourceOfFunds",
            "receivePromotionalInformation", "terms",
        ])
    }

    /// A key that comes back unchanged is a key the CMS slice is missing — on screen that reads as
    /// `idnumbertype` where a label should be.
    func testEveryVisibleKeyResolvesToCopy() {
        for field in schema.allFields {
            XCTAssertNotEqual(FormFixtures.translate(field.labelKey), field.labelKey,
                              "no copy for the \(field.identifier) label")
            if field.isRequired {
                let key = "jpc-reg-\(field.identifier)-\(field.validationMessageKey)"
                XCTAssertNotEqual(FormFixtures.translate(key), key, "no copy for \(key)")
            }
            for option in field.dropdownOptions {
                XCTAssertNotEqual(FormFixtures.translate(option.textKey), option.textKey,
                                  "no copy for the \(option.value) option")
            }
        }
    }

    func testBundledSubmitReadsTheAcceptedEnvelope() async throws {
        let result = try await submit(idNumber: "9001015800089")
        XCTAssertEqual(result.accountId, "32212b00-54d0-449e-877a-f712f0976823")
        XCTAssertEqual(result.message, "User Created Successfully.")
        XCTAssertEqual(result.accessToken, "_act-jwt-bundled-fixture")
    }

    /// The rejection arrives as HTTP 200, so this is the whole envelope path: `isSuccessful: false`,
    /// then `error.code` resolved through the bundled copy.
    func testTheFixtureIdNumberIsRejectedTheWayTheCRMRejectsOne() async {
        do {
            _ = try await submit(idNumber: FormFixtures.rejectedIdNumber)
            XCTFail("the bundled CRM must reject \(FormFixtures.rejectedIdNumber)")
        } catch {
            XCTAssertEqual(error as? FormError,
                           .server(message: "The ID or Passport Number Provided Is Invalid"))
        }
    }

    /// It can only demo a rejected submit if the form would let it be submitted at all.
    func testTheRejectedIdNumberClearsTheFieldsOwnRule() throws {
        let field = try XCTUnwrap(schema.field(identifiedBy: "idNumber"))
        XCTAssertTrue(field.accepts(.text(FormFixtures.rejectedIdNumber)))
    }

    private func submit(idNumber: String) async throws -> FormSubmitResult {
        try await FormDependencies.bundled(delay: 0).repository.submitForm(
            FormSubmission(formCodeName: .registration,
                           values: ["idNumber": .text(idNumber)],
                           formId: "1052")
        )
    }
}
