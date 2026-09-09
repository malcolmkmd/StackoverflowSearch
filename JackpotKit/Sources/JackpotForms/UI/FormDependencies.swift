import Foundation

/// Everything the engine needs besides the form name. Defaults are generic; a feature adds its rules on top.
public struct FormDependencies {
    public var repository: any FormRepository
    /// The app's translation function: a key in, its text out, and the key itself on a miss.
    public var translate: @Sendable (String) -> String
    /// "This field's regex is chosen by that dropdown", by identifier. Declared, never inferred from row order.
    public var regexDependencies: [String: String]
    /// What a name on a dropdown option's `regex` stands for. A literal pattern there describes the selection itself.
    public var namedPatterns: [String: String]
    /// Latest date a calendar field may select; nil means today.
    public var maximumDate: Date?

    public init(repository: any FormRepository,
                translate: @escaping @Sendable (String) -> String = { $0 },
                regexDependencies: [String: String] = [:],
                namedPatterns: [String: String] = FormDependencies.jpcPatterns,
                maximumDate: Date? = nil) {
        self.repository = repository
        self.translate = translate
        self.regexDependencies = regexDependencies
        self.namedPatterns = namedPatterns
        self.maximumDate = maximumDate
    }

    /// `passportNumberRegex` is a length rule, not a character class.
    public static let jpcPatterns = [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ]
}

public extension FormDependencies {
    /// The bundled registration schema behind fake latency, so loading states are visible, with placeholder copy.
    static func mock(delay: TimeInterval = 0.35) -> FormDependencies {
        FormDependencies(repository: StubFormRepository(delay: delay), translate: { registrationCopy[$0] ?? $0 })
    }

    /// Placeholder copy for the registration keys, until the app's own strings are wired in.
    private static let registrationCopy = [
        "username": "Enter Mobile Number",
        "password": "Password",
        "firstname": "First Name (As it appears on your ID)",
        "lastname": "Surname (As it appears on ID)",
        "email": "Email",
        "referralCode": "I have a sign up code",
        "idNumberType": "ID Number Type",
        "idNumber": "ID Number",
        "dateOfBirth": "Enter Date Of Birth",
        "sourceOfFunds": "Enter Source Of Income",
        "receivePromotionalInformation-jza": "Send Jackpot City Promotions to me",
        "terms": "I am over 18 years of age & I accept Jackpotcity's Terms & Conditions & Privacy Policy",

        "jpc-reg-idnumber": "South African ID",
        "jpc-reg-passport": "Passport",
        "jpc-reg-SalaryOrWages": "Salary or Wages",
        "jpc-reg-PensionOrGrant": "Pension or Grant",
        "jpc-reg-AllowanceOrBursary": "Allowance or Bursary",
        "jpc-reg-SavingsOrRentalOrOther": "Savings, Rental or Other",
        "jpc-reg-SelfEmployed": "Self Employed",

        "jpc-reg-username-regex": "Enter a valid mobile number",
        "jpc-reg-password-regex": "Password must be 8–20 characters",
        "jpc-reg-firstname-regex": "Enter your first name as it appears on your ID",
        "jpc-reg-lastname-regex": "Enter your surname as it appears on your ID",
        "jpc-reg-email-regex": "Enter a valid email address",
        "jpc-reg-referralCode-regex": "Sign up codes are 3–25 letters or numbers",
        "jpc-reg-idNumberType-regex": "Please select an ID type",
        "jpc-reg-idNumber-regex": "Enter in a valid ID number",
        "jpc-reg-dateOfBirth-regex": "Enter date of birth",
        "jpc-reg-sourceOfFunds-regex": "Please select your source of income.",
        "jpc-reg-terms-regex": "You must accept the Terms & Conditions to continue",
    ]
}
