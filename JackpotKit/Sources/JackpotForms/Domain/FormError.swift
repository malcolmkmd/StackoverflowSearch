import Foundation

/// Why a form operation failed, in words the UI can show. `server` keeps the server's wording.
public enum FormError: LocalizedError, Equatable {
    case offline
    case notFound(FormName)
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
