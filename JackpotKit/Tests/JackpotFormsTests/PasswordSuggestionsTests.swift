import XCTest
@testable import JackpotForms

final class PasswordSuggestionsTests: XCTestCase {
    private let identity: (String) -> String = { $0 }

    func testChecklistRows() {
        let config = PasswordSuggestions.Config(min: 8, max: 20, vulnerable: true)
        let empty = PasswordSuggestions.items(for: "", config: config, translate: identity)
        XCTAssertEqual(empty.map(\.id), ["min", "max", "vulnerable"])
        XCTAssertEqual(empty.map(\.text), ["min-8-char", "max-20-char", "password-is-vulnerable"])
        XCTAssertEqual(empty.map(\.isSatisfied), [false, false, true])

        let ok = PasswordSuggestions.items(for: "longenough", config: config, translate: identity)
        XCTAssertEqual(ok.map(\.isSatisfied), [true, true, true])

        let vulnerable = PasswordSuggestions.items(for: "Password1", config: config, translate: identity)
        XCTAssertEqual(vulnerable.first { $0.id == "vulnerable" }?.isSatisfied, false)
    }

    func testSpacesAndCharacterClasses() {
        let config = PasswordSuggestions.Config(
            min: nil,
            max: nil,
            vulnerable: false,
            spaces: true,
            required: [.upper, .lower, .number, .special]
        )
        let items = PasswordSuggestions.items(for: "Ab1!", config: config, translate: identity)
        XCTAssertEqual(items.map(\.id), ["spaces", "upper", "lower", "number", "special"])
        XCTAssertTrue(items.allSatisfy(\.isSatisfied))

        let spaced = PasswordSuggestions.items(for: "Ab 1!", config: config, translate: identity)
        XCTAssertEqual(spaced.first { $0.id == "spaces" }?.isSatisfied, false)
    }

    func testTranslateIsAppliedToEveryRow() {
        let config = PasswordSuggestions.Config(min: 8, max: 20, vulnerable: true)
        let items = PasswordSuggestions.items(for: "secret", config: config, translate: { "T:\($0)" })
        XCTAssertEqual(items.map(\.text), ["T:min-8-char", "T:max-20-char", "T:password-is-vulnerable"])
    }
}
