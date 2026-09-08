import XCTest
@testable import JackpotForms

/// The bundled-JSON repository the sandbox, the previews and every mock run on.
final class StubFormRepositoryTests: XCTestCase {
    func testStubServesTheBundledForm() async throws {
        let repo = StubFormRepository(forms: BundledForms.all, delay: 0)
        let form = try await repo.form(named: .registration)
        XCTAssertEqual(form.id, 1052)
    }

    func testStubReportsAnUnknownFormAsNotFound() async {
        let repo = StubFormRepository(forms: BundledForms.all, delay: 0)
        do {
            _ = try await repo.form(named: FormName("deposit"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError, .notFound(FormName("deposit")))
        }
    }

    func testStubSubmitSucceeds() async throws {
        let repo = StubFormRepository(forms: [:], delay: 0)
        let submission = FormSubmission(formCodeName: .registration, values: [:], formId: "1052")
        let submitted = try await repo.submitForm(submission)
        XCTAssertNil(submitted.accountId)
    }
}
