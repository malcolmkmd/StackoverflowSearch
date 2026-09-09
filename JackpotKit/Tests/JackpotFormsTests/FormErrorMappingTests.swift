import XCTest
@testable import JackpotForms
import JackpotNetworking

/// The server's own wording has to survive the trip from JSON to the screen, and every hop is a
/// place it could be dropped.
final class FormErrorMappingTests: XCTestCase {
    private let repository = RemoteFormRepository(apiClient: ScriptedApiClient())

    func testServerMessageSurvivesToTheUserFacingString() {
        let apiError = APIError.badRequest(APIProblem(code: 1042, message: "Mobile number already registered"))
        let mapped = repository.userFacing(apiError, formName: .registration)
        XCTAssertEqual((mapped as? FormError), .server(message: "Mobile number already registered"))
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Mobile number already registered")
    }

    func testA400WithNoMessageFallsBackRatherThanShowingNothing() {
        let mapped = repository.userFacing(APIError.badRequest(nil), formName: .registration)
        XCTAssertEqual(mapped as? FormError, .unexpected)
        XCTAssertNotNil((mapped as? LocalizedError)?.errorDescription)
    }

    func testOfflineGetsItsOwnMessage() {
        let mapped = repository.userFacing(APIError.transport(.notConnectedToInternet), formName: .registration)
        XCTAssertEqual(mapped as? FormError, .offline)
    }

    func testUnknownFormBecomesNotFound() {
        let mapped = repository.userFacing(APIError.unexpectedStatus(404, nil), formName: FormName("deposit"))
        XCTAssertEqual(mapped as? FormError, .notFound(FormName("deposit")))
    }

    /// A cancelled load is a navigation event, not a failure — it must never reach the user.
    func testCancellationStaysCancellation() {
        XCTAssertTrue(repository.userFacing(APIError.cancelled, formName: .registration) is CancellationError)
    }

    func testNonAPIErrorsPassThroughUntouched() {
        struct Custom: LocalizedError { var errorDescription: String? { "custom" } }
        let mapped = repository.userFacing(Custom(), formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "custom")
    }

    func testServerErrorPrefersTheServersWordingOverOurs() {
        let mapped = repository.userFacing(APIError.server(APIProblem(code: 0, message: "Scheduled maintenance")),
                                           formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Scheduled maintenance")
    }
}

/// The app-data response carries error copy keyed by code — `"6000328": "Maximum OTP tries…"` for the
/// app at large, `jpc-reg-error.{code}` for registration — so an API error envelope's `code` is a
/// translation key, whichever function resolves it.
final class LocalizedErrorMappingTests: XCTestCase {
    private let table = [
        "6000328": "Maximum OTP tries reached, Please contact support on +233 30 825 5838",
        "jpc-reg-error.1042": "Hierdie selfoonnommer is reeds geregistreer",
    ]
    private var repository: RemoteFormRepository {
        RemoteFormRepository(apiClient: ScriptedApiClient(), translate: { [table] in table[$0] ?? $0 })
    }

    func testBareErrorCodeResolvesToLocalisedCopy() {
        let error = APIError.badRequest(APIProblem(code: 6000328, message: "Max OTP tries"))
        let mapped = repository.userFacing(error, formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription,
                       "Maximum OTP tries reached, Please contact support on +233 30 825 5838")
    }

    /// The table wins over the envelope's own text — it's the localised one.
    func testRegistrationErrorCodeBeatsTheServersMessage() {
        let error = APIError.badRequest(APIProblem(code: 1042, message: "Mobile number already registered"))
        let mapped = repository.userFacing(error, formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription,
                       "Hierdie selfoonnommer is reeds geregistreer")
    }

    func testUnknownCodeFallsBackToTheServersMessage() {
        let error = APIError.badRequest(APIProblem(code: 999999, message: "Something specific"))
        let mapped = repository.userFacing(error, formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Something specific")
    }
}
