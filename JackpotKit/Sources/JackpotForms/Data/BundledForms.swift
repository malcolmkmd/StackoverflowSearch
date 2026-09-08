import Foundation

/// The schemas shipped with the package as JSON, keyed by `formCodeName`. The stub repository,
/// previews and tests all read them from here. `registration.json` is the CRM's response for
/// `forms/jackpotcity/JZA/registration?api-version=2.0`, saved verbatim.
enum BundledForms {
    static var all: [FormName: Data] {
        [.registration: json(named: "registration")]
    }

    static func json(named name: String) -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("Missing bundled schema \(name).json")
            return Data("{}".utf8)
        }
        return data
    }
}
