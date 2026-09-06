import Foundation
import JackpotNetworking
import JackpotFormsDomain

// The translation boundary. `JackpotFormsUI` never sees `APIError`, so this is where transport
// concerns become something a person can read.
enum FormErrorMapper {

    /// - Parameter localizer: resolves an error `code` to localised copy when the session's
    ///   table carries one. That beats `problem.message`, which arrives in whatever language
    ///   the API defaulted to. Typed as the Domain protocol so this target needs no
    ///   localisation dependency.
    static func map(_ error: any Error,
                    formName: FormName,
                    localizer: (any FormLocalizing)? = nil) -> any Error {
        guard let apiError = error as? APIError else { return error }

        switch apiError {
        case .cancelled:
            // Never user-facing: a cancelled load is a navigation event, not a failure.
            return CancellationError()

        case .transport where apiError.isOffline:
            return FormLoadError.offline

        case .unexpectedStatus(404, _):
            return FormLoadError.notFound(formName)

        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            // Localised copy for the code first, then whatever the server wrote, then ours —
            // the server is the only party that knows *why*.
            if let code = apiError.problem?.code,
               let localized = localizer?.message(forErrorCode: code) {
                return FormLoadError.server(message: localized)
            }
            if let message = apiError.serverMessage {
                return FormLoadError.server(message: message)
            }
            return FormLoadError.unexpected

        case .transport, .decoding, .invalidURL:
            return FormLoadError.unexpected
        }
    }
}
