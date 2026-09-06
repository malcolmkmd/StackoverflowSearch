import XCTest
@testable import JackpotNetworking

/// The API's envelope is `{ "code": 0, "message": "Error message" }`.
///
/// These matter more than they look: the client decodes problems with `try?` so a gateway's
/// HTML body can't throw. That means a *shape* mismatch is completely silent — no crash, no
/// log, just permanently empty error messages in the UI. These tests are the only thing
/// standing between a backend field rename and that failure.
final class APIProblemTests: XCTestCase {

    private func decode(_ json: String) -> APIProblem? {
        try? JSONDecoder().decode(APIProblem.self, from: Data(json.utf8))
    }

    func testTheDocumentedShape() {
        XCTAssertEqual(decode(#"{"code":0,"message":"Error message"}"#),
                       APIProblem(code: 0, message: "Error message"))
    }

    func testNonZeroCode() {
        XCTAssertEqual(decode(#"{"code":1042,"message":"Mobile already registered"}"#)?.code, 1042)
    }

    /// Tolerated so a backend switching to string codes can't silently break every message.
    func testStringCodeIsCoerced() {
        XCTAssertEqual(decode(#"{"code":"42","message":"x"}"#)?.code, 42)
    }

    func testMessageOnly() {
        XCTAssertEqual(decode(#"{"message":"Just a message"}"#),
                       APIProblem(code: nil, message: "Just a message"))
    }

    func testCodeOnly() {
        XCTAssertEqual(decode(#"{"code":7}"#), APIProblem(code: 7, message: nil))
    }

    // MARK: Things that are *not* a problem envelope

    func testEmptyObjectIsNotAProblem() {
        XCTAssertNil(decode("{}"), "an empty body is 'the server said nothing', not an empty complaint")
    }

    func testEmptyMessageIsTreatedAsAbsent() {
        XCTAssertNil(decode(#"{"message":""}"#))
    }

    func testUnrelatedJSONIsNotAProblem() {
        XCTAssertNil(decode(#"{"data":{"id":1}}"#))
    }

    func testHTMLFromAGatewayIsNotAProblem() {
        XCTAssertNil(decode("<html><body>503</body></html>"))
    }

    func testExtraFieldsAreIgnored() {
        XCTAssertEqual(decode(#"{"code":3,"message":"m","traceId":"abc","status":400}"#),
                       APIProblem(code: 3, message: "m"))
    }
}
