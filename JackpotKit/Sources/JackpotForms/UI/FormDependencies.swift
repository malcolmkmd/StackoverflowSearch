import Foundation

/// Everything the engine needs besides the form name. Defaults are generic; a feature adds its rules on top.
public struct FormDependencies {
    public var repository: any FormRepository
    public var localizer: any FormLocalizing
    /// "This dropdown drives this field's regex", by identifier. Declared, never inferred from row order.
    public var regexDependencies: [String: String]
    /// What a name on a dropdown option's `regex` stands for. A literal pattern there describes the selection itself.
    public var namedPatterns: [String: String]
    /// Latest date a calendar field may select; nil means today.
    public var maximumDate: Date?

    public init(repository: any FormRepository,
                localizer: any FormLocalizing = ClosureLocalizer { _ in nil },
                regexDependencies: [String: String] = [:],
                namedPatterns: [String: String] = FormDependencies.jpcPatterns,
                maximumDate: Date? = nil) {
        self.repository = repository
        self.localizer = localizer
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
    /// The bundled registration schema behind fake latency, so loading states are visible.
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: BundledForms.all, delay: delay, error: error),
            localizer: localizer ?? ClosureLocalizer.jpcRegistration
        )
    }
}
