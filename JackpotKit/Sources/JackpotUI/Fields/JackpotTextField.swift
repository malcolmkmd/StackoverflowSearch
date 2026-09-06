import SwiftUI

public struct JackpotTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private var editingEndedAction: (() -> Void)?
    private var focusChangedAction: ((Bool) -> Void)?

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.jackpotFieldPrefix) private var prefix
    @Environment(\.jackpotFieldSuffix) private var suffix
    @Environment(\.jackpotSecureEntry) private var isSecure
    @Environment(\.jackpotFocusedField) private var focusedField
    @Environment(\.jackpotFieldIdentity) private var identity
    @Environment(\.jackpotSubmitLabel) private var submitLabel
    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    private var requestedFocus: String? { focusedField?.wrappedValue }

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    /// Fires on blur. Chain it before any `View` modifier, like `Gesture.onEnded`.
    public func onEditingEnded(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.editingEndedAction = action
        return copy
    }

    /// Fires on both focus and blur. The field owns its `FocusState`, so this is the only way
    /// out for callers that reveal supporting content while the field is being edited.
    public func onFocusChange(_ action: @escaping (Bool) -> Void) -> Self {
        var copy = self
        copy.focusChangedAction = action
        return copy
    }

    public var body: some View {
        HStack(spacing: 0) {
            if !prefix.isEmpty {
                Text(prefix)
                    .jackpotTextStyle(\.fieldText)
                    .padding(.horizontal, theme.metrics.contentPadding)
                    .frame(height: theme.metrics.controlHeight)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(theme.colors.fieldBorder).frame(width: 1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isFocused = true }
                    .accessibilityHidden(true)
            }

            input
                .jackpotTextStyle(\.fieldText)
                .focused($isFocused)
                .submitLabel(submitLabel)
                .padding(.horizontal, theme.metrics.contentPadding)
                .frame(height: theme.metrics.controlHeight)
                // The prefix cell is hidden above, so fold it in rather than leaving
                // VoiceOver to stumble over a stray "+27".
                .accessibilityLabel(prefix.isEmpty ? Text(placeholder) : Text("\(placeholder), \(prefix)"))

            if !suffix.isEmpty {
                Text(suffix)
                    .jackpotTextStyle(\.fieldText, color: \.textSecondary)
                    .padding(.trailing, theme.metrics.contentPadding)
                    .contentShape(Rectangle())
                    .onTapGesture { isFocused = true }
            }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .jackpotForegroundStyle(\.textPrimary)
                }
                .frame(width: theme.metrics.minimumHitTarget, height: theme.metrics.minimumHitTarget)
                .padding(.trailing, 6)
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
        }
        .jackpotFieldBackground(isFocused: isFocused)
        .onChange(of: isFocused) { focused in
            focusChangedAction?(focused)
            if focused {
                if let identity { focusedField?.wrappedValue = identity }
            } else {
                editingEndedAction?()
            }
        }
        // The other half of the sync: the form moves the shared value, the field follows.
        // Guarded both ways so the two `onChange`s cannot ping-pong.
        .onChange(of: requestedFocus) { requested in
            guard focusedField != nil, let identity else { return }
            let shouldFocus = requested == identity
            if isFocused != shouldFocus { isFocused = shouldFocus }
        }
    }

    @ViewBuilder
    private var input: some View {
        if isSecure, !isRevealed {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}
