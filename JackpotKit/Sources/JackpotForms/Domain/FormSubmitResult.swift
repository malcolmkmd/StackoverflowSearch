import Foundation

public struct FormSubmitResult: Decodable, Equatable, Sendable {
    public let accountId: String?
    public let message: String?
    private let partialRegistrationStatus: Int?
    private let complianceResponse: Compliance?

    private struct Compliance: Decodable, Equatable, Sendable {
        let accessToken: String?
    }

    public init(accountId: String? = nil, message: String? = nil) {
        self.accountId = accountId
        self.message = message
        partialRegistrationStatus = nil
        complianceResponse = nil
    }

    /// Account exists but auto-FICA didn't finish (`jpc-partially-complete-profile`).
    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }

    /// The session token when the account was created; the app logs in with it.
    public var accessToken: String? { complianceResponse?.accessToken }
}
