import XCTest
@testable import JackpotForms

/// The bundled-JSON repository the sandbox, the previews and every mock run on.
final class StubFormRepositoryTests: XCTestCase {
    private let repo = StubFormRepository(delay: 0)

    func testStubServesTheBundledForm() async throws {
        let form = try await repo.form(named: .registration)
        XCTAssertEqual(form.id, 1052)
    }

    func testStubReportsAnUnknownFormAsNotFound() async {
        do {
            _ = try await repo.form(named: FormName("deposit"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormError, .notFound(FormName("deposit")))
        }
    }

    func testStubSubmitReturnsAFakeAccount() async throws {
        let submitted = try await repo.submitForm(submission(mobile: "849134302"))
        XCTAssertEqual(submitted.accountId, "27849134302")
        XCTAssertEqual(submitted.message, "User Created Successfully.")
    }

    func testStubRejectsTheDuplicateMobileWithAReadableMessage() async {
        do {
            _ = try await repo.submitForm(submission(mobile: "0000000000"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormError,
                           .server(message: "That mobile number is already registered. Try logging in instead."))
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    private func submission(mobile: String) -> FormSubmission {
        FormSubmission(formCodeName: .registration, values: ["username": .text(mobile), "terms": .bool(true)], formId: "1052")
    }
}
