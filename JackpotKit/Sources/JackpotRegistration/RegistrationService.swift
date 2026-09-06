import Foundation
import JackpotNetworking
import JackpotFormsDomain
import JackpotForms

/// What happens to the collected form values. The engine hands us a `FormSubmission`; this
/// turns it into an account.
public protocol RegistrationService: Sendable {
    func register(_ submission: FormSubmission) async throws -> RegistrationResult
}

/// What the app needs to know afterwards. ⚠️ Provisional: the registration POST's real
/// response shape is open question #5 in the forms README. Extend when it's confirmed.
public struct RegistrationResult: Equatable, Sendable {
    public let accountNumber: String?
    public let requiresOTP: Bool

    public init(accountNumber: String?, requiresOTP: Bool) {
        self.accountNumber = accountNumber
        self.requiresOTP = requiresOTP
    }
}

/// Succeeds after a short delay; fails if the mobile is `"0000000000"`. Enough to demo both
/// paths and to drive previews and tests.
public struct MockRegistrationService: RegistrationService {
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.6) { self.delay = delay }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if submission["username"].stringValue == "0000000000" {
            throw RegistrationError.mobileAlreadyRegistered
        }
        return RegistrationResult(accountNumber: "27\(submission["username"].stringValue)", requiresOTP: true)
    }
}

/// Posts the values to the registration endpoint.
///
/// ⚠️ The path, body shape and response shape are **not confirmed** — see open question #5.
/// This compiles and is wired, but `RegisterRequest` is a best guess to be corrected when the
/// backend contract is known. Keep the mock as the default until then.
public struct RemoteRegistrationService: RegistrationService {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) { self.apiClient = apiClient }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        do {
            let dto: RegisterResponseDTO = try await apiClient.request(RegisterRequest(fields: submission.stringValues))
            return RegistrationResult(accountNumber: dto.accountNumber, requiresOTP: dto.requiresOtp ?? false)
        } catch let error as APIError {
            throw RegistrationError(error)
        }
    }
}

struct RegisterRequest: APIEndpoint {
    let fields: [String: String]
    var path: String { "registration" }              // TODO: confirm with backend
    var method: HTTPMethod { .POST }
    var body: RequestBody? { try? .encodable(fields) }
    var requiresAuth: Bool { false }
}

struct RegisterResponseDTO: Decodable, Sendable {
    let accountNumber: String?
    let requiresOtp: Bool?
}

/// User-facing failures. `LocalizedError` because that's what the form engine displays.
public enum RegistrationError: LocalizedError, Equatable {
    case mobileAlreadyRegistered
    case offline
    case server(message: String)
    case unexpected

    init(_ apiError: APIError) {
        if apiError.isOffline { self = .offline; return }
        switch apiError {
        case .badRequest(let problem) where problem?.code == 1042:   // TODO: confirm code
            self = .mobileAlreadyRegistered
        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            if let message = apiError.serverMessage { self = .server(message: message) } else { self = .unexpected }
        default:
            self = .unexpected
        }
    }

    public var errorDescription: String? {
        switch self {
        case .mobileAlreadyRegistered: return "That mobile number is already registered. Try logging in instead."
        case .offline:                 return "You're offline. Check your connection and try again."
        case .server(let message):     return message
        case .unexpected:              return "Something went wrong. Please try again."
        }
    }
}
