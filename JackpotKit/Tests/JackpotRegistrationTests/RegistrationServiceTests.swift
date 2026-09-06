import XCTest
@testable import JackpotRegistration
import JackpotFormsDomain
import JackpotForms
import JackpotNetworking

final class RegistrationServiceTests: XCTestCase {

    private func submission(mobile: String) -> FormSubmission {
        FormSubmission(formCodeName: .registration, values: ["username": .text(mobile), "terms": .bool(true)])
    }

    func testMockSucceedsAndReturnsAnAccount() async throws {
        let result = try await MockRegistrationService(delay: 0).register(submission(mobile: "849134302"))
        XCTAssertEqual(result, RegistrationResult(
            accountId: "27849134302",
            accessToken: "mock-token",
            message: "User Created Successfully."
        ))
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

    func testFormLoadErrorsMapToRegistrationErrors() {
        XCTAssertEqual(RegistrationError(FormLoadError.offline), .offline)
        XCTAssertEqual(RegistrationError(FormLoadError.server(message: "x")), .server(message: "x"))
        XCTAssertEqual(RegistrationError(FormLoadError.notFound(.registration)), .unexpected)
    }

    func testRemoteServicePostsThroughTheRepository() async throws {
        let result = try await RemoteRegistrationService(repository: FakeFormRepository(success: true))
            .register(submission(mobile: "849134302"))
        XCTAssertEqual(result.accountId, "abc")
        XCTAssertEqual(result.accessToken, "tok")
        XCTAssertTrue(result.isPartial)
    }

    func testRemoteServiceTreatsARejectedSubmitAsFailure() async {
        do {
            _ = try await RemoteRegistrationService(repository: FakeFormRepository(success: false))
                .register(submission(mobile: "849134302"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .server(message: "An Error Occurred."))
        }
    }

    func testRemoteServiceSurfacesRepositoryOffline() async {
        do {
            _ = try await RemoteRegistrationService(repository: FakeFormRepository(error: FormLoadError.offline))
                .register(submission(mobile: "849134302"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .offline)
        }
    }

    /// The migration seam: the app's `getTranslation` returns the key on a miss, and that must
    /// become nil so the engine can fall back to humanised copy.
    func testClosureLocalizerMapsKeyOnMissToNil() {
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

private struct FakeFormRepository: FormRepository {
    var success: Bool = true
    var error: (any Error)?

    func form(named name: FormName) async throws -> FormSchema {
        throw CancellationError()
    }

    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        if let error { throw error }
        guard success else { throw FormLoadError.server(message: "An Error Occurred.") }
        return FormSubmitResult(
            accountId: "abc",
            partialRegistrationStatus: 1,
            compliance: FormComplianceResult(accessToken: "tok")
        )
    }
}
