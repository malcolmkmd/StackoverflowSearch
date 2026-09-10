import Foundation

public struct FormDependencies {
    public var repository: any FormRepository
    /// A key in, its text out, and the key itself on a miss.
    public var translate: @Sendable (String) -> String
    /// "This field's regex is chosen by that dropdown", by identifier. Declared, never inferred from row order.
    public var regexDependencies: [String: String]
    /// What a name on a dropdown option's `regex` stands for. A literal pattern there describes the selection itself.
    public var namedPatterns: [String: String]
    public var maximumDate: Date?
    public var passwordConfig: PasswordSuggestions.Config
    /// Returns a v3 assessment token for the given action, or nil to skip. The app wires this to Google's SDK; the package never imports it.
    public var recaptcha: @Sendable (String) async throws -> String?

    public init(repository: any FormRepository,
                translate: @escaping @Sendable (String) -> String = { $0 },
                regexDependencies: [String: String] = [:],
                namedPatterns: [String: String] = FormDependencies.jpcPatterns,
                maximumDate: Date? = nil,
                passwordConfig: PasswordSuggestions.Config = .init(),
                recaptcha: @escaping @Sendable (String) async throws -> String? = { _ in nil }) {
        self.repository = repository
        self.translate = translate
        self.regexDependencies = regexDependencies
        self.namedPatterns = namedPatterns
        self.maximumDate = maximumDate
        self.passwordConfig = passwordConfig
        self.recaptcha = recaptcha
    }

    /// `passportNumberRegex` is a length rule, not a character class.
    public static let jpcPatterns = [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ]
}

public extension FormDependencies {
    static func mock(delay: TimeInterval = 0.35) -> FormDependencies {
        FormDependencies(
            repository: MockFormRepository(delay: delay),
            translate: MockForm.translate,
            passwordConfig: .init(min: 8, max: 20, vulnerable: true),
            recaptcha: { _ in "mock-recaptcha-token" }
        )
    }
}
