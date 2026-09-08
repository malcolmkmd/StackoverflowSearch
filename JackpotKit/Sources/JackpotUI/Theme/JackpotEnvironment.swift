import SwiftUI

// What travels through the environment is what genuinely cascades: the theme, a button's
// loading state, and the shared focus value a group of fields coordinates on. Per-field data
// (label, kind, prefix) is an initialiser argument on the field itself.

extension EnvironmentValues {
    @Entry public var jackpotTheme: JackpotTheme = .jackpotCity
    @Entry public var jackpotIsLoading: Bool = false
    @Entry public var jackpotFocusedField: Binding<String?>? = nil
    @Entry public var jackpotFieldIdentity: String? = nil

    /// Set by `jackpotFieldError(_:)` and read by the field chrome, so the invalid ring and the
    /// message under the control always agree.
    @Entry var jackpotFieldError: String? = nil
}

// MARK: - Theme

public extension View {
    /// Sets `tint` alongside the theme, so system controls (pickers, toggles) inherit the brand
    /// accent without every call site remembering to.
    func jackpotTheme(_ theme: JackpotTheme) -> some View {
        environment(\.jackpotTheme, theme).tint(theme.colors.accent)
    }
}

// MARK: - Control state

public extension View {
    /// Disables as well as spins: a button that spins but still fires is a double submit.
    func jackpotLoading(_ isLoading: Bool = true) -> some View {
        environment(\.jackpotIsLoading, isLoading).disabled(isLoading)
    }
}

// MARK: - Keyboard focus

public extension View {
    /// Shares one "which field is focused" value across a group of fields so the return key
    /// can walk them. Tag each field with `jackpotFieldIdentity(_:)`.
    func jackpotFocusedField(_ binding: Binding<String?>) -> some View {
        environment(\.jackpotFocusedField, binding)
    }

    func jackpotFieldIdentity(_ identity: String) -> some View {
        environment(\.jackpotFieldIdentity, identity)
    }
}
