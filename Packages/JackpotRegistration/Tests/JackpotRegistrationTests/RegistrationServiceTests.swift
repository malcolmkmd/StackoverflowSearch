import XCTest
@testable import JackpotRegistration
import JackpotFormsDomain
import JackpotForms
import JackpotNetworking

final class RegistrationServiceTests: XCTestCase {

    private func submission(mobile: String) -> FormSubmission {
        FormSubmission(formCodeName: .registration, values: ["username": .text(mobile), "terms": .bool(true)])
    }

    func testMockSucceedsAndReportsOTP() async throws {
        let result = try await MockRegistrationService(delay: 0).register(submission(mobile: "849134302"))
        XCTAssertEqual(result, RegistrationResult(accountNumber: "27849134302", requiresOTP: true))
    }

    func testMockDuplicateMobileFailsWithAReadableMessage() async {
        do {
            _ = try await MockRegistrationService(delay: 0).register(submission(mobile: "0000000000"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .mobileAlreadyRegistered)
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    /// The form engine displays `LocalizedError.errorDescription`; every case must have one.
    func testEveryErrorHasUserFacingCopy() {
        let cases: [RegistrationError] = [.mobileAlreadyRegistered, .offline, .server(message: "x"), .unexpected]
        for c in cases { XCTAssertFalse((c.errorDescription ?? "").isEmpty, "\(c)") }
    }

    func testAPIErrorsMapToRegistrationErrors() {
        XCTAssertEqual(RegistrationError(.transport(.notConnectedToInternet)), .offline)
        XCTAssertEqual(RegistrationError(.badRequest(APIProblem(code: 1042, message: "dup"))), .mobileAlreadyRegistered)
        XCTAssertEqual(RegistrationError(.badRequest(APIProblem(code: 7, message: "Bad input"))), .server(message: "Bad input"))
        XCTAssertEqual(RegistrationError(.server(nil)), .unexpected)
    }

    /// The migration seam: the app's `getTranslation` returns the key on a miss, and that
    /// must become nil so the engine can fall back to humanised copy.
    func testClosureLocalizerMapsKeyOnMissToNil() {
        func legacyGetTranslation(Key: String) -> String { Key == "username" ? "Enter Mobile Number" : Key }
        let localizer = ClosureLocalizer { key in
            let value = legacyGetTranslation(Key: key)
            return value == key ? nil : value
        }
        XCTAssertEqual(localizer.string(forKey: "username"), "Enter Mobile Number")
        XCTAssertNil(localizer.string(forKey: "dateOfBirth"))
        XCTAssertEqual(localizer.display("dateOfBirth"), "Date Of Birth")
    }
}
