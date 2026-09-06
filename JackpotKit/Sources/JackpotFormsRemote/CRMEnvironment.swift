import Foundation
import JackpotNetworking

// The CRM config service's calling convention.
//
// This used to live on `APIEnvironment` in JackpotCore, which was wrong for the same reason the
// reference project's `APIEndpoint.asURLRequest()` splicing in `StackExchangeRequest
// .commonQueryItems()` was wrong: it bakes one service's identity into a type that is meant
// to describe *any* service. A generic networking layer that names `config.jpc.africa` is
// not generic — it just hasn't been asked to serve a second host yet.
//
// The knowledge belongs next to `FormRequest`, which already encodes the rest of the same
// contract (the `forms/{brand}/{region}/{name}` path shape).

public extension APIEnvironment {

    /// The JackpotCity CRM config service — `https://config.jpc.africa/crm`.
    ///
    /// `api-version` is a query item on every call, not a header, and applies to the whole
    /// service rather than to the forms resource. Pass the version explicitly when the CRM
    /// moves on; the default tracks whatever the forms endpoint currently expects.
    ///
    /// If another feature starts talking to the same CRM, promote this to a shared target —
    /// don't copy it.
    static func crm(baseURL: URL, apiVersion: String = "2.0") -> APIEnvironment {
        APIEnvironment(
            baseURL: baseURL,
            defaultHeaders: ["Accept": "application/json"],
            defaultQueryItems: [URLQueryItem(name: "api-version", value: apiVersion)]
        )
    }
}
