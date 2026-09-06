import SwiftUI

extension EnvironmentValues {
    @Entry public var jackpotTheme: JackpotTheme = .jackpotCity
    @Entry public var jackpotValidationMessage: String? = nil
    @Entry public var jackpotFieldLabel: String? = nil
    @Entry public var jackpotFieldPrefix: String = ""
    @Entry public var jackpotFieldSuffix: String = ""
    @Entry public var jackpotSecureEntry: Bool = false
    @Entry public var jackpotIsLoading: Bool = false
    @Entry public var jackpotIsSelected: Bool = false
    @Entry public var jackpotFocusedField: Binding<String?>? = nil
    @Entry public var jackpotFieldIdentity: String? = nil
    @Entry public var jackpotSubmitLabel: SubmitLabel = .return
}

// MARK: - Theme

public extension View {
    /// Sets `tint` alongside the theme, so system controls (pickers, toggles) inherit the brand
    /// accent without every call site remembering to.
    func jackpotTheme(_ theme: JackpotTheme) -> some View {
        environment(\.jackpotTheme, theme).tint(theme.colors.accent)
    }
}

// MARK: - Field configuration

public extension View {
    func jackpotValidationMessage(_ message: String?) -> some View {
        environment(\.jackpotValidationMessage, message?.isEmpty == false ? message : nil)
    }

    func jackpotFieldPrefix(_ text: String) -> some View {
        environment(\.jackpotFieldPrefix, text)
    }

    func jackpotFieldSuffix(_ text: String) -> some View {
        environment(\.jackpotFieldSuffix, text)
    }

    func jackpotSecureEntry(_ isEnabled: Bool = true) -> some View {
        environment(\.jackpotSecureEntry, isEnabled)
    }
}

// MARK: - Control state

public extension View {
    /// Disables as well as spins: a button that spins but still fires is a double submit.
    func jackpotLoading(_ isLoading: Bool = true) -> some View {
        environment(\.jackpotIsLoading, isLoading).disabled(isLoading)
    }

    func jackpotSelected(_ isSelected: Bool = true) -> some View {
        environment(\.jackpotIsSelected, isSelected)
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

    func jackpotSubmitLabel(_ label: SubmitLabel) -> some View {
        environment(\.jackpotSubmitLabel, label)
    }
}
