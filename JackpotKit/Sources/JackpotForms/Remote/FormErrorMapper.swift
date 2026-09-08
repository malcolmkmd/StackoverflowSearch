import Foundation
import JackpotNetworking

// Where transport errors become something a person can read; the engine never sees `APIError`.
enum FormErrorMapper {
    static func map(_ error: any Error,
                    formName: FormName,
                    localizer: (any FormLocalizing)? = nil) -> any Error {
        guard let apiError = error as? APIError else { return error }

        switch apiError {
        // A cancelled load is a navigation event, not a failure.
        case .cancelled:
            return CancellationError()

        case .transport where apiError.isOffline:
            return FormError.offline

        case .unexpectedStatus(404, _):
            return FormError.notFound(formName)

        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            return message(code: apiError.problem?.code, server: apiError.serverMessage, localizer: localizer)
                .map { FormError.server(message: $0) } ?? FormError.unexpected

        case .transport, .decoding, .invalidURL:
            return FormError.unexpected
        }
    }

    /// Localised copy for the code, then the server's wording.
    static func message(code: Int?, server: String?, localizer: (any FormLocalizing)?) -> String? {
        code.flatMap { localizer?.message(forErrorCode: $0) } ?? server
    }
}
