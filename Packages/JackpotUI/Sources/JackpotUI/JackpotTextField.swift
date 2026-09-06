import SwiftUI
import UIKit

/// A text input with the panel's chrome: optional prefix cell (`+27`), suffix, secure-entry
/// reveal toggle, focus ring and red invalid border.
///
/// Owns its own focus state and reports edits ending through `onEditingEnded`, so a form can
/// mark the field "touched" on blur without the component knowing what a form is.
///
/// Takes `UIKeyboardType` and `UITextContentType` directly. An earlier version wrapped them in
/// its own enums so the package would also type-check on a macOS host — that bought CLI
/// `swift test` at the cost of a parallel vocabulary and a mapping switch needing extension for
/// every new content type. The package is iOS-only, and the manifest already said so.
public struct JackpotTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private let prefix: String
    private let suffix: String
    private let keyboard: UIKeyboardType
    private let contentType: UITextContentType?
    private let autocapitalization: TextInputAutocapitalization
    private let isSecure: Bool
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onEditingEnded: () -> Void

    @Environment(\.jackpotTheme) private var theme
    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    public init(_ placeholder: String,
                text: Binding<String>,
                prefix: String = "",
                suffix: String = "",
                keyboard: UIKeyboardType = .default,
                contentType: UITextContentType? = nil,
                autocapitalization: TextInputAutocapitalization = .sentences,
                isSecure: Bool = false,
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onEditingEnded: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self._text = text
        self.prefix = prefix
        self.suffix = suffix
        self.keyboard = keyboard
        self.contentType = contentType
        self.autocapitalization = autocapitalization
        self.isSecure = isSecure
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onEditingEnded = onEditingEnded
    }

    public var body: some View {
        HStack(spacing: 0) {
            if !prefix.isEmpty {
                Text(prefix)
                    .font(.body)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: theme.controlHeight)
                    .overlay(Rectangle().fill(theme.fieldBorder).frame(width: 1), alignment: .trailing)
            }

            Group {
                if isSecure, !isRevealed {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body)
            .foregroundColor(theme.textPrimary)
            .focused($isFocused)
            .disabled(isDisabled)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(keyboard != .default)
            .padding(.horizontal, 14)
            .frame(height: theme.controlHeight)

            if !suffix.isEmpty {
                Text(suffix).foregroundColor(theme.textSecondary).padding(.trailing, 14)
            }

            if isSecure {
                Button { isRevealed.toggle() } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye").foregroundColor(theme.textPrimary)
                }
                .frame(width: 44, height: 44)
                .padding(.trailing, 6)
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
        }
        .jackpotFieldBorder(isInvalid: isInvalid, isFocused: isFocused)
        .onChange(of: isFocused) { focused in
            if !focused { onEditingEnded() }
        }
    }
}
