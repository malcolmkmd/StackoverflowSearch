import Foundation

struct MockFormRepository: FormRepository {
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.35) {
        self.delay = delay
    }

    func form(named name: FormName) async throws -> FormSchema {
        try await pause()
        guard name == .registration else { throw FormError.notFound(name) }
        return MockForm.schema
    }

    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        try await pause()
        let mobile = submission["username"].stringValue
        if mobile == "0000000000" {
            throw FormError.server(message: "That mobile number is already registered. Try logging in instead.")
        }
        return FormSubmitResult(accountId: "27\(mobile)", message: "User Created Successfully.")
    }

    private func pause() async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}

enum MockForm {
    static let translate: @Sendable (String) -> String = { copy[$0.lowercased()] ?? $0 }

    static let schema = FormSchema(
        id: 1052,
        codeName: .registration,
        sections: [
            FormSection(id: 45, rows: [
                row(1, FormField(id: 1, identifier: "username", inputType: .number, isRequired: true,
                                 regex: "^(27|0)?[1-9][0-9]{8}$", prefix: "+27")),
                row(2, FormField(id: 2, identifier: "password", inputType: .password, isRequired: true,
                                 regex: "^(.){8,20}$")),
                row(3, FormField(id: 3, identifier: "firstname", isRequired: true,
                                 regex: "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$")),
                row(4, FormField(id: 4, identifier: "lastname", isRequired: true,
                                 regex: "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$")),
                row(5, FormField(id: 5, identifier: "email", inputType: .email, isRequired: true,
                                 regex: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")),
                row(6, FormField(id: 6, identifier: "referralCode",
                                 regex: "^[a-zA-Z0-9]{3,25}$|^$")),
            ]),
            FormSection(id: 46, rows: [
                row(1, FormField(id: 7, identifier: "idNumberType", type: .dropdown, isRequired: true,
                                 regex: "^[a-zA-Z]+$",
                                 dropdownOptions: [
                                    .init(value: "idNumber", textKey: "jpc-reg-idnumber", regex: "idNumberRegex"),
                                    .init(value: "passport", textKey: "jpc-reg-passport", regex: "passportNumberRegex"),
                                 ])),
                row(2, FormField(id: 8, identifier: "idNumber", isRequired: true, regex: "^[0-9]{13}$")),
                row(3, FormField(id: 9, identifier: "dateOfBirth", inputType: .calendar, isRequired: true,
                                 regex: "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$")),
                row(4, FormField(id: 10, identifier: "sourceOfFunds", type: .dropdown, isRequired: true,
                                 regex: "^[a-zA-Z]+$",
                                 dropdownOptions: [
                                    .init(value: "SalaryOrWages", textKey: "jpc-reg-SalaryOrWages", regex: "[a-zA-Z]"),
                                    .init(value: "PensionOrGrant", textKey: "jpc-reg-PensionOrGrant", regex: "[a-zA-Z]"),
                                    .init(value: "AllowanceOrBursary", textKey: "jpc-reg-AllowanceOrBursary", regex: "[a-zA-Z]"),
                                    .init(value: "SavingsOrRentalOrOther", textKey: "jpc-reg-SavingsOrRentalOrOther", regex: "[a-zA-Z]"),
                                    .init(value: "SelfEmployed", textKey: "jpc-reg-SelfEmployed", regex: "[a-zA-Z]"),
                                 ])),
                row(5, FormField(id: 11, identifier: "receivePromotionalInformation",
                                 labelKey: "receivePromotionalInformation-jza", type: .checkbox,
                                 regex: "^true|^false$")),
                row(6, FormField(id: 12, identifier: "terms", type: .checkbox, isRequired: true, regex: "^true$")),
            ]),
        ],
        hasRecaptcha: true
    )

    private static func row(_ number: Int, _ field: FormField) -> FormRow {
        FormRow(number: number, fields: [field])
    }

    private static let copy: [String: String] = [
        "username": "Enter Mobile Number",
        "password": "Password",
        "firstname": "First Name (As it appears on your ID)",
        "lastname": "Surname (As it appears on ID)",
        "email": "Email",
        "referralcode": "I have a sign up code",
        "idnumbertype": "ID Number Type",
        "idnumber": "ID Number",
        "dateofbirth": "Enter Date Of Birth",
        "sourceoffunds": "Enter Source Of Income",
        "receivepromotionalinformation-jza": "Send Jackpot City Promotions to me",
        "terms": "I am over 18 years of age & I accept Jackpotcity's Terms & Conditions & Privacy Policy",
        "jpc-reg-idnumber": "South African ID",
        "jpc-reg-passport": "Passport",
        "jpc-reg-salaryorwages": "Salary or Wages",
        "jpc-reg-pensionorgrant": "Pension or Grant",
        "jpc-reg-allowanceorbursary": "Allowance or Bursary",
        "jpc-reg-savingsorrentalorother": "Savings, Rental or Other",
        "jpc-reg-selfemployed": "Self Employed",
        "jpc-reg-username-regex": "Enter a valid mobile number",
        "jpc-reg-password-regex": "Password must be 8–20 characters",
        "jpc-reg-firstname-regex": "Enter your first name as it appears on your ID",
        "jpc-reg-lastname-regex": "Enter your surname as it appears on your ID",
        "jpc-reg-email-regex": "Enter a valid email address",
        "jpc-reg-referralcode-regex": "Sign up codes are 3–25 letters or numbers",
        "jpc-reg-idnumbertype-regex": "Please select an ID type",
        "jpc-reg-idnumber-regex": "Enter in a valid ID number",
        "jpc-reg-dateofbirth-regex": "Enter date of birth",
        "jpc-reg-sourceoffunds-regex": "Please select your source of income.",
        "jpc-reg-terms-regex": "You must accept the Terms & Conditions to continue",
        "password-validity": "Password Validity",
        "next": "Next",
        "previous": "Previous",
        "sign-up": "Sign Up",
        "login": "Login",
        "already-have-account": "Already have an account?",
        "at-least-one-upper-char": "At least one uppercase character",
        "at-least-one-lower-char": "At least one lowercase character",
        "at-least-one-num-char": "At least one number",
        "at-least-one-special-char": "At least one special character",
        "min-8-char": "Minimum of 8 characters",
        "max-20-char": "Maximum of 20 characters",
        "required": "Required",
        "requirements-met": "Requirements met",
        "show-password": "Show password",
        "hide-password": "Hide password",
        "loading-form": "Loading form",
        "couldnt-load-form": "Couldn't load this form",
        "form-progress": "Form progress",
        "password-is-vulnerable": "Password contains 'password' - this can be unsafe",
        "please-remove-spaces": "Please remove spaces",
    ]
}
