import Foundation

public extension ComposedKeyLocalizer {
    /// Placeholder copy for the registration schema's keys, matching the designs. In
    /// production the same table arrives in the app-data response's `locales` section; this
    /// one keeps the form legible until it does, and stands in for it in previews and the
    /// sandbox.
    static let jpcRegistration = ComposedKeyLocalizer(table: [
        // Field labels
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
