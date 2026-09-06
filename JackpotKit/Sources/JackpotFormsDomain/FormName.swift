import Foundation

/// Identifies a form in the CRM — the `formCodeName` in the schema, and the last path
/// component of the fetch URL.
///
/// Deliberately not an enum. Forms are authored server-side and new ones appear without an app
/// release, so a closed set would fight the architecture. This is the `Notification.Name`
/// pattern instead: a `RawRepresentable` wrapper with static members for the forms this build
/// knows about, and `FormName("deposit")` for anything else.
///
/// Not `ExpressibleByStringLiteral`, on purpose: `formName: "registraton"` would compile and
/// give a runtime 404. Constructing one from an arbitrary string has to be written out, so
/// `FormName(` stays greppable at review time.
/// Not `Codable`: a form name never crosses a serialisation boundary as itself. Decoding goes
/// `FormDTO.formCodeName` (a `String`) → `FormName(_:)` in the mapper, and encoding goes
/// `FormSubmitBody.formName = submission.formCodeName.rawValue`. Both directions are explicit at
/// the wire type, which is where the JSON key names already live.
public struct FormName: RawRepresentable, Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

// MARK: - Known forms
//
// Add a member here when the CRM starts serving a form you reference by name in code. Forms
// you only ever reach dynamically — from a sitemap, deep link or the forms list endpoint —
// never need one.

public extension FormName {
    /// The two-section sign-up form: credentials + name + email, then FICA.
    static let registration = FormName("registration")

    /// Development-only schema exercising every supported field type.
    static let kitchenSink = FormName("kitchenSink")

    /// Forms bundled with the package as JSON, for mocks, previews and the sandbox.
    static let bundled: [FormName] = [.registration, .kitchenSink]
}
