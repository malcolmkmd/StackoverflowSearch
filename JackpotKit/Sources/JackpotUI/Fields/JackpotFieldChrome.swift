import SwiftUI

// MARK: - Background

/// Fill, hairline and the focused / invalid ring every field shares.
public struct JackpotFieldBackground: ViewModifier {
    private let isFocused: Bool

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.jackpotFieldError) private var error
    @Environment(\.isEnabled) private var isEnabled

    public init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }

    public func body(content: Content) -> some View {
        content
            .jackpotBackground(\.fieldBackground, in: theme.sizes.fieldShape)
            .overlay {
                theme.sizes.fieldShape
                    .strokeBorder(borderColor, lineWidth: borderWidth)
                    .animation(.easeOut(duration: 0.15), value: emphasis)
            }
            .opacity(isEnabled ? 1 : 0.6)
    }

    private enum Emphasis: Equatable { case none, focused, invalid }

    private var emphasis: Emphasis {
        if error != nil { return .invalid }
        return isFocused ? .focused : .none
    }

    private var borderColor: Color {
        switch emphasis {
        case .invalid: return theme.colors.fieldBorderInvalid
        case .focused: return theme.colors.fieldBorderFocused
        case .none:    return theme.colors.fieldBorder
        }
    }

    /// Width as well as colour, so focus and errors are not carried by colour alone.
    private var borderWidth: CGFloat {
        emphasis == .none ? theme.sizes.borderWidth : theme.sizes.emphasizedBorderWidth
    }
}

public extension View {
    func jackpotFieldBackground(isFocused: Bool = false) -> some View {
        modifier(JackpotFieldBackground(isFocused: isFocused))
    }
}

// MARK: - Error row

public extension View {
    /// Marks a field invalid: the chrome draws the invalid ring and `message` appears beneath
    /// the control. Nil or empty clears both. Apply it to the whole field, not just the input.
    func jackpotFieldError(_ message: String?) -> some View {
        modifier(JackpotFieldErrorRow(message: message?.isEmpty == false ? message : nil))
    }
}

private struct JackpotFieldErrorRow: ViewModifier {
    let message: String?

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: .xs) {
            content.environment(\.jackpotFieldError, message)

            if let message {
                Text(message)
                    .jackpotTextStyle(\.error, color: \.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Error: \(message)")
            }
        }
        .animation(.easeOut(duration: 0.2), value: message)
    }
}

// MARK: - Floating label

/// The in-field label the text field, dropdown and date field share. It sits where a
/// placeholder would and rises to the top edge of the control when the field is focused or
/// holds a value; `content` is the value drawn beneath it.
struct JackpotFloatingField<Content: View>: View {
    private let title: String
    private let isFloating: Bool
    private let isFocused: Bool
    private let content: Content
    private let raisedLabelOffset: CGFloat = -16

    @Environment(\.jackpotTheme) private var theme

    init(_ title: String, isFloating: Bool, isFocused: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isFloating = isFloating
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            content
                .padding(.top, isFloating ? theme.sizes.spacing : 0)

            Text(title)
                .jackpotFont(\.fieldText)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .scaleEffect(isFloating ? 0.85 : 1, anchor: .leading)
                .offset(y: isFloating ? raisedLabelOffset : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.sizes.contentPadding)
        .frame(height: theme.sizes.controlHeight)
        .animation(.easeOut(duration: 0.15), value: isFloating)
    }
}

