import Foundation
import JackpotNetworking

// Fetch, submit and app-data all live under `https://config.jpc.africa/cron`. Fetch carries
// `api-version=2.0` and submit carries none, so the version belongs on the request rather than
// on this environment.

public extension APIEnvironment {

    /// The cron config service — `https://config.jpc.africa/cron`.
    static func cron(baseURL: URL) -> APIEnvironment {
        APIEnvironment(baseURL: baseURL)
    }

    /// `https://config.jpc.africa/crm` → `https://config.jpc.africa/cron`, because call sites
    /// historically passed a CRM base and production fetch is on cron.
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
