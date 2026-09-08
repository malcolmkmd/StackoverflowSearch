import Foundation
import JackpotForms

/// Turns a `FormSubmission` into an account.
public protocol RegistrationService: Sendable {
    func register(_ submission: FormSubmission) async throws -> RegistrationResult
}

/// An account, an optional session token, and whether FICA still needs a manual upload.
public struct RegistrationResult: Equatable, Sendable {
    public let accountId: String?
    public let accessToken: String?
    public let partialRegistrationStatus: Int?
    public let isValidId: Bool?
    public let message: String?
    public let complianceMessage: String?

    public init(accountId: String?,
                accessToken: String? = nil,
                partialRegistrationStatus: Int? = nil,
                isValidId: Bool? = nil,
                message: String? = nil,
                complianceMessage: String? = nil) {
        self.accountId = accountId
        self.accessToken = accessToken
        self.partialRegistrationStatus = partialRegistrationStatus
        self.isValidId = isValidId
        self.message = message
        self.complianceMessage = complianceMessage
    }

    public init(_ submit: FormSubmitResult) {
        self.init(
            accountId: submit.accountId,
            accessToken: submit.compliance?.accessToken,
            partialRegistrationStatus: submit.partialRegistrationStatus,
            isValidId: submit.compliance?.isValidId,
            message: submit.message,
            complianceMessage: submit.compliance?.message
        )
    }

    /// Account exists but auto-FICA didn't finish (`jpc-partially-complete-profile`).
    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }
}

/// Succeeds after a short delay; fails for mobile `"0000000000"`.
public struct MockRegistrationService: RegistrationService {
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.6) { self.delay = delay }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if submission["username"].stringValue == "0000000000" {
            throw RegistrationError.mobileAlreadyRegistered
        }
        return RegistrationResult(
            accountId: "27\(submission["username"].stringValue)",
            accessToken: "mock-token",
            message: "User Created Successfully."
        )
    }
}

/// Posts through `FormRepository.submitForm`.
public struct RemoteRegistrationService: RegistrationService {
    private let repository: any FormRepository

    public init(repository: any FormRepository) { self.repository = repository }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        do {
            return RegistrationResult(try await repository.submitForm(submission))
        } catch let error as FormLoadError {
            throw RegistrationError(error)
        }
    }
}

/// User-facing failures; `LocalizedError` because that's what the engine displays.
public enum RegistrationError: LocalizedError, Equatable {
    case mobileAlreadyRegistered
    case offline
    case server(message: String)
    case unexpected

    init(_ error: FormLoadError) {
        switch error {
        case .offline:              self = .offline
        case .server(let message):  self = .server(message: message)
        case .notFound, .unexpected:
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
