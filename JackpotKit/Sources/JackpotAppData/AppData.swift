import Foundation
import JackpotNetworking

/// The once-per-session bootstrap call:
///
///     GET {cron}/app-data/{region}/{platform}/{tenant}/{locale}?api-version=1.0
///     GET .../cron/app-data/JZA/IOS/jackpotcity/en-US?api-version=1.0
///
/// `tenant` is the brand (`jackpotcity`). Note this is a **different version** from the forms
/// fetch (`/cron/forms/...` at `api-version=2.0`) on the same host, so the version belongs to
/// the request rather than to a shared environment.
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
/// `redirects`, `sitemaps`, `locales` — owned by six different parts of the app. Splitting the
/// top-level keys up front gives one network call and six independent decodes, so a CMS edit
/// that nulls the strings cannot also take app settings, sitemaps and registration with it.
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

    /// The `locales` table. Every other section belongs to whichever feature owns it, and
    /// each decodes its own type from the same response.
    public var locales: [String: String] {
        section("locales") ?? [:]
    }
}

public enum AppDataError: Error, Equatable {
    /// The payload's top level wasn't a JSON object.
    case notAnObject
    /// The server reported nothing changed while there was nothing cached to serve.
    case noPayload
}
