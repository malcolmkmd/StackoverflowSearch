import Foundation

/// Why a form operation failed, in terms the UI can render.
///
/// `JackpotFormsUI` depends on Domain only — never on `JackpotNetworking` — so `APIError` cannot reach
/// a view model. That's the layering working as intended, but it means the repository has to
/// translate at the boundary. Without this type the server's own wording ("Mobile number
/// already registered") gets decoded, carried all the way up, and then thrown away in favour
/// of a generic string.
///
/// `LocalizedError` because that's what `DynamicFormModel` reads.
public enum FormLoadError: LocalizedError, Equatable {
    case offline
    case notFound(FormName)
    /// The server explained itself. Prefer its wording over ours.
    case server(message: String)
    /// HTTP succeeded but the body reported `success: false`.
    case submissionFailed
    case unexpected

    public var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Check your connection and try again."
        case .notFound(let name):
            return "We couldn't find the \(name.rawValue) form. Please try again later."
        case .server(let message):
            return message
        case .submissionFailed:
            return "We couldn't submit the form. Please try again."
        case .unexpected:
            return "Something went wrong. Please try again."
        }
    }
}
