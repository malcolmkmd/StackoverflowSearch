import Foundation

/// The error envelope the API returns with a non-2xx response:
///
///     { "code": 0, "message": "Error message" }
///
/// `code` is a **number**, not a string — an earlier version had it as `String?`, which meant
/// `{"code": 0}` failed to decode and every problem silently came back `nil`. Since decoding is
/// `try?` by design (a gateway may return HTML, and that must not throw), a shape mismatch here
/// is invisible: you get no crash, no log, just permanently empty error messages. It decodes
/// both number and string forms now so a backend that changes its mind can't reintroduce that.
public struct APIProblem: Decodable, Sendable, Equatable {
    public let code: Int?
    public let message: String?

    public init(code: Int?, message: String?) {
        self.code = code
        self.message = message
    }

    private enum CodingKeys: String, CodingKey { case code, message }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedCode: Int?
        if let number = try? container.decodeIfPresent(Int.self, forKey: .code) {
            decodedCode = number
        } else {
            decodedCode = (try? container.decodeIfPresent(String.self, forKey: .code)).flatMap { $0.flatMap(Int.init) }
        }
        let decodedMessage = (try? container.decodeIfPresent(String.self, forKey: .message))?.flatMap {
            $0.isEmpty ? nil : $0
        }

        // A body carrying neither field — `{}`, or JSON that happens to parse but isn't a
        // problem envelope — is *not* a problem. Throwing here means the client's `try?`
        // yields nil, so `.badRequest(nil)` correctly reads "the server said nothing"
        // rather than "the server sent an empty complaint".
        guard decodedCode != nil || decodedMessage != nil else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Not a problem envelope: neither `code` nor `message` present"
            ))
        }

        code = decodedCode
        message = decodedMessage
    }
}

/// What the client concluded happened.
///
/// The API contract is **200, 400, 401, 500** — those four have named cases. Anything else can
/// still arrive from a proxy, gateway, WAF or a misrouted deploy, so `unexpectedStatus` carries
/// it rather than pretending it can't happen or silently reporting it as a server error.
///
/// Distinct from `APIProblem`: this enum is client-authored and closed (new cases need an app
/// release); `APIProblem` is server-authored and open (new codes ship without one).
public enum APIError: Error, Sendable, Equatable {
    case invalidURL(String)
    case transport(URLError.Code)
    /// 400 — the request was rejected. `problem.message` is the text to show.
    case badRequest(APIProblem?)
    /// 401 — after any interceptor has had its one chance to refresh and retry.
    case unauthorized(APIProblem?)
    /// 500 — after one retry, if the endpoint was idempotent.
    case server(APIProblem?)
    /// Outside the documented contract. Almost always infrastructure rather than the API.
    case unexpectedStatus(Int, APIProblem?)
    case decoding(String)
    case cancelled

    /// The server's envelope, whichever case carries it.
    public var problem: APIProblem? {
        switch self {
        case .badRequest(let p), .unauthorized(let p), .server(let p), .unexpectedStatus(_, let p):
            return p
        case .invalidURL, .transport, .decoding, .cancelled:
            return nil
        }
    }

    /// The server's own wording, when it sent any. Prefer this over a generic string.
    public var serverMessage: String? {
        problem?.message.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var isOffline: Bool {
        guard case .transport(let code) = self else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut].contains(code)
    }

}
