import Foundation

/// Why a form operation failed, in terms the UI can render.
///
/// The engine never sees `APIError`; the repository translates at the boundary, so the
/// server's own wording survives the trip. Without this type the server's own wording
/// ("Mobile number already registered") gets decoded, carried up, and then thrown away in
/// favour of a generic string.
public enum FormLoadError: LocalizedError, Equatable {
    case offline
    case notFound(FormName)
    /// The server explained itself. Prefer its wording over ours.
    case server(message: String)
    case unexpected

    public var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Check your connection and try again."
        case .notFound(let name):
            return "We couldn't find the \(name.rawValue) form. Please try again later."
        case .server(let message):
            return message
        case .unexpected:
            return "Something went wrong. Please try again."
        }
    }
}
