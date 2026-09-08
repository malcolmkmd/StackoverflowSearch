import SwiftUI

/// `TextInputAutocapitalization` is neither `Equatable` nor inspectable, so the kind stores its
/// own case and converts when applying.
public enum JackpotCapitalization: Equatable, Sendable {
    case never, words, sentences, characters

    var textInput: TextInputAutocapitalization {
        switch self {
        case .never:      return .never
        case .words:      return .words
        case .sentences:  return .sentences
        case .characters: return .characters
        }
    }
}

/// Keyboard, autofill, autocorrection and secure-entry settings as one value, so a field's
/// semantics are declared once — `JackpotTextField("Email", text: $email, kind: .email)` —
/// instead of as four loose modifiers per call site.
public struct JackpotFieldKind: Equatable, Sendable {
    public var keyboard: UIKeyboardType = .default
    public var contentType: UITextContentType?
    public var capitalization: JackpotCapitalization = .sentences
    public var disablesAutocorrection = false
    public var isSecure = false

    public static let text = JackpotFieldKind()

    public static let givenName = JackpotFieldKind(contentType: .givenName,
                                                   capitalization: .words,
                                                   disablesAutocorrection: true)

    public static let familyName = JackpotFieldKind(contentType: .familyName,
                                                    capitalization: .words,
                                                    disablesAutocorrection: true)

    public static let email = JackpotFieldKind(keyboard: .emailAddress,
                                               contentType: .emailAddress,
                                               capitalization: .never,
                                               disablesAutocorrection: true)

    public static let phoneNumber = JackpotFieldKind(keyboard: .phonePad,
                                                    contentType: .telephoneNumber,
                                                    capitalization: .never,
                                                    disablesAutocorrection: true)

    /// `.newPassword`, not `.password`: it opts the field into iOS's strong-password suggestion,
    /// which is what a registration form wants.
    public static let newPassword = JackpotFieldKind(contentType: .newPassword,
                                                     capitalization: .never,
                                                     disablesAutocorrection: true,
                                                     isSecure: true)

    public static let number = JackpotFieldKind(keyboard: .numberPad,
                                                capitalization: .never,
                                                disablesAutocorrection: true)

    public func with(_ transform: (inout JackpotFieldKind) -> Void) -> JackpotFieldKind {
        var copy = self
        transform(&copy)
        return copy
    }
}

extension View {
    /// Applies the kind's keyboard and autofill settings. Secure entry is the field's own
    /// business, because it decides between `SecureField` and `TextField`.
    func textInput(_ kind: JackpotFieldKind) -> some View {
        keyboardType(kind.keyboard)
            .textContentType(kind.contentType)
            .textInputAutocapitalization(kind.capitalization.textInput)
            .autocorrectionDisabled(kind.disablesAutocorrection)
    }
}
