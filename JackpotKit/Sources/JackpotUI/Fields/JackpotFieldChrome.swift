import SwiftUI

public struct JackpotFieldBackground: ViewModifier {
    private let isFocused: Bool

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.jackpotValidationMessage) private var validationMessage
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
        if validationMessage != nil { return .invalid }
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

struct JackpotFloatingLabel: View {
    let title: String
    let isFloating: Bool
    var isFocused: Bool = false

    @Environment(\.jackpotTheme) private var theme

    var body: some View {
        Text(title)
            .font(isFloating ? theme.typography.label : theme.typography.fieldText)
            .environment(\.font, isFloating ? theme.typography.label : theme.typography.fieldText)
            .foregroundStyle(labelColor)
            .scaleEffect(isFloating ? 0.75 : 1, anchor: .leading)
            .lineLimit(1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var labelColor: Color {
        if isFloating {
            return isFocused ? theme.colors.accent : theme.colors.textPrimary
        }
        return theme.colors.textSecondary
    }
}

// MARK: - Form row

public struct JackpotLabeledField<Content: View>: View {
    private let label: String?
    private let error: String?
    private let content: Content

    public init(_ label: String? = nil, error: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.error = error
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .xs) {
            if let label, !label.isEmpty {
                Text(label).jackpotTextStyle(\.label, color: \.textSecondary)
            }

            content
                .jackpotValidationMessage(error)
                .environment(\.jackpotFieldLabel, label)

            if let error, !error.isEmpty {
                Text(error)
                    .jackpotTextStyle(\.error, color: \.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Error: \(error)")
            }
        }
        .animation(.easeOut(duration: 0.2), value: error)
    }
}

// MARK: - Divider

public struct JackpotDivider: View {
    @Environment(\.jackpotTheme) private var theme

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(theme.colors.fieldBorder)
            .frame(height: 1)
            .padding(.vertical, .xxs)
            .accessibilityHidden(true)
    }
}
