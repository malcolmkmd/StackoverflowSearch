import Foundation
import SwiftUI
import JackpotFormsDomain

/// Turns the schema's keys into the copy in the designs. In production the equivalent table
/// arrives in the app-data response's `locales` section.
public extension ComposedKeyLocalizer {
    static let jpcRegistration = ComposedKeyLocalizer(table: [
        // Placeholders / labels
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
        "acceptTermsConditions": "I am over 18 years of age & I accept Jackpotcity's Terms & Conditions & Privacy Policy",

        // Dropdown options
        "jpc-reg-idnumber": "South African ID",
        "jpc-reg-passport": "Passport",
        "jpc-reg-SalaryOrWages": "Salary or Wages",
        "jpc-reg-PensionOrGrant": "Pension or Grant",
        "jpc-reg-AllowanceOrBursary": "Allowance or Bursary",
        "jpc-reg-SavingsOrRentalOrOther": "Savings, Rental or Other",
        "jpc-reg-SelfEmployed": "Self Employed",

        // Composed validation messages: jpc-reg-{fieldIdentifier}-{validationMessage}
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
    ])
}

public enum FormPreviewData {
    /// `Bundle.module` is internal, so it cannot appear in a public default argument — hence
    /// this overload rather than `bundle: Bundle = .module`.
    public static func bundledJSON(named name: String) -> Data {
        json(named: name, in: .module)
    }

    public static func json(named name: String, in bundle: Bundle) -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("Missing fixture \(name).json")
            return Data("{}".utf8)
        }
        return data
    }

    /// The schemas shipped with the package, keyed by `formCodeName`.
    public static var bundledForms: [FormName: Data] {
        Dictionary(uniqueKeysWithValues: FormName.bundled.map { ($0, bundledJSON(named: $0.rawValue)) })
    }
}
