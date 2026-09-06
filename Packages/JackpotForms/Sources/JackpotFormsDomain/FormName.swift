import Foundation

/// Identifies a form in the CRM — the `formCodeName` in the schema, and the last path
/// component of the fetch URL.
///
/// Deliberately **not** an enum. Forms are authored server-side and new ones appear
/// without an app release, so a closed set would fight the architecture: the moment the
/// CRM serves `deposit`, a `switch` somewhere would stop compiling or a new form would be
/// unreachable until the next submission to the App Store.
///
/// Instead this is the `Notification.Name` pattern — a `RawRepresentable` wrapper with
/// static members for the forms this build knows about:
///
///     DynamicFormView(formName: .registration) { ... }     // autocompleted, typo-proof
///     DynamicFormView(formName: FormName("deposit")) { ... } // server-authored, still fine
///
/// Note it is **not** `ExpressibleByStringLiteral`. If it were, `formName: "registraton"`
/// would still compile and you'd be back to a runtime 404 — which is the whole problem this
/// type exists to remove. Constructing one from an arbitrary string is possible but has to be
/// written out, so `FormName(` is greppable at review time.
public struct FormName: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Shorthand for the static members below and for server-authored names.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

// MARK: - Known forms
//
// Add a case here when the CRM starts serving a form you reference by name in code.
// Forms you only ever reach dynamically (from a sitemap, a deep link, the forms list
// endpoint) never need an entry — construct them with `FormName(_:)`.

public extension FormName {
    /// The two-section sign-up form: credentials + name + email, then FICA.
    static let registration = FormName("registration")

    /// Development-only schema exercising every supported field type.
    static let kitchenSink = FormName("kitchenSink")

    /// Forms bundled with the package as JSON, for mocks, previews and the sandbox.
    static let bundled: [FormName] = [.registration, .kitchenSink]
}
