import SwiftUI

extension EnvironmentValues {
    @Entry public var jackpotTheme: JackpotTheme = .jackpotCity
    @Entry public var jackpotIsLoading: Bool = false
    @Entry public var jackpotFocusedField: Binding<String?>? = nil
    @Entry public var jackpotFieldIdentity: String? = nil
    /// Identity by default, so a component still renders the key when no table is wired.
    public var jackpotTranslate: @Sendable (String) -> String {
        get { self[JackpotTranslateKey.self] }
        set { self[JackpotTranslateKey.self] = newValue }
    }

    @Entry var jackpotFieldError: String? = nil
}

private struct JackpotTranslateKey: EnvironmentKey {
    static let defaultValue: @Sendable (String) -> String = { $0 }
}

// MARK: - Theme

public extension View {
    /// Sets `tint` too, so system controls follow the accent.
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
    /// One focused-field value shared by a group so the return key can walk it; tag fields with `jackpotFieldIdentity(_:)`.
    func jackpotFocusedField(_ binding: Binding<String?>) -> some View {
        environment(\.jackpotFocusedField, binding)
    }

    func jackpotFieldIdentity(_ identity: String) -> some View {
        environment(\.jackpotFieldIdentity, identity)
    }
}
