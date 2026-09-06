import Foundation

/// The cache validators a response came back with.
///
/// The app-data response carries `last-modified`; if the service also emits `etag`, that wins.
/// Sending these back turns a revalidation into a 304 with an empty body — the round trip still
/// happens, but nothing is transferred or decoded.
public struct HTTPValidators: Sendable, Equatable, Codable {
    public let etag: String?
    public let lastModified: String?

    public init(etag: String?, lastModified: String?) {
        self.etag = etag
        self.lastModified = lastModified
    }

    public init?(_ response: HTTPURLResponse) {
        let etag = response.value(forHTTPHeaderField: "ETag")
        let lastModified = response.value(forHTTPHeaderField: "Last-Modified")
        guard etag != nil || lastModified != nil else { return nil }
        self.etag = etag
        self.lastModified = lastModified
    }

    var conditionalHeaders: [String: String] {
        var headers: [String: String] = [:]
        if let etag { headers["If-None-Match"] = etag }
        if let lastModified { headers["If-Modified-Since"] = lastModified }
        return headers
    }
}

public enum ConditionalResponse: Sendable, Equatable {
    /// 304 — what we already hold is current.
    case notModified
    case fresh(Data, HTTPValidators?)
}
