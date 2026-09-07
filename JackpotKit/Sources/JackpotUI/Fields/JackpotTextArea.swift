import SwiftUI

public struct JackpotTextArea: View {
    @Binding private var text: String
    private let placeholder: String
    private var editingEndedAction: (() -> Void)?

    @Environment(\.jackpotTheme) private var theme
    @FocusState private var isFocused: Bool

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

    public var body: some View {
        ZStack(alignment: .topLeading) {
            editor
                .focused($isFocused)
                .frame(minHeight: theme.sizes.textAreaMinHeight)
                .padding(.s)
                .jackpotTextStyle(\.fieldText)
                .accessibilityLabel(placeholder)

            if text.isEmpty {
                Text(placeholder)
                    .jackpotTextStyle(\.fieldText, color: \.textSecondary)
                    .padding(.horizontal, .sm)
                    .padding(.vertical, .m)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .jackpotFieldBackground(isFocused: isFocused)
        .onChange(of: isFocused) { focused in
            if !focused { editingEndedAction?() }
        }
    }

    /// Before iOS 16 the only way to clear the editor's opaque background is
    /// `UITextView.appearance()`, which would affect every text view in the app.
    @ViewBuilder
    private var editor: some View {
        if #available(iOS 16.0, *) {
            TextEditor(text: $text).scrollContentBackground(.hidden)
        } else {
            TextEditor(text: $text)
        }
    }
}
