import Foundation

/// What `POST /cron/forms/submit` returns on a 2xx body.
///
/// HTTP 200 is not success — the envelope carries `isSuccessful` and an `error` object.
/// A created account can still need manual FICA (`partialRegistrationStatus`, compliance).
public struct FormSubmitResult: Equatable, Sendable {
    public let accountId: String?
    public let message: String?
    public let status: String?
    public let partialRegistrationStatus: Int?
    public let compliance: FormComplianceResult?

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

    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }
}

public struct FormComplianceResult: Equatable, Sendable {
    public let complianceStatus: Int?
    public let requiredComplianceStatus: Int?
    public let isValidId: Bool?
    public let message: String?
    public let accessToken: String?

    public init(complianceStatus: Int? = nil,
                requiredComplianceStatus: Int? = nil,
                isValidId: Bool? = nil,
                message: String? = nil,
                accessToken: String? = nil) {
        self.complianceStatus = complianceStatus
        self.requiredComplianceStatus = requiredComplianceStatus
        self.isValidId = isValidId
        self.message = message
        self.accessToken = accessToken
    }
}
