import Foundation
import JackpotForms
import JackpotLocalization

public extension Translations {
    /// Feeds the app's table to the form engine. Lives here so neither module knows the other.
    /// `regional: true` covers both key shapes the schema uses: plain keys pick up `-jza`, suffixed keys resolve directly.
    var formLocalizer: ClosureLocalizer {
        ClosureLocalizer({ string(forKey: $0, regional: true) },
                         errorCode: { message(forErrorCode: $0) })
    }
}
