import XCTest
@testable import JackpotRegistration
import JackpotForms

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
