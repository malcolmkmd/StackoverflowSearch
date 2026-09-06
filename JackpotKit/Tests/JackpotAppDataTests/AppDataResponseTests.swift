import XCTest
@testable import JackpotAppData
import JackpotNetworking

/// The bootstrap payload carries six unrelated sections owned by six parts of the app. These
/// assert that one section can never take down another — which is the failure the app's
/// current `ConfigData` has, because it decodes `locales` with non-optional `decode` while
/// every other section uses `decodeIfPresent`.
final class AppDataResponseTests: XCTestCase {

    private func response(_ json: String) throws -> AppDataResponse {
        try AppDataResponse(data: Data(json.utf8))
    }

    // MARK: The real shape

    func testDecodesLocalesFromTheRealPayloadShape() throws {
        let payload = try response(#"""
        {
          "appsettings": null, "wmsconfig": null, "registration": null,
          "redirects": null, "sitemaps": null,
          "locales": { "new-site": "New Site", "6000328": "Maximum OTP tries reached" }
        }
        """#)
        XCTAssertEqual(payload.locales["new-site"], "New Site")
        XCTAssertEqual(payload.presentSections, ["locales"])
    }

    /// A null section is the same as an absent one, and neither is an error.
    func testNullSectionsAreTreatedAsAbsent() throws {
        let payload = try response(#"{ "locales": {"a":"A"}, "sitemaps": null }"#)
        XCTAssertFalse(payload.contains("sitemaps"))
        XCTAssertTrue(payload.contains("locales"))
    }

    // MARK: Independence — the point of the type

    struct WMSConfig: Decodable, Equatable { let regionCode: String? }

    func testSectionsDecodeIndependently() throws {
        let payload = try response(#"""
        { "wmsconfig": { "regionCode": "JZA" }, "locales": { "a": "A" } }
        """#)
        XCTAssertEqual(payload.section("wmsconfig", as: WMSConfig.self), WMSConfig(regionCode: "JZA"))
        XCTAssertEqual(payload.locales, ["a": "A"])
    }

    /// The bug this design exists to prevent: today, one bad section loses all six.
    func testAMalformedSectionDoesNotCostYouTheOthers() throws {
        let payload = try response(#"""
        { "wmsconfig": "this should have been an object", "locales": { "a": "A" } }
        """#)
        XCTAssertNil(payload.section("wmsconfig", as: WMSConfig.self))
        XCTAssertEqual(payload.locales, ["a": "A"], "a broken wmsconfig must not lose the strings")
    }

    /// The mirror image, and the one that actually bites: today `locales` is decoded with
    /// non-optional `decode`, so nulling it throws and takes appsettings, sitemaps, redirects
    /// and registration down with it.
    func testMissingLocalesDoesNotCostYouTheOtherSections() throws {
        let payload = try response(#"""
        { "wmsconfig": { "regionCode": "JZA" }, "sitemaps": { "sitemap": [] }, "locales": null }
        """#)
        XCTAssertEqual(payload.locales, [:], "no strings — degraded, not fatal")
        XCTAssertEqual(payload.section("wmsconfig", as: WMSConfig.self), WMSConfig(regionCode: "JZA"))
        XCTAssertTrue(payload.contains("sitemaps"))
    }

    /// A section this build has never heard of must not be an error — the CMS adds them
    /// without an app release.
    func testUnknownSectionsAreIgnoredButVisible() throws {
        let payload = try response(#"{ "locales": {"a":"A"}, "somethingNew": { "x": 1 } }"#)
        XCTAssertEqual(payload.presentSections, ["locales", "somethingNew"])
        XCTAssertEqual(payload.locales, ["a": "A"])
    }

    // MARK: Malformed input

    func testNonObjectPayloadThrows() {
        XCTAssertThrowsError(try response("[1,2,3]")) { error in
            XCTAssertEqual(error as? AppDataError, .notAnObject)
        }
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try response("<html>502</html>"))
    }

    func testEmptyObjectYieldsNoSections() throws {
        let payload = try response("{}")
        XCTAssertTrue(payload.presentSections.isEmpty)
        XCTAssertEqual(payload.locales, [:])
    }

    // MARK: Endpoint

    func testBuildsTheURLFromTheCurlCommand() throws {
        let request = try AppDataRequest(region: "JZA", tenant: "jackpotcity", locale: "en-US")
            .urlRequest(in: .init(baseURL: URL(string: "https://config.jpc.africa")!))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://config.jpc.africa/cron/app-data/JZA/IOS/jackpotcity/en-US?api-version=1.0")
    }

    /// Bootstrap runs before login.
    func testBootstrapDoesNotRequireAuth() {
        XCTAssertFalse(AppDataRequest(region: "JZA", tenant: "synapse", locale: "en-US").requiresAuth)
    }
}
