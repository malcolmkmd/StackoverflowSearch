import XCTest
@testable import JackpotLocalization

/// Keys and values below are taken from the real app-data response.
final class TranslationsTests: XCTestCase {

    private let sample = Translations([
        "6000328": "Maximum OTP tries reached, Please contact support on +233 30 825 5838",
        "markets.windrawwin": "1X2",
        "new-site": "New Site",
        "select-password-reset-method": "Select Password Reset Method",
        "jpc-fixed-jackpots-starts-in": "Starts in",
        "city-jackpots": "City Jackpots",
        "receivePromotionalInformation": "Send me promotions",
        "receivePromotionalInformation-jza": "Send Jackpot City Promotions to me",
    ], regionCode: "JZA")

    // MARK: Lookup

    func testResolvesAKey() {
        XCTAssertEqual(sample("new-site"), "New Site")
        XCTAssertEqual(sample("markets.windrawwin"), "1X2")
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(sample("NEW-SITE"), "New Site")
        XCTAssertEqual(sample("New-Site"), "New Site")
    }

    /// A missing key renders as itself — visible in QA, rather than an empty label.
    func testMissingKeyFallsBackToTheKey() {
        XCTAssertEqual(sample("no-such-key"), "no-such-key")
        XCTAssertNil(sample.string(forKey: "no-such-key"))
    }

    // MARK: Region cascade

    func testRegionalVariantWinsWhenItExists() {
        XCTAssertEqual(sample("receivePromotionalInformation"),
                       "Send Jackpot City Promotions to me")
    }

    func testPlainKeyUsedWhenNoRegionalVariantExists() {
        XCTAssertEqual(sample("new-site"), "New Site")
    }

    func testRegionalLookupCanBeForcedOff() {
        XCTAssertEqual(sample("receivePromotionalInformation", regional: false),
                       "Send me promotions")
    }

    /// The CRM sometimes hands us a key that already carries the region suffix — the
    /// registration schema's `fieldLabel` is literally `receivePromotionalInformation-jza`.
    /// Looking that up must not double-suffix into a miss.
    func testAPreSuffixedKeyStillResolves() {
        XCTAssertEqual(sample("receivePromotionalInformation-jza"),
                       "Send Jackpot City Promotions to me")
    }

    func testNoRegionMeansNoRegionalLookup() {
        let noRegion = Translations(["a-jza": "regional", "a": "plain"], regionCode: nil)
        XCTAssertEqual(noRegion("a"), "plain")
        XCTAssertNil(noRegion.regionSuffix)
    }

    func testBlankRegionIsTreatedAsAbsent() {
        XCTAssertNil(Translations(["a": "b"], regionCode: "   ").regionSuffix)
    }

    // MARK: Error codes

    /// The table doubles as an error-code catalogue, which is what ties an API error envelope
    /// (`{"code": 6000328, …}`) to a sentence in the player's language.
    func testErrorCodeResolvesToItsMessage() {
        XCTAssertEqual(sample.message(forErrorCode: 6000328),
                       "Maximum OTP tries reached, Please contact support on +233 30 825 5838")
    }

    func testPrefixedRegistrationErrorCodeResolves() {
        let table = Translations(["jpc-reg-error.153008": "An error occurred"], regionCode: "JZA")
        XCTAssertEqual(table.message(forErrorCode: 153008), "An error occurred")
    }

    func testUnknownErrorCodeIsNil() {
        XCTAssertNil(sample.message(forErrorCode: 999))
    }

    /// A numeric code must never pick up the region suffix — "6000328-jza" isn't a thing.
    func testErrorCodeLookupIgnoresRegion() {
        let table = Translations(["123": "plain", "123-jza": "regional"], regionCode: "JZA")
        XCTAssertEqual(table.message(forErrorCode: 123), "plain")
    }

    /// The app's existing key enums are `String`-backed, so `rawValue` is all the bridge needs.
    func testStringBackedEnumsResolveThroughTheirRawValue() {
        enum FixedJackpotTranslationsKeys: String {
            case startsIn = "jpc-fixed-jackpots-starts-in"
            case cityJackpots = "city-jackpots"
        }
        XCTAssertEqual(sample(FixedJackpotTranslationsKeys.startsIn.rawValue), "Starts in")
        XCTAssertEqual(sample(FixedJackpotTranslationsKeys.cityJackpots.rawValue), "City Jackpots")
    }

    // MARK: Housekeeping

    func testEmptyTable() {
        let empty = Translations()
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty("anything"), "anything")
    }

    /// Lookup must not rebuild the lowercased table each time: 50k lookups against a 2k-row
    /// table finish in well under a second only if normalisation happens once, at init.
    func testLookupIsConstantTimeNotAFullTableRebuild() {
        let big = Translations(
            Dictionary(uniqueKeysWithValues: (0..<2_000).map { ("key-\($0)", "value-\($0)") }),
            regionCode: "jza"
        )
        let started = Date()
        for index in 0..<50_000 {
            _ = big("KEY-\(index % 2_000)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.0)
    }
}
