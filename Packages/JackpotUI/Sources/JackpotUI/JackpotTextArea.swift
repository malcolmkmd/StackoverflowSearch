import SwiftUI

/// Multi-line input. `TextEditor` has no placeholder on iOS 15, hence the overlay.
public struct JackpotTextArea: View {
    @Binding private var text: String
    private let placeholder: String
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onEditingEnded: () -> Void

    @Environment(\.jackpotTheme) private var theme
    @FocusState private var isFocused: Bool

    public init(_ placeholder: String,
                text: Binding<String>,
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onEditingEnded: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self._text = text
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onEditingEnded = onEditingEnded
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($isFocused)
                .frame(minHeight: 110)
                .padding(8)
                .foregroundColor(theme.textPrimary)
                .disabled(isDisabled)
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .jackpotFieldBorder(isInvalid: isInvalid, isFocused: isFocused)
        .onChange(of: isFocused) { focused in
            if !focused { onEditingEnded() }
        }
    }
}
