import SwiftUI

public struct JackpotTextField: View {
    @Binding private var text: String
    private let title: String
    private let kind: JackpotFieldKind
    private let prefix: String
    private let suffix: String
    private var editingEndedAction: (() -> Void)?
    private var focusChangedAction: ((Bool) -> Void)?

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.jackpotFocusedField) private var focusedField
    @Environment(\.jackpotFieldIdentity) private var identity
    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    private var requestedFocus: String? { focusedField?.wrappedValue }

    /// - Parameters:
    ///   - title: the in-field label. It floats to the top edge on focus or once there is text.
    ///   - kind: keyboard, autofill and secure-entry semantics.
    ///   - prefix: a fixed cell before the input, like `+27` on a mobile number.
    ///   - suffix: trailing text inside the field.
    public init(_ title: String,
                text: Binding<String>,
                kind: JackpotFieldKind = .text,
                prefix: String = "",
                suffix: String = "") {
        self.title = title
        self._text = text
        self.kind = kind
        self.prefix = prefix
        self.suffix = suffix
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
                    .padding(.horizontal, theme.sizes.contentPadding)
                    .frame(height: theme.sizes.controlHeight)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(theme.colors.fieldBorder).frame(width: 1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isFocused = true }
                    .accessibilityHidden(true)
            }

            JackpotFloatingField(title, isFloating: isFloating, isFocused: isFocused) {
                input
                    .jackpotTextStyle(\.fieldText)
                    .textInput(kind)
                    .focused($isFocused)
                    // The prefix cell is hidden above, so fold it in rather than leaving
                    // VoiceOver to stumble over a stray "+27".
                    .accessibilityLabel(prefix.isEmpty ? Text(title) : Text("\(title), \(prefix)"))
            }

            if !suffix.isEmpty {
                Text(suffix)
                    .jackpotTextStyle(\.fieldText, color: \.textSecondary)
                    .padding(.trailing, theme.sizes.contentPadding)
                    .contentShape(Rectangle())
                    .onTapGesture { isFocused = true }
            }

            if kind.isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .jackpotForegroundStyle(\.textPrimary)
                }
                .frame(width: theme.sizes.minimumHitTarget, height: theme.sizes.minimumHitTarget)
                .padding(.trailing, .xs)
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

    private var isFloating: Bool {
        isFocused || !text.isEmpty
    }

    @ViewBuilder
    private var input: some View {
        if kind.isSecure, !isRevealed {
            SecureField("", text: $text)
        } else {
            TextField("", text: $text)
        }
    }
}
