import Foundation
import JackpotNetworking

/// The once-per-session bootstrap call:
///
///     GET https://config.jpc.africa/cron/app-data/{region}/{platform}/{tenant}/{locale}?api-version=1.0
///     GET .../cron/app-data/JZA/IOS/synapse/en-US?api-version=1.0
///
/// Note this is a **different service and version** from the forms endpoint
/// (`/crm/forms/...` at `api-version=2.0`) on the same host — the response advertises
/// `api-supported-versions: 1.0,2.0`. Two services, one gateway, so the version belongs to the
/// request rather than to a single shared environment.
public struct AppDataRequest: APIEndpoint {
    let region: String
    let platform: String
    let tenant: String
    let locale: String

    public init(region: String, platform: String = "IOS", tenant: String, locale: String) {
        self.region = region
        self.platform = platform
        self.tenant = tenant
        self.locale = locale
    }

    public var path: String { "cron/app-data/\(region)/\(platform)/\(tenant)/\(locale)" }
    public var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "1.0")] }
    public var requiresAuth: Bool { false }
}

/// One response, decoded a section at a time.
///
/// The payload carries six unrelated things — `appsettings`, `wmsconfig`, `registration`,
/// `redirects`, `sitemaps`, `locales` — owned by six different parts of the app. Two ways to
/// model that, and only one of them survives contact with a CMS:
///
/// **The single-struct version** (what the app does today) puts every section in one
/// `Decodable` and decodes them together. It has two failure modes:
///
/// - Any section using non-optional `decode` takes the **whole response** with it when that
///   key is null. The app's `ConfigData` does exactly this for `locales`, so a CMS edit that
///   nulls the strings also loses app settings, sitemaps, redirects and registration — none
///   of which have anything to do with copy.
/// - It becomes the next god object. Every feature that needs a slice adds a property, and
///   nothing can be extracted afterwards.
///
/// **This version** splits the top-level keys up front and hands each one out on request. One
/// network call, six independent decodes, and a malformed `wmsconfig` cannot stop `locales`
/// from loading. `section(_:as:)` returns nil rather than throwing, because a section this
/// build doesn't understand is not a reason to fail the ones it does.
public struct AppDataResponse: Sendable, Equatable {

    private let sections: [String: Data]

    public init(data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppDataError.notAnObject
        }
        sections = object.reduce(into: [:]) { result, pair in
            // A null section is the same as an absent one.
            guard !(pair.value is NSNull) else { return }
            guard let data = try? JSONSerialization.data(withJSONObject: pair.value,
                                                         options: [.fragmentsAllowed]) else { return }
            result[pair.key] = data
        }
    }

    /// Decodes one section, or nil if it's absent, null, or shaped differently than expected.
    /// Never throws: one feature's broken section must not break another's.
    public func section<T: Decodable>(_ key: String,
                                      as type: T.Type = T.self,
                                      decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = sections[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// Which sections actually arrived. Worth logging — it's how you notice the CMS has
    /// started returning null for something the app depends on.
    public var presentSections: [String] { sections.keys.sorted() }

    public func contains(_ key: String) -> Bool { sections[key] != nil }

    // MARK: Sections this module owns

    /// The `locales` table. Every other section belongs to whichever feature owns it —
    /// `wmsconfig` to app settings, `sitemaps` to navigation, `registration` to sign-up —
    /// and each decodes its own type from the same response.
    public var locales: [String: String] {
        section("locales") ?? [:]
    }
}

public enum AppDataError: Error, Equatable {
    case notAnObject
}
