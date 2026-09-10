import XCTest
@testable import JackpotNetworking

final class BundledHTTPClientTests: XCTestCase {
    private let request = URLRequest(url: URL(string: "https://config.jpc.africa/cron/forms/submit")!)

    func testAFixtureIsServedAsA200() async throws {
        let client = BundledHTTPClient(.init(Data(#"{"isSuccessful":true}"#.utf8)))
        let (data, response) = try await client.send(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"isSuccessful":true}"#)
    }

    /// An unrouted request is a 404 rather than a crash, so a missing route surfaces through the
    /// same error path a real 404 would.
    func testAnUnroutedRequestIs404() async throws {
        let (data, response) = try await BundledHTTPClient { _ in nil }.send(request)
        XCTAssertEqual(response.statusCode, 404)
        XCTAssertTrue(data.isEmpty)
    }

    func testTheRouteCanDependOnWhatWasPosted() async throws {
        let client = BundledHTTPClient { request in
            let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
            return body.contains("reject") ? .init(Data("no".utf8), statusCode: 400) : .init(Data("yes".utf8))
        }
        var posted = request
        posted.httpBody = Data(#"{"fields":{"idNumber":"reject"}}"#.utf8)

        let (_, rejected) = try await client.send(posted)
        let (_, accepted) = try await client.send(request)
        XCTAssertEqual(rejected.statusCode, 400)
        XCTAssertEqual(accepted.statusCode, 200)
    }

    func testAMissingResourceIsNotAFixture() {
        XCTAssertNil(BundledHTTPClient.Fixture(resource: "no-such-file", in: .main))
    }
}
