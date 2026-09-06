import Foundation
import JackpotNetworking

// Config service calling convention. Fetch, submit and app-data all live under
// `https://config.jpc.africa/cron` — production `buildFormURL` is
// `/cron/forms/jackpotcity/{wmsNavigationRegionCode}/{identifier}?api-version=2.0`.
// Submit is a sibling: `{cron}/forms/submit` with no version query item, so version
// belongs on the request, not on this environment.

public extension APIEnvironment {

    /// The cron config service — `https://config.jpc.africa/cron`.
    static func cron(baseURL: URL) -> APIEnvironment {
        APIEnvironment(
            baseURL: baseURL,
            defaultHeaders: ["Accept": "application/json"]
        )
    }

    /// `https://config.jpc.africa/crm` → `https://config.jpc.africa/cron`.
    ///
    /// Call sites historically passed a CRM base; production fetch is on cron.
    static func cronBaseURL(fromCRM url: URL) -> URL {
        switch url.lastPathComponent {
        case "crm":
            return url.deletingLastPathComponent().appendingPathComponent("cron")
        case "cron":
            return url
        default:
            return url.appendingPathComponent("cron")
        }
    }
}
