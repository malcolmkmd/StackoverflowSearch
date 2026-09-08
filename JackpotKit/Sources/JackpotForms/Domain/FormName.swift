import Foundation

/// The `formCodeName` in the schema and the last path component of the fetch URL. A struct rather than an
/// enum because forms are authored server-side, so `FormName("deposit")` must be constructible; not
/// `ExpressibleByStringLiteral`, so a typo cannot compile into a 404.
public struct FormName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - Known forms

public extension FormName {
    /// The two-section sign-up form: credentials, name and email, then FICA.
    static let registration = FormName("registration")
}
