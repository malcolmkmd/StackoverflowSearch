import SwiftUI

/// The border every input control shares: neutral, blue when focused, red when invalid.
public struct JackpotFieldBorder: ViewModifier {
    private let isInvalid: Bool
    private let isFocused: Bool
    @Environment(\.jackpotTheme) private var theme

    public init(isInvalid: Bool, isFocused: Bool = false) {
        self.isInvalid = isInvalid
        self.isFocused = isFocused
    }

    public func body(content: Content) -> some View {
        content
            .background(theme.fieldBackground)
            .cornerRadius(theme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(borderColor, lineWidth: isInvalid || isFocused ? 2 : 1)
            )
    }

    private var borderColor: Color {
        if isInvalid { return theme.fieldBorderInvalid }
        if isFocused { return theme.fieldBorderFocused }
        return theme.fieldBorder
    }
}

public extension View {
    func jackpotFieldBorder(isInvalid: Bool, isFocused: Bool = false) -> some View {
        modifier(JackpotFieldBorder(isInvalid: isInvalid, isFocused: isFocused))
    }
}

/// Label above, control in the middle, error beneath. The shape every form row shares.
public struct JackpotLabeledField<Content: View>: View {
    private let label: String?
    private let error: String?
    private let content: Content
    @Environment(\.jackpotTheme) private var theme

    public init(label: String? = nil, error: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.error = error
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label, !label.isEmpty {
                Text(label).font(.footnote).foregroundColor(theme.textSecondary)
            }
            content
            if let error, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(theme.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Error: \(error)")
            }
        }
    }
}

/// A hairline rule between groups.
public struct JackpotDivider: View {
    @Environment(\.jackpotTheme) private var theme
    public init() {}
    public var body: some View {
        Rectangle().fill(theme.fieldBorder).frame(height: 1).padding(.vertical, 4)
    }
}
