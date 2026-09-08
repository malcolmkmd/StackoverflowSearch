import Foundation

/// What `POST /cron/forms/submit` returns. HTTP 200 is not success, and a created account can still need manual FICA.
public struct FormSubmitResult: Decodable, Equatable, Sendable {
    public let accountId: String?
    public let message: String?
    public let status: String?
    public let partialRegistrationStatus: Int?
    public let compliance: FormComplianceResult?

    enum CodingKeys: String, CodingKey {
        case accountId, message, status, partialRegistrationStatus
        case compliance = "complianceResponse"
    }

    public init(accountId: String? = nil,
                message: String? = nil,
                status: String? = nil,
                partialRegistrationStatus: Int? = nil,
                compliance: FormComplianceResult? = nil) {
        self.accountId = accountId
        self.message = message
        self.status = status
        self.partialRegistrationStatus = partialRegistrationStatus
        self.compliance = compliance
    }

    /// Account exists but auto-FICA didn't finish (`jpc-partially-complete-profile`).
    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }
}

/// `accessToken` is the session token when the account was created; the app logs in with it.
public struct FormComplianceResult: Decodable, Equatable, Sendable {
    public let complianceStatus: Int?
    public let requiredComplianceStatus: Int?
    public let isValidId: Bool?
    public let message: String?
    public let accessToken: String?
}
