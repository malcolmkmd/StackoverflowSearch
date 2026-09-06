# Build Playbook

Create the files in the order given. Run the commands where they appear. Open a PR where marked.

159 tests when complete.

`JackpotKit` is one package, so the whole suite runs in a simulator via
`xcodebuild -scheme JackpotKit-Package`.

---

## PR 1 — JackpotUI

**1.**

```bash
mkdir -p JackpotKit/Sources/JackpotUI/{Theme,Styles,Fields,Components,Preview}
mkdir -p JackpotKit/Tests/JackpotUITests
cd JackpotKit
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

**2.** `JackpotKit/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JackpotKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
    ],
    targets: [
        .target(name: "JackpotUI"),
        .testTarget(name: "JackpotUITests", dependencies: ["JackpotUI"]),
    ]
)
```

Later PRs append their targets to this same manifest rather than creating new packages.

**3.** `JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift`

```swift
import SwiftUI
import UIKit

public struct JackpotTheme: Equatable, Sendable {
    public var colors: JackpotColors = .jackpotCity
    public var metrics: JackpotMetrics = .standard
    public var typography: JackpotTypography = .standard

    public static let jackpotCity = JackpotTheme()

    public func with(_ transform: (inout JackpotTheme) -> Void) -> JackpotTheme {
        var copy = self
        transform(&copy)
        return copy
    }
}

// MARK: - Colours

public struct JackpotColors: Equatable, Sendable {
    public var surface = Palette.surface
    public var surfaceElevated = Palette.surfaceElevated

    public var fieldBackground = Palette.fieldBackground
    public var fieldBorder = Palette.fieldBorder
    public var fieldBorderFocused = Palette.accent
    public var fieldBorderInvalid = Palette.error

    public var textPrimary = Palette.textPrimary
    public var textSecondary = Palette.textSecondary
    public var textOnAccent = Palette.textOnAccent

    public var accent = Palette.accent
    public var actionPrimary = Palette.actionPrimary
    public var currency = Palette.actionPrimary

    public var error = Palette.error
    public var warning = Palette.warning
    public var success = Palette.success

    public static let jackpotCity = JackpotColors()
}

/// Held as shared constants rather than inline literals so two separately built
/// `JackpotColors` still compare equal — a dynamic `Color` compares by identity.
enum Palette {
    static let surface = Color.adaptive(light: Color(red: 1.00, green: 1.00, blue: 1.00),
                                        dark: Color(red: 0.07, green: 0.08, blue: 0.09))

    static let surfaceElevated = Color.adaptive(light: Color(red: 0.96, green: 0.97, blue: 0.98),
                                                dark: Color(red: 0.11, green: 0.12, blue: 0.14))

    static let fieldBackground = Color.adaptive(light: Color(red: 1.00, green: 1.00, blue: 1.00),
                                                dark: Color(red: 0.13, green: 0.14, blue: 0.16))

    static let fieldBorder = Color.adaptive(light: Color(red: 0.80, green: 0.82, blue: 0.85),
                                            dark: Color.white.opacity(0.18))

    static let textPrimary = Color.adaptive(light: Color(red: 0.07, green: 0.09, blue: 0.12),
                                            dark: .white)

    static let textSecondary = Color.adaptive(light: Color(red: 0.42, green: 0.45, blue: 0.50),
                                              dark: Color.white.opacity(0.6))

    /// Sits on the accent and action fills, never on the surface, so it does not invert.
    static let textOnAccent = Color.white

    static let accent = Color.adaptive(light: Color(red: 0.13, green: 0.40, blue: 0.87),
                                       dark: Color(red: 0.16, green: 0.47, blue: 0.96))

    static let actionPrimary = Color.adaptive(light: Color(red: 0.85, green: 0.60, blue: 0.05),
                                              dark: Color(red: 0.96, green: 0.71, blue: 0.13))

    static let error = Color.adaptive(light: Color(red: 0.80, green: 0.16, blue: 0.10),
                                      dark: Color(red: 0.94, green: 0.28, blue: 0.16))

    static let warning = Color.adaptive(light: Color(red: 0.72, green: 0.45, blue: 0.02),
                                        dark: Color(red: 0.96, green: 0.62, blue: 0.13))

    static let success = Color.adaptive(light: Color(red: 0.10, green: 0.55, blue: 0.32),
                                        dark: Color(red: 0.20, green: 0.72, blue: 0.44))
}

extension Color {
    /// Resolves against the trait collection, so one palette serves both appearances and
    /// honours a `preferredColorScheme` override anywhere in the hierarchy.
    static func adaptive(light: Color, dark: Color) -> Color {
        let light = UIColor(light)
        let dark = UIColor(dark)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Metrics

public struct JackpotMetrics: Equatable, Sendable {
    public var cornerRadius: CGFloat = 10
    public var controlHeight: CGFloat = 52
    public var spacing: CGFloat = 12
    public var contentPadding: CGFloat = 14
    public var borderWidth: CGFloat = 1
    public var emphasizedBorderWidth: CGFloat = 2
    public var minimumHitTarget: CGFloat = 44
    public var progressBarHeight: CGFloat = 4
    public var textAreaMinHeight: CGFloat = 110
    public var cardMinHeight: CGFloat = 140

    public static let standard = JackpotMetrics()

    public var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Typography

public struct JackpotTypography: Equatable, Sendable {
    public var fieldText = Font.body
    public var label = Font.footnote
    public var error = Font.caption
    public var rowLabel = Font.subheadline
    public var sectionTitle = Font.subheadline.weight(.semibold)
    public var button = Font.headline

    public static let standard = JackpotTypography()
}
```

**4.** `JackpotKit/Sources/JackpotUI/Theme/JackpotEnvironment.swift`

The environment carries the theme and the per-field configuration, so the fields themselves stay
free of configuration parameters.

```swift
import SwiftUI

extension EnvironmentValues {
    @Entry public var jackpotTheme: JackpotTheme = .jackpotCity
    @Entry public var jackpotValidationMessage: String? = nil
    @Entry public var jackpotFieldLabel: String? = nil
    @Entry public var jackpotFieldPrefix: String = ""
    @Entry public var jackpotFieldSuffix: String = ""
    @Entry public var jackpotSecureEntry: Bool = false
    @Entry public var jackpotIsLoading: Bool = false
    @Entry public var jackpotFocusedField: Binding<String?>? = nil
    @Entry public var jackpotFieldIdentity: String? = nil
    @Entry public var jackpotSubmitLabel: SubmitLabel = .return
}

// MARK: - Theme

public extension View {
    func jackpotTheme(_ theme: JackpotTheme) -> some View {
        environment(\.jackpotTheme, theme).tint(theme.colors.accent)
    }

    func jackpotTheme(_ transform: @escaping (inout JackpotTheme) -> Void) -> some View {
        modifier(JackpotThemeTransform(transform: transform))
    }
}

private struct JackpotThemeTransform: ViewModifier {
    let transform: (inout JackpotTheme) -> Void
    @Environment(\.jackpotTheme) private var inherited

    func body(content: Content) -> some View {
        var theme = inherited
        transform(&theme)
        return content.jackpotTheme(theme)
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
```

**5.** `JackpotKit/Sources/JackpotUI/Theme/JackpotStyling.swift`

```swift
import SwiftUI

public extension View {
    func jackpotForegroundStyle(_ color: KeyPath<JackpotColors, Color>) -> some View {
        modifier(JackpotForegroundStyle(color: color))
    }

    func jackpotBackground(_ color: KeyPath<JackpotColors, Color>) -> some View {
        modifier(JackpotBackgroundStyle(color: color, shape: Rectangle()))
    }

    func jackpotBackground<S: Shape>(_ color: KeyPath<JackpotColors, Color>, in shape: S) -> some View {
        modifier(JackpotBackgroundStyle(color: color, shape: shape))
    }

    func jackpotFont(_ font: KeyPath<JackpotTypography, Font>) -> some View {
        modifier(JackpotFontStyle(font: font))
    }

    func jackpotTextStyle(_ font: KeyPath<JackpotTypography, Font>,
                          color: KeyPath<JackpotColors, Color> = \.textPrimary) -> some View {
        jackpotFont(font).jackpotForegroundStyle(color)
    }
}

private struct JackpotForegroundStyle: ViewModifier {
    let color: KeyPath<JackpotColors, Color>
    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundStyle(theme.colors[keyPath: color])
    }
}

private struct JackpotBackgroundStyle<S: Shape>: ViewModifier {
    let color: KeyPath<JackpotColors, Color>
    let shape: S
    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content.background(theme.colors[keyPath: color], in: shape)
    }
}

private struct JackpotFontStyle: ViewModifier {
    let font: KeyPath<JackpotTypography, Font>
    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content.font(theme.typography[keyPath: font])
    }
}
```

**6.** `JackpotKit/Sources/JackpotUI/Styles/JackpotButtonStyle.swift`

```swift
import SwiftUI

public struct JackpotButtonStyle: ButtonStyle {
    public enum Prominence: Hashable, Sendable {
        case primary
        case secondary
        case tertiary
    }

    private let prominence: Prominence

    public init(_ prominence: Prominence = .primary) {
        self.prominence = prominence
    }

    public func makeBody(configuration: Configuration) -> some View {
        // A ButtonStyle is not a View, so @Environment on the style itself never updates.
        ButtonBody(prominence: prominence, configuration: configuration)
    }

    private struct ButtonBody: View {
        let prominence: Prominence
        let configuration: ButtonStyleConfiguration

        @Environment(\.jackpotTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.jackpotIsLoading) private var isLoading

        var body: some View {
            configuration.label
                .jackpotFont(\.button)
                .opacity(isLoading ? 0 : 1)
                .overlay {
                    if isLoading {
                        ProgressView().tint(foreground).accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: theme.metrics.controlHeight)
                .foregroundStyle(foreground)
                .background(background, in: theme.metrics.fieldShape)
                .contentShape(theme.metrics.fieldShape)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
                .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
        }

        /// `jackpotLoading(_:)` disables the button, but mid-submit it should still look live.
        private var isDimmed: Bool { !isEnabled && !isLoading }

        private var background: Color {
            switch prominence {
            case .primary:   return isDimmed ? theme.colors.fieldBackground : theme.colors.accent
            case .secondary: return theme.colors.fieldBackground
            case .tertiary:  return .clear
            }
        }

        private var foreground: Color {
            switch prominence {
            case .primary:   return isDimmed ? theme.colors.textSecondary : theme.colors.textOnAccent
            case .secondary: return isDimmed ? theme.colors.textSecondary : theme.colors.textPrimary
            case .tertiary:  return isDimmed ? theme.colors.textSecondary : theme.colors.accent
            }
        }
    }
}

public extension ButtonStyle where Self == JackpotButtonStyle {
    static var jackpot: JackpotButtonStyle { JackpotButtonStyle(.primary) }

    static func jackpot(_ prominence: JackpotButtonStyle.Prominence) -> JackpotButtonStyle {
        JackpotButtonStyle(prominence)
    }
}
```

**7.** `JackpotKit/Sources/JackpotUI/Styles/JackpotToggleStyle.swift`

```swift
import SwiftUI

public struct JackpotToggleStyle: ToggleStyle {
    public enum Appearance: Hashable, Sendable {
        case checkbox
    }

    private let appearance: Appearance

    public init(_ appearance: Appearance = .checkbox) {
        self.appearance = appearance
    }

    public func makeBody(configuration: Configuration) -> some View {
        ToggleBody(appearance: appearance, configuration: configuration)
    }

    private struct ToggleBody: View {
        let appearance: Appearance
        let configuration: ToggleStyleConfiguration

        @Environment(\.jackpotTheme) private var theme
        @Environment(\.jackpotValidationMessage) private var validationMessage

        var body: some View {
            switch appearance {
            case .checkbox: checkbox
            }
        }

        private var checkbox: some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack(alignment: .top, spacing: theme.metrics.spacing) {
                    Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(boxColor)
                        .frame(width: 24, height: 24)
                        .animation(.easeOut(duration: 0.15), value: configuration.isOn)
                    configuration.label
                        .jackpotTextStyle(\.rowLabel)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: theme.metrics.minimumHitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation {
                // The explicit style stops the stand-in resolving back to this one.
                Toggle(isOn: configuration.$isOn) { configuration.label }
                    .toggleStyle(.switch)
            }
        }

        private var boxColor: Color {
            if configuration.isOn { return theme.colors.accent }
            return validationMessage == nil ? theme.colors.textSecondary : theme.colors.fieldBorderInvalid
        }
    }
}

public extension ToggleStyle where Self == JackpotToggleStyle {
    static var jackpotCheckbox: JackpotToggleStyle { JackpotToggleStyle(.checkbox) }
}
```

**8.** `JackpotKit/Sources/JackpotUI/Styles/JackpotProgressViewStyle.swift`

```swift
import SwiftUI

public struct JackpotBarProgressViewStyle: ProgressViewStyle {
    private let height: CGFloat?

    public init(height: CGFloat? = nil) {
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        BarBody(height: height, fraction: configuration.fractionCompleted ?? 0)
    }

    private struct BarBody: View {
        let height: CGFloat?
        let fraction: Double

        @Environment(\.jackpotTheme) private var theme

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.colors.fieldBorder)
                    Capsule()
                        .fill(.tint)
                        .frame(width: proxy.size.width * fraction.clampedToUnitInterval)
                }
            }
            .frame(height: height ?? theme.metrics.progressBarHeight)
            .animation(.easeOut(duration: 0.25), value: fraction)
        }
    }
}

public extension ProgressViewStyle where Self == JackpotBarProgressViewStyle {
    static var jackpotBar: JackpotBarProgressViewStyle { JackpotBarProgressViewStyle() }

    static func jackpotBar(height: CGFloat) -> JackpotBarProgressViewStyle {
        JackpotBarProgressViewStyle(height: height)
    }
}

private extension Double {
    var clampedToUnitInterval: Double { min(max(self, 0), 1) }
}
```

**9.** `JackpotKit/Sources/JackpotUI/Fields/JackpotFieldChrome.swift`

The shared field background and the label/error row every field sits in.

```swift
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
            .jackpotBackground(\.fieldBackground, in: theme.metrics.fieldShape)
            .overlay {
                theme.metrics.fieldShape
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
        emphasis == .none ? theme.metrics.borderWidth : theme.metrics.emphasizedBorderWidth
    }
}

public extension View {
    func jackpotFieldBackground(isFocused: Bool = false) -> some View {
        modifier(JackpotFieldBackground(isFocused: isFocused))
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
        VStack(alignment: .leading, spacing: 6) {
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

public extension View {
    func jackpotLabeled(_ label: String? = nil, error: String? = nil) -> some View {
        JackpotLabeledField(label, error: error) { self }
    }
}
```

**10.** `JackpotKit/Sources/JackpotUI/Fields/JackpotFieldKind.swift`

One value per input type the registration schema asks for, applied to a field with `jackpotField(_:)`.

```swift
import SwiftUI

/// `TextInputAutocapitalization` is neither `Equatable` nor inspectable, so the kind stores
/// its own case and converts when applying.
public enum JackpotCapitalization: Equatable, Sendable {
    case never, words, sentences, characters

    var textInput: TextInputAutocapitalization {
        switch self {
        case .never:      return .never
        case .words:      return .words
        case .sentences:  return .sentences
        case .characters: return .characters
        }
    }
}

public struct JackpotFieldKind: Equatable, Sendable {
    public var keyboard: UIKeyboardType = .default
    public var contentType: UITextContentType?
    public var capitalization: JackpotCapitalization = .sentences
    public var disablesAutocorrection = false
    public var isSecure = false

    public static let text = JackpotFieldKind()

    public static let givenName = JackpotFieldKind(contentType: .givenName,
                                                   capitalization: .words,
                                                   disablesAutocorrection: true)

    public static let familyName = JackpotFieldKind(contentType: .familyName,
                                                    capitalization: .words,
                                                    disablesAutocorrection: true)

    public static let email = JackpotFieldKind(keyboard: .emailAddress,
                                               contentType: .emailAddress,
                                               capitalization: .never,
                                               disablesAutocorrection: true)

    public static let phoneNumber = JackpotFieldKind(keyboard: .phonePad,
                                                    contentType: .telephoneNumber,
                                                    capitalization: .never,
                                                    disablesAutocorrection: true)

    public static let newPassword = JackpotFieldKind(contentType: .newPassword,
                                                     capitalization: .never,
                                                     disablesAutocorrection: true,
                                                     isSecure: true)

    public static let number = JackpotFieldKind(keyboard: .numberPad,
                                                capitalization: .never,
                                                disablesAutocorrection: true)

    public func with(_ transform: (inout JackpotFieldKind) -> Void) -> JackpotFieldKind {
        var copy = self
        transform(&copy)
        return copy
    }
}

public extension View {
    func jackpotField(_ kind: JackpotFieldKind) -> some View {
        modifier(JackpotFieldKindModifier(kind: kind))
    }
}

private struct JackpotFieldKindModifier: ViewModifier {
    let kind: JackpotFieldKind

    func body(content: Content) -> some View {
        content
            .keyboardType(kind.keyboard)
            .textContentType(kind.contentType)
            .textInputAutocapitalization(kind.capitalization.textInput)
            .autocorrectionDisabled(kind.disablesAutocorrection)
            .jackpotSecureEntry(kind.isSecure)
    }
}
```

**11.** `JackpotKit/Sources/JackpotUI/Fields/JackpotTextField.swift`

```swift
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
```

**12.** `JackpotKit/Sources/JackpotUI/Fields/JackpotDropdown.swift`

```swift
import SwiftUI

public struct JackpotOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct JackpotDropdown: View {
    @Binding private var selection: String?
    private let placeholder: String
    private let options: [JackpotOption]

    @Environment(\.jackpotTheme) private var theme

    public init(_ placeholder: String, selection: Binding<String?>, options: [JackpotOption]) {
        self.placeholder = placeholder
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.id
                } label: {
                    if option.id == selection {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack {
                Text(selected?.label ?? placeholder)
                    .jackpotForegroundStyle(valueColor)
                Spacer()
                Image(systemName: "chevron.down").jackpotForegroundStyle(\.textPrimary)
            }
            .jackpotFont(\.fieldText)
            .padding(.horizontal, theme.metrics.contentPadding)
            .frame(height: theme.metrics.controlHeight)
            .jackpotFieldBackground()
        }
        .accessibilityLabel(placeholder)
        .accessibilityValue(selected?.label ?? "None")
    }

    private var selected: JackpotOption? {
        options.first { $0.id == selection }
    }

    private var valueColor: KeyPath<JackpotColors, Color> {
        selected == nil ? \.textSecondary : \.textPrimary
    }
}
```

**13.** `JackpotKit/Sources/JackpotUI/Fields/JackpotDateField.swift`

The Calender input type: a read-only field that presents a graphical picker in a sheet.

```swift
import SwiftUI

public struct JackpotDateField: View {
    @Binding private var selection: Date?
    private let placeholder: String
    private let range: PartialRangeThrough<Date>

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.jackpotFieldLabel) private var fieldLabel
    @State private var isPresented = false

    public init(_ placeholder: String,
                selection: Binding<Date?>,
                in range: PartialRangeThrough<Date> = ...Date()) {
        self.placeholder = placeholder
        self._selection = selection
        self.range = range
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(displayedValue)
                    .jackpotForegroundStyle(valueColor)
                Spacer()
                Image(systemName: "calendar").jackpotForegroundStyle(\.textPrimary)
            }
            .jackpotFont(\.fieldText)
            .padding(.horizontal, theme.metrics.contentPadding)
            .frame(height: theme.metrics.controlHeight)
            .jackpotFieldBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fieldLabel ?? placeholder)
        .accessibilityValue(selection == nil ? "None" : displayedValue)
        .sheet(isPresented: $isPresented) {
            if #available(iOS 16.0, *) {
                sheet
                    .presentationDetents([.height(sheetHeight)])
                    .presentationDragIndicator(.visible)
            } else {
                sheet
            }
        }
    }

    /// Wheel plus title and button. Before iOS 16 there are no detents, so the sheet is full
    /// height and the spacer pins the button to the bottom instead.
    private var sheetHeight: CGFloat { wheelHeight + 160 }

    private var wheelHeight: CGFloat { 216 }

    private var sheet: some View {
        ZStack {
            theme.colors.surface.ignoresSafeArea()

            VStack(spacing: theme.metrics.spacing) {
                Text(fieldLabel ?? placeholder)
                    .jackpotTextStyle(\.button)
                    .padding(.top, 20)

                DatePicker("",
                           selection: Binding(get: { selection ?? range.upperBound },
                                              set: { selection = $0 }),
                           in: range,
                           displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: wheelHeight)
                    .padding(.horizontal)

                Spacer(minLength: 0)

                Button("Done") {
                    // Confirming without dragging still counts as a choice, otherwise the
                    // field silently stays empty.
                    if selection == nil { selection = range.upperBound }
                    isPresented = false
                }
                .buttonStyle(.jackpot)
                .padding([.horizontal, .bottom], 16)
            }
        }
    }

    private var displayedValue: String {
        guard let selection else { return placeholder }
        return selection.formatted(date: .abbreviated, time: .omitted)
    }

    private var valueColor: KeyPath<JackpotColors, Color> {
        selection == nil ? \.textSecondary : \.textPrimary
    }
}
```

**14.** `JackpotKit/Sources/JackpotUI/Components/JackpotChecklist.swift`

The live password-rules panel.

```swift
import SwiftUI

public struct JackpotChecklistItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let isSatisfied: Bool

    public init(id: String, text: String, isSatisfied: Bool) {
        self.id = id
        self.text = text
        self.isSatisfied = isSatisfied
    }
}

public struct JackpotChecklist: View {
    private let title: String
    private let section: String
    private let items: [JackpotChecklistItem]

    @Environment(\.jackpotTheme) private var theme
    @State private var isExpanded = true

    public init(_ title: String, section: String = "Required", items: [JackpotChecklistItem]) {
        self.title = title
        self.section = section
        self.items = items
    }

    public var body: some View {
        if !items.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: satisfiedFraction)
                        .progressViewStyle(.jackpotBar(height: 6))
                        .tint(satisfiedFraction < 1 ? theme.colors.warning : theme.colors.success)
                        .accessibilityLabel("Requirements met")

                    Text(section).jackpotTextStyle(\.sectionTitle)

                    ForEach(items) { item in
                        row(for: item)
                    }
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(title).jackpotTextStyle(\.sectionTitle)
            }
            // The chevron follows the tint, which the theme points at the accent colour.
            .tint(theme.colors.textPrimary)
            .padding(theme.metrics.contentPadding)
            .jackpotBackground(\.fieldBackground, in: theme.metrics.fieldShape)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: isExpanded)
        }
    }

    private func row(for item: JackpotChecklistItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isSatisfied ? theme.colors.accent : theme.colors.textSecondary)
                .animation(.easeOut(duration: 0.15), value: item.isSatisfied)
            Text(item.text).jackpotTextStyle(\.rowLabel)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isSatisfied ? "Met" : "Not met")
    }

    private var satisfiedFraction: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isSatisfied).count) / Double(items.count)
    }
}
```

**15.** `JackpotKit/Sources/JackpotUI/Components/JackpotErrorView.swift`

Shown when the form fails to load.

```swift
import SwiftUI

public struct JackpotErrorView: View {
    private let message: String
    private let title: String
    private var retryAction: (() -> Void)?

    public init(_ message: String, title: String = "Something went wrong") {
        self.message = message
        self.title = title
    }

    /// Adds the retry button. Without it the view is message-only.
    public func onRetry(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.retryAction = action
        return copy
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .jackpotForegroundStyle(\.textSecondary)
                .accessibilityHidden(true)

            Text(title).jackpotTextStyle(\.button)

            Text(message)
                .jackpotTextStyle(\.label, color: \.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let retryAction {
                Button("Retry", action: retryAction)
                    .buttonStyle(.jackpot)
                    .frame(width: 160)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
```

**16.** `JackpotKit/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift`

The panel wraps a preview in the themed surface; the gallery below is how you check the components
without running the app.

```swift
#if DEBUG
import SwiftUI

public struct JackpotPreviewPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.caption).jackpotForegroundStyle(\.textSecondary)
            }
            content
        }
        .padding(16)
        .frame(width: 390)
        .jackpotTheme(.jackpotCity)
        .jackpotBackground(\.surface)
    }
}

// MARK: - Component gallery

struct JackpotUI_Previews: PreviewProvider {
    struct Harness: View {
        @State private var mobile = ""
        @State private var email = ""
        @State private var secret = "Passwo1"
        @State private var touched = false
        @State private var promotions = false
        @State private var agreed = true
        @State private var income: String? = nil
        @State private var dateOfBirth: Date? = nil

        var body: some View {
            ScrollView {
                JackpotPreviewPanel("Gallery") {
                    JackpotLabeledField("Mobile") {
                        JackpotTextField("Enter Mobile Number", text: $mobile)
                            .onEditingEnded { touched = true }
                            .jackpotField(.phoneNumber)
                            .jackpotFieldPrefix("+27")
                    }

                    JackpotLabeledField("Email") {
                        JackpotTextField("Enter Email Address", text: $email)
                            .jackpotField(.email)
                    }

                    JackpotLabeledField(error: "Password must be 8–20 characters") {
                        JackpotTextField("Password", text: $secret)
                            .jackpotField(.newPassword)
                    }

                    JackpotChecklist("Password Validity", items: [
                        .init(id: "min", text: "Minimum of 8 characters", isSatisfied: false),
                        .init(id: "max", text: "Maximum of 20 characters", isSatisfied: true),
                    ])

                    JackpotLabeledField("Source Of Income", error: "Please choose one") {
                        JackpotDropdown("Enter Source Of Income", selection: $income, options: [
                            .init(id: "salary", label: "Salary or Wages"),
                            .init(id: "pension", label: "Pension or Grant"),
                        ])
                    }

                    JackpotLabeledField("Date Of Birth") {
                        JackpotDateField("Enter Date Of Birth", selection: $dateOfBirth)
                    }

                    Toggle("Send Jackpot City Promotions to me", isOn: $promotions)
                        .toggleStyle(.jackpotCheckbox)
                    Toggle("I am over 18 years of age & I accept the Terms & Conditions", isOn: $agreed)
                        .toggleStyle(.jackpotCheckbox)

                    ProgressView(value: 0.45).progressViewStyle(.jackpotBar)

                    Button("Next") {}.buttonStyle(.jackpot).disabled(true)
                    Button("Sign Up") {}.buttonStyle(.jackpot).jackpotLoading()
                    Button("Previous") {}.buttonStyle(.jackpot(.secondary))
                    Button("Skip for now") {}.buttonStyle(.jackpot(.tertiary))
                }
            }
            .jackpotTheme(.jackpotCity)
            .jackpotBackground(\.surface)
        }
    }

    static var previews: some View {
        Group {
            Harness().preferredColorScheme(.dark).previewDisplayName("Gallery — dark")
            Harness().preferredColorScheme(.light).previewDisplayName("Gallery — light")
            JackpotPreviewPanel("Error") {
                JackpotErrorView("The network connection was lost.").onRetry {}
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Error — dark")
            JackpotPreviewPanel("Error") {
                JackpotErrorView("The network connection was lost.").onRetry {}
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Error — light")
            Harness()
                .environment(\.sizeCategory, .accessibilityLarge)
                .previewDisplayName("Gallery — XL text")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**17.** `JackpotKit/Tests/JackpotUITests/JackpotThemeTests.swift`

```swift
import SwiftUI
import XCTest
@testable import JackpotUI

final class JackpotThemeTests: XCTestCase {
    func testBrandThemeComposesTheStandardPresets() {
        XCTAssertEqual(JackpotTheme.jackpotCity.colors, .jackpotCity)
        XCTAssertEqual(JackpotTheme.jackpotCity.metrics, .standard)
        XCTAssertEqual(JackpotTheme.jackpotCity.typography, .standard)
    }

    func testWithReturnsACopyAndLeavesTheOriginalAlone() {
        let brand = JackpotTheme.jackpotCity
        let roomy = brand.with { $0.metrics.cornerRadius = 24 }

        XCTAssertEqual(roomy.metrics.cornerRadius, 24)
        XCTAssertEqual(brand.metrics.cornerRadius, 10)
        XCTAssertEqual(roomy.colors, brand.colors, "An unrelated slice should carry over untouched")
    }

    func testFieldShapeFollowsCornerRadius() {
        let theme = JackpotTheme.jackpotCity.with { $0.metrics.cornerRadius = 4 }
        XCTAssertEqual(theme.metrics.fieldShape.cornerSize, CGSize(width: 4, height: 4))
        XCTAssertEqual(theme.metrics.fieldShape.style, .continuous)
    }
}

final class JackpotColorSchemeTests: XCTestCase {
    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    func testSurfaceAndTextInvertBetweenAppearances() {
        let colors = JackpotColors.jackpotCity
        for keyPath in [\JackpotColors.surface, \.fieldBackground, \.textPrimary, \.textSecondary] {
            let color = UIColor(colors[keyPath: keyPath])
            XCTAssertNotEqual(color.resolvedColor(with: light),
                              color.resolvedColor(with: dark),
                              "\(keyPath) should differ per appearance")
        }
    }

    func testTextOnAccentDoesNotInvert() {
        let color = UIColor(JackpotColors.jackpotCity.textOnAccent)
        XCTAssertEqual(color.resolvedColor(with: light), color.resolvedColor(with: dark))
    }

    func testBodyTextClearsWCAGContrastInBothAppearances() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let text = UIColor(colors.textPrimary).resolvedColor(with: traits)
            let background = UIColor(colors.surface).resolvedColor(with: traits)
            XCTAssertGreaterThan(contrastRatio(text, background), 4.5,
                                 "textPrimary on surface, \(traits.userInterfaceStyle.rawValue)")

            let secondary = UIColor(colors.textSecondary).resolvedColor(with: traits)
            XCTAssertGreaterThan(contrastRatio(secondary, background), 4.5,
                                 "textSecondary on surface, \(traits.userInterfaceStyle.rawValue)")
        }
    }

    /// WCAG 2.1 relative luminance.
    private func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let lighter = max(luminance(a), luminance(b))
        let darker = min(luminance(a), luminance(b))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}

final class JackpotFieldKindTests: XCTestCase {
    func testEmailOptsOutOfCapitalisationAndAutocorrection() {
        XCTAssertEqual(JackpotFieldKind.email.keyboard, .emailAddress)
        XCTAssertEqual(JackpotFieldKind.email.contentType, .emailAddress)
        XCTAssertTrue(JackpotFieldKind.email.disablesAutocorrection)
        XCTAssertFalse(JackpotFieldKind.email.isSecure)
    }

    func testPasswordKindsAreSecure() {
        XCTAssertTrue(JackpotFieldKind.newPassword.isSecure)
        XCTAssertEqual(JackpotFieldKind.newPassword.contentType, .newPassword)
    }

    func testWithOverridesASingleTrait() {
        let kind = JackpotFieldKind.text.with { $0.capitalization = .words }
        XCTAssertEqual(kind.capitalization, .words)
        XCTAssertEqual(kind.keyboard, JackpotFieldKind.text.keyboard)
    }
}

final class JackpotOptionTests: XCTestCase {
    func testOptionsAreIdentifiedByTheirStoredValue() {
        let option = JackpotOption(id: "SalaryOrWages", label: "Salary or Wages")
        XCTAssertEqual(option.id, "SalaryOrWages")
    }

    func testChecklistItemEquatable() {
        let a = JackpotChecklistItem(id: "min", text: "Minimum of 8", isSatisfied: false)
        XCTAssertEqual(a, JackpotChecklistItem(id: "min", text: "Minimum of 8", isSatisfied: false))
        XCTAssertNotEqual(a, JackpotChecklistItem(id: "min", text: "Minimum of 8", isSatisfied: true))
    }
}
```

**18.**

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotUI

`Executed 11 tests, with 0 failures`

Open `JackpotPreviewPanel.swift` and resume the **Gallery** preview.

---

## PR 2 — JackpotForms

**19.**

```bash
mkdir -p JackpotKit/Sources/{JackpotFormsDomain,JackpotFormsData}
mkdir -p JackpotKit/Sources/JackpotFormsUI/{Fields,Demo,Resources}
mkdir -p JackpotKit/Tests/JackpotFormsTests/Fixtures
```

**20.** `JackpotKit/Package.swift`

```swift
        .target(name: "JackpotFormsDomain"),
        .target(name: "JackpotFormsData", dependencies: ["JackpotFormsDomain"]),
        .target(
            name: "JackpotFormsUI",
            dependencies: ["JackpotFormsDomain", "JackpotUI"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "JackpotFormsTests",
            dependencies: ["JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI"],
            resources: [.process("Fixtures")]
        ),
```

These append to the `targets:` array of the manifest PR 1 created — three more modules in the
same package, not a package of their own.

**21.** `JackpotKit/Sources/JackpotFormsDomain/FormName.swift`

```swift
import Foundation

/// Identifies a form in the CRM — the `formCodeName` in the schema, and the last path
/// component of the fetch URL.
///
/// Deliberately **not** an enum. Forms are authored server-side and new ones appear
/// without an app release, so a closed set would fight the architecture: the moment the
/// CRM serves `deposit`, a `switch` somewhere would stop compiling or a new form would be
/// unreachable until the next submission to the App Store.
///
/// Instead this is the `Notification.Name` pattern — a `RawRepresentable` wrapper with
/// static members for the forms this build knows about:
///
///     DynamicFormView(formName: .registration) { ... }     // autocompleted, typo-proof
///     DynamicFormView(formName: FormName("deposit")) { ... } // server-authored, still fine
///
/// Note it is **not** `ExpressibleByStringLiteral`. If it were, `formName: "registraton"`
/// would still compile and you'd be back to a runtime 404 — which is the whole problem this
/// type exists to remove. Constructing one from an arbitrary string is possible but has to be
/// written out, so `FormName(` is greppable at review time.
public struct FormName: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Shorthand for the static members below and for server-authored names.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

// MARK: - Known forms
//
// Add a case here when the CRM starts serving a form you reference by name in code.
// Forms you only ever reach dynamically (from a sitemap, a deep link, the forms list
// endpoint) never need an entry — construct them with `FormName(_:)`.

public extension FormName {
    /// The two-section sign-up form: credentials + name + email, then FICA.
    static let registration = FormName("registration")

    /// Development-only schema exercising every supported field type.
    static let kitchenSink = FormName("kitchenSink")

    /// Forms bundled with the package as JSON, for mocks, previews and the sandbox.
    static let bundled: [FormName] = [.registration, .kitchenSink]
}
```

**22.** `JackpotKit/Sources/JackpotFormsDomain/FormValue.swift`

```swift
import Foundation

/// A field's current value.
///
/// Every case can render itself as a string because the schema validates with
/// regexes — including the checkboxes, whose patterns are literally `^true$`.
/// `stringValue` is therefore both what gets validated and what gets submitted.
public enum FormValue: Equatable, Hashable, Sendable {
    case empty
    case text(String)
    case bool(Bool)
    case option(String)
    case date(Date)

    public var stringValue: String {
        switch self {
        case .empty:            return ""
        case .text(let s):      return s
        case .bool(let b):      return b ? "true" : "false"
        case .option(let v):    return v
        case .date(let d):      return FormValue.iso8601.string(from: d)
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .empty:         return true
        case .text(let s):   return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .option(let v): return v.isEmpty
        // An unticked required checkbox is "empty" for the purposes of the required
        // check — which is what makes `terms` behave correctly.
        case .bool(let b):   return !b
        case .date:          return false
        }
    }

    public var boolValue: Bool {
        if case .bool(let b) = self { return b }
        return stringValue.lowercased() == "true"
    }

    public var dateValue: Date? {
        switch self {
        case .date(let d): return d
        case .text(let s): return FormValue.iso8601.date(from: s)
        default:           return nil
        }
    }

    /// The `dateOfBirth` regex in the schema expects an ISO-8601 date-time with
    /// optional fractional seconds and offset, so that is what we emit.
    public static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

/// What the host receives in the submit callback: values keyed by `fieldIdentifier`.
public struct FormSubmission: Equatable, Sendable {
    public let formCodeName: FormName
    public let values: [String: FormValue]

    public init(formCodeName: FormName, values: [String: FormValue]) {
        self.formCodeName = formCodeName
        self.values = values
    }

    public subscript(identifier: String) -> FormValue {
        values[identifier] ?? .empty
    }

    /// Flat string payload, ready to become a JSON body.
    public var stringValues: [String: String] {
        values.mapValues(\.stringValue)
    }
}
```

**23.** `JackpotKit/Sources/JackpotFormsDomain/FormField.swift`

```swift
import Foundation

/// What component renders this field.
///
/// `unknown` is load-bearing, not defensive padding: the form schema is served from
/// a CRM that product edits without shipping an app build. If an unrecognised
/// `fieldType` threw, one CRM edit would brick registration for every installed
/// version. Unknown fields are skipped and reported instead — see
/// `DynamicFormModel.unsupportedFields`.
public enum FieldType: Equatable, Hashable, Sendable {
    case input
    case button
    case checkbox
    case radio
    case radioGroup
    case dropdown
    case divider
    case textArea
    case recaptchaV2
    case recaptchaV3
    case toggle
    case welcomeOffer
    case unknown(String)

    public init(raw: String) {
        switch raw.lowercased().replacingOccurrences(of: " ", with: "") {
        case "input":                    self = .input
        case "button":                   self = .button
        case "checkbox":                 self = .checkbox
        case "radio":                    self = .radio
        case "radiogroup":               self = .radioGroup
        case "dropdown", "select":       self = .dropdown
        case "divider":                  self = .divider
        case "textarea":                 self = .textArea
        case "recapchav2", "recaptchav2": self = .recaptchaV2
        case "recapchav3", "recaptchav3": self = .recaptchaV3
        case "toggle":                   self = .toggle
        case "welcomeoffer":             self = .welcomeOffer
        default:                         self = .unknown(raw)
        }
    }

    /// Layout-only types hold no value and are never validated or submitted.
    public var isDecorative: Bool {
        switch self {
        case .divider, .button: return true
        default:                return false
        }
    }
}

/// Keyboard and formatting hint for `.input`.
public enum InputType: Equatable, Hashable, Sendable {
    case text
    case number
    case password
    case email
    case calendar
    case phone
    case unknown(String)

    public init(raw: String) {
        switch raw.lowercased() {
        case "text":                  self = .text
        case "number", "numeric":     self = .number
        case "password":              self = .password
        case "email":                 self = .email
        // The schema spells this "Calender". Accept both so a server-side fix
        // doesn't silently turn every date field into a plain text box.
        case "calender", "calendar", "date": self = .calendar
        case "phone", "tel":          self = .phone
        default:                      self = .unknown(raw)
        }
    }
}

public struct DropdownOption: Identifiable, Equatable, Hashable, Sendable {
    /// Submitted value, e.g. "SalaryOrWages".
    public let value: String
    /// Localization key for the visible text, e.g. "jpc-reg-SalaryOrWages".
    public let textKey: String
    /// Either a regex pattern or the *name* of one — see `RegexResolving`.
    public let regex: String?

    public var id: String { value }

    public init(value: String, textKey: String, regex: String?) {
        self.value = value
        self.textKey = textKey
        self.regex = regex
    }
}

public struct RadioOption: Identifiable, Equatable, Hashable, Sendable {
    public let value: String
    public let textKey: String

    public var id: String { value }

    public init(value: String, textKey: String) {
        self.value = value
        self.textKey = textKey
    }
}

public struct FormField: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    /// Key used for state, validation and the submitted payload. e.g. "idNumber".
    public let identifier: String
    public let name: String
    /// Localization key for the label.
    public let labelKey: String
    public let type: FieldType
    public let inputType: InputType
    public let textStyle: String
    /// Localization key for the validation failure message.
    public let validationMessageKey: String
    public let isRequired: Bool
    public let isVisible: Bool
    public let isReadOnly: Bool
    /// Regex the value must match. Server-supplied, so it may be invalid — see `FieldValidator`.
    public let regex: String?
    public let prefix: String
    public let suffix: String
    /// Localization key for the placeholder.
    public let placeholderKey: String
    public let dropdownOptions: [DropdownOption]
    public let radioOptions: [RadioOption]

    public init(id: Int, identifier: String, name: String, labelKey: String,
                type: FieldType, inputType: InputType, textStyle: String,
                validationMessageKey: String, isRequired: Bool, isVisible: Bool, isReadOnly: Bool,
                regex: String?, prefix: String, suffix: String, placeholderKey: String,
                dropdownOptions: [DropdownOption], radioOptions: [RadioOption]) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.labelKey = labelKey
        self.type = type
        self.inputType = inputType
        self.textStyle = textStyle
        self.validationMessageKey = validationMessageKey
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isReadOnly = isReadOnly
        self.regex = regex
        self.prefix = prefix
        self.suffix = suffix
        self.placeholderKey = placeholderKey
        self.dropdownOptions = dropdownOptions
        self.radioOptions = radioOptions
    }

    /// Fields that hold a value: rendered, validated and submitted.
    public var carriesValue: Bool {
        isVisible && !type.isDecorative && !(type == .recaptchaV2 || type == .recaptchaV3)
    }

    public var isSecure: Bool { inputType == .password }
}
```

**24.** `JackpotKit/Sources/JackpotFormsDomain/Form.swift`

```swift
import Foundation

/// A whole form as the CRM form-builder describes it.
///
/// Structure, per the ticket:
///   • Sections are responsible for paging  (section == one page of the wizard)
///   • Rows determine the row for inline elements  (fields sharing a row sit side by side)
///   • Fields belong to rows
public struct FormSchema: Identifiable, Equatable, Sendable {
    public let id: Int
    public let codeName: FormName
    public let title: String
    public let subTitle: String
    public let regionCode: String
    public let sections: [FormSection]

    public init(id: Int, codeName: FormName, title: String, subTitle: String,
                regionCode: String, sections: [FormSection]) {
        self.id = id
        self.codeName = codeName
        self.title = title
        self.subTitle = subTitle
        self.regionCode = regionCode
        self.sections = sections
    }

    /// Every visible field, in render order, across all sections.
    public var allFields: [FormField] {
        sections.flatMap(\.fields)
    }

    public func field(identifiedBy identifier: String) -> FormField? {
        allFields.first { $0.identifier == identifier }
    }
}

public struct FormSection: Identifiable, Equatable, Sendable {
    public let id: Int
    public let codeName: String
    public let title: String
    public let subTitle: String
    public let order: Int
    public let rows: [FormRow]

    public init(id: Int, codeName: String, title: String, subTitle: String, order: Int, rows: [FormRow]) {
        self.id = id
        self.codeName = codeName
        self.title = title
        self.subTitle = subTitle
        self.order = order
        self.rows = rows
    }

    public var fields: [FormField] { rows.flatMap(\.fields) }
}

public struct FormRow: Identifiable, Equatable, Sendable {
    public let number: Int
    public let fields: [FormField]

    public var id: Int { number }

    public init(number: Int, fields: [FormField]) {
        self.number = number
        self.fields = fields
    }
}
```

**25.** `JackpotKit/Sources/JackpotFormsDomain/PasswordPolicy.swift`

```swift
import Foundation

/// One rule shown in the "Password Validity" panel.
public struct PasswordRule: Identifiable, Equatable, Sendable {
    public let id: String
    /// Localization key, with a plain-English fallback baked in for the demo.
    public let descriptionKey: String
    public let fallbackDescription: String
    private let test: @Sendable (String) -> Bool

    public init(id: String, descriptionKey: String, fallbackDescription: String,
                test: @escaping @Sendable (String) -> Bool) {
        self.id = id
        self.descriptionKey = descriptionKey
        self.fallbackDescription = fallbackDescription
        self.test = test
    }

    public func isSatisfied(by password: String) -> Bool { test(password) }

    public static func == (lhs: PasswordRule, rhs: PasswordRule) -> Bool { lhs.id == rhs.id }
}

/// Supplies the checklist behind the password field.
///
/// ⚠️ OPEN QUESTION: the schema gives password a single regex, `^(.){8,20}$`, but the
/// web UI shows two separate rules ("Minimum of 8 characters", "Maximum of 20
/// characters") with independent tick states and a strength bar. Those cannot both come
/// from one regex match. Either web parses the quantifier out of the pattern, or it has
/// its own rules config. The default below parses the `{min,max}` quantifier, which
/// reproduces the screenshots exactly for this form — but confirm with the web team.
public protocol PasswordPolicyProviding: Sendable {
    func rules(for field: FormField) -> [PasswordRule]
}

public struct PasswordPolicy: PasswordPolicyProviding {
    public init() {}

    public func rules(for field: FormField) -> [PasswordRule] {
        let bounds = Self.lengthBounds(in: field.regex)
        var rules: [PasswordRule] = []

        if let minimum = bounds.min {
            rules.append(PasswordRule(
                id: "min",
                descriptionKey: "jpc-reg-password-min",
                fallbackDescription: "Minimum of \(minimum) characters",
                test: { $0.count >= minimum }
            ))
        }
        if let maximum = bounds.max {
            rules.append(PasswordRule(
                id: "max",
                descriptionKey: "jpc-reg-password-max",
                fallbackDescription: "Maximum of \(maximum) characters",
                test: { !$0.isEmpty && $0.count <= maximum }
            ))
        }
        return rules
    }

    /// Pulls `{8,20}` out of `^(.){8,20}$`.
    static func lengthBounds(in pattern: String?) -> (min: Int?, max: Int?) {
        guard let pattern,
              let expression = try? NSRegularExpression(pattern: #"\{(\d+),(\d+)\}"#),
              let match = expression.firstMatch(in: pattern, range: NSRange(pattern.startIndex..., in: pattern)),
              let minRange = Range(match.range(at: 1), in: pattern),
              let maxRange = Range(match.range(at: 2), in: pattern)
        else { return (nil, nil) }
        return (Int(pattern[minRange]), Int(pattern[maxRange]))
    }
}
```

**26.** `JackpotKit/Sources/JackpotFormsDomain/RegexResolving.swift`

```swift
import Foundation

/// Dropdown options in the schema carry a `regex` that is sometimes a pattern
/// (`"[a-zA-Z]"` on sourceOfFunds) and sometimes a *name* (`"idNumberRegex"`,
/// `"passportNumberRegex"` on idNumberType). A name has to resolve to a pattern
/// somewhere; this protocol is that somewhere.
///
/// ⚠️ OPEN QUESTION for the backend team — see the guide, "Open questions". Confirm
/// whether a named regex on an option is meant to (a) validate the option itself, or
/// (b) *replace* the regex of a dependent field. The registration UI strongly implies
/// (b): choosing "South African ID" vs "Passport" changes what a valid ID Number is,
/// and the ID Number field's own regex is `^[0-9]{13}$`, which is SA-ID-specific.
/// `DynamicFormModel` implements (b) behind `dependentRegexOverrides`; flip it off
/// with `FormDependencies.appliesOptionRegexToDependentField = false`.
public protocol RegexResolving: Sendable {
    /// Pattern for a named regex, or nil if the name is unknown.
    func pattern(named name: String) -> String?
}

public struct RegexCatalog: RegexResolving {
    private let patterns: [String: String]

    public init(patterns: [String: String]) {
        self.patterns = patterns
    }

    public func pattern(named name: String) -> String? {
        patterns[name]
    }

    /// ⚠️ **These patterns are invented.** The schema references `idNumberRegex` and
    /// `passportNumberRegex` by *name*; it never sends the patterns, and we haven't been told
    /// where they live. `idNumberRegex` is safe — it matches the `idNumber` field's own regex
    /// in the schema (`^[0-9]{13}$`), which is the SA ID format. **`passportNumberRegex` is a
    /// guess.**
    ///
    /// It is deliberately permissive. The two failure modes are not symmetric:
    ///
    /// - too strict → a real passport is rejected client-side and the user cannot register at
    ///   all, with no way to appeal;
    /// - too loose → the server rejects it and the user sees a message and retries.
    ///
    /// The server validates either way, so erring loose costs a round trip and erring strict
    /// costs a registration. Replace this the moment the real pattern is known — see
    /// `docs/OPEN-QUESTIONS.md` Q4b.
    public static let jpcDefaults = RegexCatalog(patterns: [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^[a-zA-Z0-9]{5,20}$",
    ])
}

public extension String {
    /// Tells a regex *pattern* from a regex *name*.
    ///
    /// The schema uses both in the same place: `idNumberType`'s options carry
    /// `"idNumberRegex"` (a name, which redirects to another field's rule) while
    /// `sourceOfFunds`'s carry `"[a-zA-Z]"` (a literal pattern describing the selection
    /// itself). A bare identifier has no metacharacters; a real pattern almost always does.
    var looksLikeRegexPattern: Bool {
        let metacharacters = CharacterSet(charactersIn: "^$[]{}()|*+?\\.")
        return rangeOfCharacter(from: metacharacters) != nil
    }
}
```

**27.** `JackpotKit/Sources/JackpotFormsDomain/FieldValidator.swift`

```swift
import Foundation

public enum ValidationResult: Equatable, Sendable {
    case valid
    /// Localization key for the message to show, plus the field it belongs to.
    case invalid(messageKey: String)

    public var isValid: Bool { self == .valid }
}

/// Validates a value against a field's schema rules.
///
/// Two things make this less trivial than it looks:
///  1. The regexes come from a server, so they can be malformed. `NSRegularExpression`
///     throws on a bad pattern — if that propagated, one CRM typo would crash signup.
///     A pattern that will not compile is treated as "no constraint", and reported.
///  2. Compiling a pattern on every keystroke, for every field, is wasteful. Compiled
///     expressions are cached by pattern string.
public struct FieldValidator: Sendable {
    private let regexResolver: any RegexResolving
    private let cache = RegexCache()

    public init(regexResolver: any RegexResolving = RegexCatalog.jpcDefaults) {
        self.regexResolver = regexResolver
    }

    /// - Parameter overrideRegex: pattern that replaces `field.regex`, used when a
    ///   dropdown selection changes a dependent field's rule (ID type → ID number).
    public func validate(_ value: FormValue,
                         against field: FormField,
                         overrideRegex: String? = nil) -> ValidationResult {
        guard field.carriesValue, !field.isReadOnly else { return .valid }

        if field.isRequired, value.isEmpty {
            return .invalid(messageKey: field.validationMessageKey)
        }

        // An empty optional field has nothing left to check. Note some schema regexes
        // permit empty explicitly (referralCode: `...|^$`), but not all do, so this
        // guard is what keeps optional fields genuinely optional.
        if !field.isRequired, value.isEmpty { return .valid }

        guard let pattern = resolvedPattern(overrideRegex ?? field.regex), !pattern.isEmpty else {
            return .valid
        }

        guard let expression = cache.expression(for: pattern) else {
            // Malformed server pattern: do not block the user on our inability to
            // compile it. Surfaced via `invalidPatterns` for diagnostics.
            return .valid
        }

        let subject = value.stringValue
        let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
        let matched = expression.firstMatch(in: subject, options: [], range: range) != nil
        return matched ? .valid : .invalid(messageKey: field.validationMessageKey)
    }

    /// Pattern for a dropdown option's `regex`, resolving names via the catalogue.
    public func optionPattern(_ raw: String?) -> String? {
        resolvedPattern(raw)
    }

    private func resolvedPattern(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if let named = regexResolver.pattern(named: raw) { return named }
        return raw.looksLikeRegexPattern ? raw : nil
    }

    /// Patterns in this form that will not compile — worth logging in debug.
    public func invalidPatterns(in form: FormSchema) -> [String] {
        form.allFields.compactMap { field in
            guard let pattern = resolvedPattern(field.regex), !pattern.isEmpty else { return nil }
            return cache.expression(for: pattern) == nil ? pattern : nil
        }
    }
}

/// Thread-safe compiled-regex cache.
private final class RegexCache: @unchecked Sendable {
    private var storage: [String: NSRegularExpression?] = [:]
    private let lock = NSLock()

    func expression(for pattern: String) -> NSRegularExpression? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = storage[pattern] { return cached }
        let compiled = try? NSRegularExpression(pattern: pattern)
        storage[pattern] = compiled
        return compiled
    }
}
```

**28.** `JackpotKit/Sources/JackpotFormsDomain/FormLoadError.swift`

```swift
import Foundation

/// Why a form couldn't be loaded, in terms the UI can render.
///
/// `JackpotFormsUI` depends on Domain only — never on `JackpotNetworking` — so `APIError` cannot reach
/// a view model. That's the layering working as intended, but it means the repository has to
/// translate at the boundary. Without this type the server's own wording ("Mobile number
/// already registered") gets decoded, carried all the way up, and then thrown away in favour
/// of a generic string.
///
/// `LocalizedError` because that's what `DynamicFormModel` reads.
public enum FormLoadError: LocalizedError, Equatable {
    case offline
    case notFound(FormName)
    /// The server explained itself. Prefer its wording over ours.
    case server(message: String)
    case unexpected

    public var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Check your connection and try again."
        case .notFound(let name):
            return "We couldn't find the \(name.rawValue) form. Please try again later."
        case .server(let message):
            return message
        case .unexpected:
            return "Something went wrong. Please try again."
        }
    }
}
```

**29.** `JackpotKit/Sources/JackpotFormsDomain/FormLocalizing.swift`

```swift
import Foundation

/// The schema ships localization *keys*, not display text: `fieldLabel` is "username",
/// dropdown text is "jpc-reg-idnumber", `validationMessage` is "regex". The rendered UI
/// shows "Enter Mobile Number", "South African ID", "Enter in a valid ID number", so a
/// string catalogue resolves them somewhere.
///
/// ⚠️ OPEN QUESTION: every field carries the *same* `validationMessage` value ("regex")
/// yet the UI shows per-field messages. The key is therefore almost certainly composed,
/// something like `jpc-reg-{fieldIdentifier}-{validationMessage}`. `ComposedKeyLocalizer`
/// implements that guess and is a one-line change once the backend confirms the format.
public protocol FormLocalizing: Sendable {
    func string(forKey key: String) -> String?

    /// Copy for a server error code, when the localisation table carries one.
    ///
    /// The app-data response contains entries keyed by error code — `6000328` maps to the
    /// max-OTP-tries message — so a numeric `code` in an API error envelope is a localisation
    /// key. Defaulted to nil so an implementation that has no such table (bundled placeholder
    /// copy, previews) doesn't have to care.
    func message(forErrorCode code: Int) -> String?
}

public extension FormLocalizing {
    func message(forErrorCode code: Int) -> String? { nil }

    /// Resolve, or fall back to a humanised version of the key so nothing renders blank.
    func display(_ key: String) -> String {
        string(forKey: key) ?? key.humanisedKey
    }

    func validationMessage(for field: FormField) -> String {
        let composed = "jpc-reg-\(field.identifier)-\(field.validationMessageKey)"
        if let resolved = string(forKey: composed) { return resolved }
        if let resolved = string(forKey: field.validationMessageKey) { return resolved }
        return "Please enter a valid \(field.identifier.humanisedKey.lowercased())"
    }
}

/// Looks up an in-memory table, then a bundle's `.strings`. Good enough for the demo
/// and for production once the table is fed from the CRM strings endpoint.
public struct ComposedKeyLocalizer: FormLocalizing {
    private let table: [String: String]
    private let bundle: Bundle?

    public init(table: [String: String] = [:], bundle: Bundle? = nil) {
        self.table = table
        self.bundle = bundle
    }

    public func string(forKey key: String) -> String? {
        if let value = table[key] { return value }
        guard let bundle else { return nil }
        let value = bundle.localizedString(forKey: key, value: "\u{0}", table: nil)
        return value == "\u{0}" ? nil : value
    }
}

public extension String {
    /// "jpc-reg-idnumber" → "Idnumber";  "firstname" → "Firstname";  "dateOfBirth" → "Date Of Birth"
    var humanisedKey: String {
        var working = self
        if let range = working.range(of: "jpc-reg-") { working.removeSubrange(range) }
        working = working.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")

        var spaced = ""
        for character in working {
            if character.isUppercase, !spaced.isEmpty, spaced.last != " " { spaced.append(" ") }
            spaced.append(character)
        }
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}

/// Wraps any `(key) -> String?` as a localizer.
///
/// This is how the app hands the form engine its *existing* `getTranslation` during the
/// migration, without either package knowing the other exists:
///
/// ```swift
/// ClosureLocalizer { key in
///     let value = getTranslation(Key: key)
///     return value == key ? nil : value      // getTranslation returns the key on a miss
/// }
/// ```
///
/// That last line matters. `FormLocalizing` uses `nil` to mean "unresolved" so the engine
/// can fall back to humanised copy; without mapping key-on-miss back to `nil`, a missing
/// string renders as the raw key ("username") instead of a readable label.
public struct ClosureLocalizer: FormLocalizing {
    private let resolve: @Sendable (String) -> String?
    private let resolveCode: @Sendable (Int) -> String?

    public init(_ resolve: @escaping @Sendable (String) -> String?,
                errorCode resolveCode: @escaping @Sendable (Int) -> String? = { _ in nil }) {
        self.resolve = resolve
        self.resolveCode = resolveCode
    }

    public func string(forKey key: String) -> String? { resolve(key) }
    public func message(forErrorCode code: Int) -> String? { resolveCode(code) }
}
```

**30.** `JackpotKit/Sources/JackpotFormsDomain/FormRepository.swift`

```swift
import Foundation

/// Fetches a form definition by name.
/// Implementation lives in JackpotFormsData; the UI only ever sees this.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
}
```

**31.** `JackpotKit/Sources/JackpotFormsData/FormDTO.swift`

```swift
import Foundation

// Wire shapes, exactly as the CRM form-builder sends them. Nothing outside this file
// knows about "formSectionCodeName" or the "Calender" spelling.
//
// Everything optional except the identifiers we cannot render without. The schema is
// edited by product in a CMS; a missing `prefix` must not fail the whole decode.

public struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let formTitle: String?
    let formSubTitle: String?
    let regionCode: String?
    let sections: [FormSectionDTO]?
}

public struct FormSectionDTO: Decodable {
    let formSectionId: Int
    let formSectionCodeName: String?
    let formSectionTitle: String?
    let formSectionSubTitle: String?
    let formSectionOrder: Int?
    let rows: [FormRowDTO]?
}

public struct FormRowDTO: Decodable {
    let rowNumber: Int
    let fields: [FormFieldDTO]?
}

public struct FormFieldDTO: Decodable {
    let fieldId: Int
    let fieldIdentifier: String
    let fieldName: String?
    let fieldLabel: String?
    let fieldType: String
    let inputType: String?
    let textStyle: String?
    let validationMessage: String?
    let isRequired: Bool?
    let isVisible: Bool?
    let isReadOnly: Bool?
    let fieldRegex: String?
    let prefix: String?
    let suffix: String?
    let fieldPlaceholder: String?
    let fieldDropdowns: [FieldDropdownDTO]?
    let fieldRadioGroup: [FieldRadioDTO]?
}

public struct FieldDropdownDTO: Decodable {
    let value: String
    let text: String?
    let regex: String?
}

public struct FieldRadioDTO: Decodable {
    let value: String
    let text: String?
}
```

**32.** `JackpotKit/Sources/JackpotFormsData/FormMapper.swift`

```swift
import Foundation
import JackpotFormsDomain

public enum FormMapper {
    public static func map(_ dto: FormDTO) -> FormSchema {
        FormSchema(
            id: dto.formId,
            codeName: FormName(dto.formCodeName),
            title: dto.formTitle ?? dto.formCodeName,
            subTitle: dto.formSubTitle ?? "",
            regionCode: dto.regionCode ?? "",
            sections: (dto.sections ?? [])
                .map(mapSection)
                .sorted { $0.order < $1.order }
        )
    }

    private static func mapSection(_ dto: FormSectionDTO) -> FormSection {
        FormSection(
            id: dto.formSectionId,
            codeName: dto.formSectionCodeName ?? "\(dto.formSectionId)",
            title: dto.formSectionTitle ?? "",
            subTitle: dto.formSectionSubTitle ?? "",
            order: dto.formSectionOrder ?? dto.formSectionId,
            rows: (dto.rows ?? [])
                .map(mapRow)
                .sorted { $0.number < $1.number }
        )
    }

    private static func mapRow(_ dto: FormRowDTO) -> FormRow {
        FormRow(number: dto.rowNumber, fields: (dto.fields ?? []).map(mapField))
    }

    private static func mapField(_ dto: FormFieldDTO) -> FormField {
        FormField(
            id: dto.fieldId,
            identifier: dto.fieldIdentifier,
            name: dto.fieldName ?? dto.fieldIdentifier,
            labelKey: dto.fieldLabel ?? dto.fieldIdentifier,
            type: FieldType(raw: dto.fieldType),
            inputType: InputType(raw: dto.inputType ?? "Text"),
            textStyle: dto.textStyle ?? "Regular",
            validationMessageKey: dto.validationMessage ?? "regex",
            // Defaults chosen to fail safe: an unspecified field is optional and
            // visible rather than silently blocking submission.
            isRequired: dto.isRequired ?? false,
            isVisible: dto.isVisible ?? true,
            isReadOnly: dto.isReadOnly ?? false,
            regex: dto.fieldRegex?.isEmpty == true ? nil : dto.fieldRegex,
            prefix: dto.prefix ?? "",
            suffix: dto.suffix ?? "",
            placeholderKey: dto.fieldPlaceholder ?? dto.fieldIdentifier,
            dropdownOptions: (dto.fieldDropdowns ?? []).map {
                DropdownOption(value: $0.value, textKey: $0.text ?? $0.value, regex: $0.regex)
            },
            radioOptions: (dto.fieldRadioGroup ?? []).map {
                RadioOption(value: $0.value, textKey: $0.text ?? $0.value)
            }
        )
    }
}
```

**33.** `JackpotKit/Sources/JackpotFormsData/StubFormRepository.swift`

```swift
import Foundation
import JackpotFormsDomain

/// Serves forms from bundled JSON. Backs the demo harness and previews, and lets the
/// whole feature be built and reviewed before the endpoint is reachable from the app.
public struct StubFormRepository: FormRepository {
    private let forms: [FormName: Data]
    /// Seconds. (`Duration` is iOS 16 — this package targets 15.)
    private let delay: TimeInterval
    private let error: (any Error)?

    public init(forms: [FormName: Data], delay: TimeInterval = 0.35, error: (any Error)? = nil) {
        self.forms = forms
        self.delay = delay
        self.error = error
    }

    public func form(named name: FormName) async throws -> FormSchema {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let error { throw error }
        guard let data = forms[name] else { throw FormLoadError.notFound(name) }
        return FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
    }

    /// Decodes raw JSON straight to a `form` — handy in tests and previews.
    public static func decode(_ data: Data) throws -> FormSchema {
        FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
    }
}
```

**34.** `JackpotKit/Sources/JackpotFormsUI/FormDependencies.swift`

```swift
import SwiftUI
import JackpotFormsDomain

/// Everything `DynamicFormView` needs that isn't the form name or the callback.
///
/// Passing this through the SwiftUI environment is what keeps the public call site at
/// the two arguments the ticket asks for:
///
///     DynamicFormView(formName: .registration) { submission in ... }
///
/// while still injecting every dependency explicitly at the composition root:
///
///     RootView().formDependencies(.live(repository: repo))
public struct FormDependencies {
    public var repository: any FormRepository
    public var validator: FieldValidator
    public var localizer: any FormLocalizing
    public var passwordPolicy: any PasswordPolicyProviding
    /// Whether a dropdown option's *named* regex overrides another field's rule.
    ///
    /// Confirmed behaviour: the ID Number Type dropdown selects whether the user is entering a
    /// South African ID or a passport, and the ID Number field must validate accordingly.
    public var appliesOptionRegexToDependentField: Bool

    /// Explicit "this dropdown drives this field's regex" links, keyed by field identifier.
    ///
    /// Without this the link is *positional* — the field immediately after the dropdown — which
    /// works for the current schema but breaks silently if the CRM reorders rows or inserts a
    /// field between them. On a regulated field (SA ID vs passport) silent breakage is the wrong
    /// failure mode, so the known link is stated outright and the positional rule is only a
    /// fallback for links we haven't been told about.
    public var regexDependencies: [String: String]
    /// Latest date a `Calender` field allows. Defaults to 18 years ago: the form's
    /// only age gate today is the T&C checkbox, and a picker that cannot select an
    /// under-18 date is a cheap second line of defence.
    public var maximumDateOfBirth: Date

    public init(repository: any FormRepository,
                validator: FieldValidator = FieldValidator(),
                localizer: any FormLocalizing = ComposedKeyLocalizer(),
                passwordPolicy: any PasswordPolicyProviding = PasswordPolicy(),
                appliesOptionRegexToDependentField: Bool = true,
                regexDependencies: [String: String] = ["idNumberType": "idNumber"],
                maximumDateOfBirth: Date = Calendar(identifier: .gregorian)
                    .date(byAdding: .year, value: -18, to: Date()) ?? Date()) {
        self.repository = repository
        self.validator = validator
        self.localizer = localizer
        self.passwordPolicy = passwordPolicy
        self.appliesOptionRegexToDependentField = appliesOptionRegexToDependentField
        self.regexDependencies = regexDependencies
        self.maximumDateOfBirth = maximumDateOfBirth
    }

    public static func live(repository: any FormRepository,
                           localizer: any FormLocalizing = ComposedKeyLocalizer()) -> FormDependencies {
        FormDependencies(repository: repository, localizer: localizer)
    }
}

private struct FormDependenciesKey: EnvironmentKey {
    /// Deliberately fatal: a form with no repository is a wiring bug, and a silent
    /// empty form would be much harder to diagnose than a clear crash in development.
    static var defaultValue: FormDependencies {
        FormDependencies(repository: UnavailableFormRepository(assertsWhenCalled: true))
    }
}

/// Never returns a form. Used wherever a repository is structurally required but must not be
/// called: the environment default (which asserts, because reaching it means the caller forgot
/// `.formDependencies(_:)`), the placeholder a two-argument `DynamicFormView` holds until
/// `.task` swaps in the environment's, and previews that seed a model directly.
struct UnavailableFormRepository: FormRepository {
    let assertsWhenCalled: Bool

    init(assertsWhenCalled: Bool = false) {
        self.assertsWhenCalled = assertsWhenCalled
    }

    func form(named name: FormName) async throws -> FormSchema {
        if assertsWhenCalled {
            assertionFailure("No FormDependencies in the environment. Call .formDependencies(_:) above DynamicFormView.")
        }
        throw CancellationError()
    }
}

public extension EnvironmentValues {
    var formDependencies: FormDependencies {
        get { self[FormDependenciesKey.self] }
        set { self[FormDependenciesKey.self] = newValue }
    }
}

public extension View {
    func formDependencies(_ dependencies: FormDependencies) -> some View {
        environment(\.formDependencies, dependencies)
    }
}

#if DEBUG
public extension FormDependencies {
    /// Dependencies for previews: never fetches (previews seed the schema directly),
    /// but carries the real localizer so the copy matches the designs.
    static var preview: FormDependencies {
        FormDependencies(repository: UnavailableFormRepository(),
                         localizer: ComposedKeyLocalizer.jpcRegistration)
    }
}

#endif
```

**35.** `JackpotKit/Sources/JackpotFormsUI/DynamicFormModel.swift`

```swift
import Foundation
import Combine
import JackpotFormsDomain

/// The engine. Owns the fetched schema, every field's value, touched state and errors,
/// and which section (page) is showing.
///
/// `ObservableObject` rather than `@Observable` because this package targets iOS 15.
/// The upgrade is mechanical when the app moves to 17 — see the guide, "iOS 15 seams".
@MainActor
public final class DynamicFormModel: ObservableObject {

    public enum ViewState: Equatable {
        case loading
        case loaded(FormSchema)
        case failed(String)
    }

    // MARK: Published state
    @Published public internal(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var errors: [String: String] = [:]
    @Published public internal(set) var sectionIndex: Int = 0
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

    /// Field types the schema asked for that this build cannot render. Non-fatal by
    /// design (see `FieldType.unknown`); surfaced so QA and logs can see them.
    @Published public private(set) var unsupportedFields: [String] = []

    /// Published: `objectWillChange` has to fire *before* the set changes, or the error it
    /// reveals lands a render late.
    @Published private var touched: Set<String> = []

    // MARK: Inputs
    private let formName: FormName
    private var dependencies: FormDependencies
    private var isConfigured: Bool
    private var loadTask: Task<Void, Never>?

    /// - Parameter isConfigured: true when the caller supplied real dependencies. The
    ///   two-argument `DynamicFormView.init` passes false and lets `configureIfNeeded`
    ///   swap in the environment's copy on first appearance — `@StateObject` cannot
    ///   read `@Environment` from an initializer.
    public init(formName: FormName, dependencies: FormDependencies, isConfigured: Bool = true) {
        self.formName = formName
        self.dependencies = dependencies
        self.isConfigured = isConfigured
    }

    /// Adopts environment-provided dependencies exactly once. No-op afterwards, so a
    /// re-render never resets a half-filled form.
    public func configureIfNeeded(with dependencies: FormDependencies) {
        guard !isConfigured else { return }
        self.dependencies = dependencies
        isConfigured = true
    }

    // MARK: Derived

    public var form: FormSchema? {
        if case .loaded(let form) = viewState { return form }
        return nil
    }

    public var sections: [FormSection] { form?.sections ?? [] }
    public var currentSection: FormSection? {
        sections.indices.contains(sectionIndex) ? sections[sectionIndex] : nil
    }
    public var isFirstSection: Bool { sectionIndex == 0 }
    public var isLastSection: Bool { sectionIndex >= sections.count - 1 }

    /// Fraction of all required fields across the whole form that currently validate.
    /// Drives the progress bar at the top of the panel.
    public var progress: Double {
        guard let form else { return 0 }
        let required = form.allFields.filter { $0.carriesValue && $0.isRequired }
        guard !required.isEmpty else { return isLastSection ? 1 : 0 }
        let satisfied = required.filter { isValid($0) }.count
        return Double(satisfied) / Double(required.count)
    }

    /// Whether the visible section can be advanced past / submitted.
    public var isCurrentSectionValid: Bool {
        guard let section = currentSection else { return false }
        return section.fields.filter(\.carriesValue).allSatisfy(isValid)
    }

    public var isFormValid: Bool {
        guard let form else { return false }
        return form.allFields.filter(\.carriesValue).allSatisfy(isValid)
    }

    public func value(for field: FormField) -> FormValue {
        values[field.identifier] ?? defaultValue(for: field)
    }

    /// Error text for a field, or nil while it is untouched.
    public func error(for field: FormField) -> String? {
        touched.contains(field.identifier) ? errors[field.identifier] : nil
    }

    public func localized(_ key: String) -> String { dependencies.localizer.display(key) }

    public func passwordRules(for field: FormField) -> [PasswordRule] {
        dependencies.passwordPolicy.rules(for: field)
    }

    public var maximumDateOfBirth: Date { dependencies.maximumDateOfBirth }

    // MARK: Loading

    public func load() {
        loadTask?.cancel()
        viewState = .loading
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let form = try await dependencies.repository.form(named: formName)
                guard !Task.isCancelled else { return }
                self.apply(form)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                self.viewState = .failed(Self.message(for: error))
            }
        }
    }

    private func apply(_ form: FormSchema) {
        viewState = .loaded(form)
        sectionIndex = 0
        touched = []
        errors = [:]
        values = Dictionary(uniqueKeysWithValues:
            form.allFields.filter(\.carriesValue).map { ($0.identifier, defaultValue(for: $0)) }
        )
        unsupportedFields = form.allFields.compactMap {
            if case .unknown(let raw) = $0.type { return "\($0.identifier) (\(raw))" }
            return nil
        }
        revalidateAll()
    }

    private func defaultValue(for field: FormField) -> FormValue {
        switch field.type {
        case .checkbox, .toggle: return .bool(false)
        case .dropdown, .radio, .radioGroup: return .option("")
        default: return field.inputType == .calendar ? .empty : .text("")
        }
    }

    // MARK: Editing

    public func setValue(_ value: FormValue, for field: FormField) {
        values[field.identifier] = value
        validate(field)
        // A dropdown can change a dependent field's rule (ID type → ID number), so
        // anything downstream of it has to be re-checked, not just this field.
        if field.type == .dropdown, dependencies.appliesOptionRegexToDependentField {
            revalidateDependents(of: field)
        }
    }

    /// Call on blur, or on first edit, so errors don't appear before the user has typed.
    /// Re-touching is a no-op rather than another render — the return key marks a field on
    /// submit and then again on the blur that follows.
    public func markTouched(_ field: FormField) {
        guard !touched.contains(field.identifier) else { return }
        touched.insert(field.identifier)
    }

    /// Focus navigation only carries identifiers.
    public func markTouched(identifiedBy identifier: String) {
        guard let field = form?.field(identifiedBy: identifier) else { return }
        markTouched(field)
    }

    // MARK: Validation

    private func isValid(_ field: FormField) -> Bool {
        errors[field.identifier] == nil
    }

    @discardableResult
    private func validate(_ field: FormField) -> Bool {
        let result = dependencies.validator.validate(
            value(for: field),
            against: field,
            overrideRegex: overrideRegex(for: field)
        )
        switch result {
        case .valid:
            errors[field.identifier] = nil
            return true
        case .invalid:
            errors[field.identifier] = dependencies.localizer.validationMessage(for: field)
            return false
        }
    }

    private func revalidateAll() {
        form?.allFields.filter(\.carriesValue).forEach { validate($0) }
    }

    private func revalidateDependents(of field: FormField) {
        guard let form else { return }
        let dependents = form.allFields.filter { candidate in
            candidate.carriesValue && regexDriver(for: candidate)?.id == field.id
        }
        dependents.forEach { validate($0) }
    }

    /// The dropdown that drives `field`'s regex, if any.
    ///
    /// Links are declared in `FormDependencies.regexDependencies`, never inferred from field
    /// order. An earlier version fell back to "the dropdown immediately before this field",
    /// which worked for the current schema but would have re-enabled silent breakage on a
    /// reorder — the exact fragility declaring the link was meant to remove.
    private func regexDriver(for field: FormField) -> FormField? {
        guard dependencies.appliesOptionRegexToDependentField,
              let form,
              let driverIdentifier = dependencies.regexDependencies.first(where: { $0.value == field.identifier })?.key,
              let driver = form.field(identifiedBy: driverIdentifier),
              driver.type == .dropdown
        else { return nil }
        return driver
    }

    /// The pattern a dropdown's current selection imposes on `field`, if any.
    ///
    /// Only *named* regexes redirect. `idNumberType`'s options carry `"idNumberRegex"` /
    /// `"passportNumberRegex"` — names — while `sourceOfFunds`'s carry `"[a-zA-Z]"`, a literal
    /// pattern that describes the selection itself and must not leak onto another field.
    private func overrideRegex(for field: FormField) -> String? {
        guard let driver = regexDriver(for: field),
              case .option(let selected) = value(for: driver),
              !selected.isEmpty,
              let option = driver.dropdownOptions.first(where: { $0.value == selected }),
              let raw = option.regex,
              !raw.looksLikeRegexPattern
        else { return nil }

        return dependencies.validator.optionPattern(raw)
    }

    // MARK: Paging

    /// Advances if the visible section validates; otherwise reveals its errors.
    @discardableResult
    public func advance() -> Bool {
        guard let section = currentSection else { return false }
        touched.formUnion(section.fields.filter(\.carriesValue).map(\.identifier))
        revalidateAll()
        guard isCurrentSectionValid else { return false }
        if !isLastSection { sectionIndex += 1 }
        return true
    }

    public func goBack() {
        guard sectionIndex > 0 else { return }
        sectionIndex -= 1
    }

    // MARK: Submitting

    public func submit(_ handler: @escaping (FormSubmission) async throws -> Void) async {
        guard let form else { return }
        touched.formUnion(form.allFields.filter(\.carriesValue).map(\.identifier))
        revalidateAll()
        guard isFormValid else { return }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            try await handler(FormSubmission(formCodeName: form.codeName, values: values))
        } catch is CancellationError {
        } catch {
            submitError = Self.message(for: error)
        }
    }

    deinit { loadTask?.cancel() }

    private static func message(for error: any Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription { return localized }
        return "Something went wrong. Please try again."
    }
}

#if DEBUG
// Preview support. Lives in this file because `apply(_:)` is private, and `private`
// in Swift is file-scoped — so an extension here can seed a model without widening
// the type's real API.
public extension DynamicFormModel {

    /// A model already holding `schema`, with no async load — previews render instantly
    /// and deterministically instead of flashing a skeleton.
    static func preview(schema: FormSchema,
                        dependencies: FormDependencies = .preview,
                        values: [String: FormValue] = [:],
                        touched: [String] = [],
                        sectionIndex: Int = 0) -> DynamicFormModel {
        let model = DynamicFormModel(formName: schema.codeName, dependencies: dependencies)
        model.apply(schema)
        for (identifier, value) in values {
            guard let field = schema.field(identifiedBy: identifier) else { continue }
            model.setValue(value, for: field)
        }
        for identifier in touched {
            guard let field = schema.field(identifiedBy: identifier) else { continue }
            model.markTouched(field)
        }
        model.sectionIndex = min(max(0, sectionIndex), max(0, schema.sections.count - 1))
        return model
    }

    /// Stuck on the loading state, for previewing the skeleton.
    static func previewLoading(dependencies: FormDependencies = .preview) -> DynamicFormModel {
        DynamicFormModel(formName: FormName("preview"), dependencies: dependencies)
    }

    /// Parked on the failure state.
    static func previewFailed(_ message: String = "The network connection was lost.") -> DynamicFormModel {
        let model = DynamicFormModel(formName: FormName("preview"), dependencies: .preview)
        model.viewState = .failed(message)
        return model
    }
}
#endif
```

**36.** `JackpotKit/Sources/JackpotFormsUI/Demo/PreviewFixtures.swift`

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// Hand-built fixtures mirroring the real registration schema.
///
/// Built in Swift rather than decoded from the bundled JSON on purpose: `JackpotFormsUI`
/// does not depend on `JackpotFormsData`, so it has no decoder — and previews that don't
/// touch the bundle render faster and can't fail on a missing resource. The JSON-backed
/// previews live in `JackpotForms`, which can see both layers.
public enum FormPreview {

    // MARK: Field builder

    public static func field(_ identifier: String,
                             type: FieldType = .input,
                             inputType: InputType = .text,
                             label: String? = nil,
                             placeholder: String? = nil,
                             required: Bool = true,
                             regex: String? = nil,
                             prefix: String = "",
                             dropdowns: [DropdownOption] = [],
                             radios: [RadioOption] = []) -> FormField {
        FormField(
            id: abs(identifier.hashValue % 10_000),
            identifier: identifier,
            name: identifier,
            labelKey: label ?? identifier,
            type: type,
            inputType: inputType,
            textStyle: "Regular",
            validationMessageKey: "regex",
            isRequired: required,
            isVisible: true,
            isReadOnly: false,
            regex: regex,
            prefix: prefix,
            suffix: "",
            placeholderKey: placeholder ?? identifier,
            dropdownOptions: dropdowns,
            radioOptions: radios
        )
    }

    // MARK: Individual fields, matching the real schema's rules

    public static let mobile = field("username", inputType: .number,
                                     regex: "^(27|0)?[1-9][0-9]{8}$", prefix: "+27")

    public static let password = field("password", inputType: .password,
                                       regex: "^(.){8,20}$")

    public static let firstName = field("firstname",
                                        regex: "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$")

    public static let email = field("email", inputType: .email,
                                    regex: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

    public static let referralCode = field("referralCode", required: false,
                                           regex: "^[a-zA-Z0-9]{3,25}$|^$")

    public static let idNumberType = field(
        "idNumberType", type: .dropdown, regex: "^[a-zA-Z]+$",
        dropdowns: [
            DropdownOption(value: "idNumber", textKey: "jpc-reg-idnumber", regex: "idNumberRegex"),
            DropdownOption(value: "passport", textKey: "jpc-reg-passport", regex: "passportNumberRegex"),
        ]
    )

    public static let idNumber = field("idNumber", regex: "^[0-9]{13}$")

    public static let dateOfBirth = field(
        "dateOfBirth", inputType: .calendar,
        regex: "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$"
    )

    public static let sourceOfFunds = field(
        "sourceOfFunds", type: .dropdown, regex: "^[a-zA-Z]+$",
        dropdowns: [
            DropdownOption(value: "SalaryOrWages", textKey: "jpc-reg-SalaryOrWages", regex: "[a-zA-Z]"),
            DropdownOption(value: "PensionOrGrant", textKey: "jpc-reg-PensionOrGrant", regex: "[a-zA-Z]"),
            DropdownOption(value: "AllowanceOrBursary", textKey: "jpc-reg-AllowanceOrBursary", regex: "[a-zA-Z]"),
            DropdownOption(value: "SavingsOrRentalOrOther", textKey: "jpc-reg-SavingsOrRentalOrOther", regex: "[a-zA-Z]"),
            DropdownOption(value: "SelfEmployed", textKey: "jpc-reg-SelfEmployed", regex: "[a-zA-Z]"),
        ]
    )

    public static let promoOptIn = field("receivePromotionalInformation", type: .checkbox,
                                         label: "receivePromotionalInformation-jza",
                                         required: false, regex: "^true|^false$")

    public static let terms = field("terms", type: .checkbox, required: true, regex: "^true$")

    // MARK: Whole schemas

    /// The two-section registration form, structured exactly as the CRM sends it.
    public static let registration = FormSchema(
        id: 1052, codeName: .registration, title: "registration", subTitle: "registration",
        regionCode: "JZA",
        sections: [
            FormSection(id: 45, codeName: "1", title: "1", subTitle: "1", order: 1, rows: [
                FormRow(number: 1, fields: [mobile]),
                FormRow(number: 2, fields: [password]),
                FormRow(number: 3, fields: [firstName]),
                FormRow(number: 4, fields: [field("lastname", regex: "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$")]),
                FormRow(number: 5, fields: [email]),
                FormRow(number: 6, fields: [referralCode]),
            ]),
            FormSection(id: 46, codeName: "2", title: "2", subTitle: "2", order: 2, rows: [
                FormRow(number: 1, fields: [idNumberType]),
                FormRow(number: 2, fields: [idNumber]),
                FormRow(number: 3, fields: [dateOfBirth]),
                FormRow(number: 4, fields: [sourceOfFunds]),
                FormRow(number: 5, fields: [promoOptIn]),
                FormRow(number: 6, fields: [terms]),
            ]),
        ]
    )

    /// A single field wrapped in a one-section schema — for previewing components alone.
    public static func schema(_ fields: [FormField]) -> FormSchema {
        FormSchema(id: 1, codeName: FormName("preview"), title: "", subTitle: "", regionCode: "JZA",
                   sections: [FormSection(id: 1, codeName: "1", title: "", subTitle: "", order: 1,
                                          rows: fields.enumerated().map { FormRow(number: $0.offset + 1, fields: [$0.element]) })])
    }

    /// Model holding just these fields, optionally pre-filled and pre-touched so the
    /// invalid (red) state can be previewed without interacting.
    @MainActor
    public static func model(_ fields: [FormField],
                            values: [String: FormValue] = [:],
                            touched: [String] = []) -> DynamicFormModel {
        .preview(schema: schema(fields), values: values, touched: touched)
    }

    /// Values that make section one valid — useful for previewing the unlocked
    /// Welcome Offer and the enabled Next button.
    public static let validSectionOne: [String: FormValue] = [
        "username": .text("849134302"),
        "password": .text("Password1"),
        "firstname": .text("Malcolm"),
        "lastname": .text("Collin"),
        "email": .text("hi@example.com"),
    ]
}
#endif
```

**37.** `JackpotKit/Sources/JackpotFormsUI/Fields/FieldRenderer.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// Maps a schema `fieldType` to a component. This switch is the entire contract between the
/// form builder and the app: adding a type on the server means adding a case here and
/// shipping — until then, the unknown case keeps the form usable.
///
/// Every case binds the model to a `JackpotUI` component. The components know nothing about
/// forms; the views in this folder are the only place the two meet.
struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        switch field.type {
        case .input:                    InputFieldView(field: field, model: model)
        case .dropdown:                 DropdownFieldView(field: field, model: model)
        case .checkbox:                 CheckboxFieldView(field: field, model: model)
        case .textArea, .radio, .radioGroup, .toggle, .welcomeOffer, .divider: EmptyView()
        case .button:                   EmptyView()          // the form's footer owns navigation
        case .recaptchaV2, .recaptchaV3: RecaptchaPlaceholderView(field: field)
        case .unknown:                  EmptyView()          // reported via model.unsupportedFields
        }
    }
}

/// reCAPTCHA needs a WKWebView bridge; out of scope for the first PR but the type is
/// recognised so the form still renders and validates around it.
struct RecaptchaPlaceholderView: View {
    let field: FormField
    @Environment(\.jackpotTheme) private var theme

    var body: some View {
        #if DEBUG
        Text("reCAPTCHA (\(field.identifier)) — not implemented")
            .jackpotTextStyle(\.error, color: \.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .jackpotFieldBackground()
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Keyboard focus order

extension FormField {
    /// Only single-line text entry joins return-key navigation. A date opens a picker, and a
    /// text area needs the return key for newlines.
    var acceptsKeyboardFocus: Bool {
        type == .input && inputType != .calendar
    }
}

extension DynamicFormModel {
    /// The current section's text fields, in the order the return key walks them.
    var focusableIdentifiers: [String] {
        (currentSection?.rows ?? [])
            .flatMap(\.fields)
            .filter { $0.isVisible && $0.acceptsKeyboardFocus }
            .map(\.identifier)
    }

    /// Returns the field after `identifier`, or nil at the end so the keyboard dismisses.
    func fieldAfter(_ identifier: String?) -> String? {
        let ids = focusableIdentifiers
        guard let identifier, let index = ids.firstIndex(of: identifier) else { return nil }
        let next = ids.index(after: index)
        return next < ids.endIndex ? ids[next] : nil
    }
}

// MARK: - Shared bindings

extension DynamicFormModel {
    /// Text binding for a field, writing back as `.text`.
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    // The three below mark the field touched as they write. A discrete choice is a complete
    // answer, so validating it immediately is right — unlike typing, where `text(for:)` stays
    // silent and the field reports blur through `onEditingEnded`.

    /// Selection binding for dropdowns and radio groups. An empty selection is `.option("")`.
    func selection(for field: FormField) -> Binding<String?> {
        Binding(get: { let v = self.value(for: field).stringValue; return v.isEmpty ? nil : v },
                set: { self.setValue(.option($0 ?? ""), for: field); self.markTouched(field) })
    }

    func bool(for field: FormField) -> Binding<Bool> {
        Binding(get: { self.value(for: field).boolValue },
                set: { self.setValue(.bool($0), for: field); self.markTouched(field) })
    }

    func date(for field: FormField) -> Binding<Date?> {
        Binding(get: { self.value(for: field).dateValue },
                set: { self.setValue($0.map(FormValue.date) ?? .empty, for: field); self.markTouched(field) })
    }

    func options(for field: FormField) -> [JackpotOption] {
        field.dropdownOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }
    }

    func radioOptions(for field: FormField) -> [JackpotOption] {
        field.radioOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }
    }
}
```

Registration asks for Input, Dropdown and Checkbox only, so the text area, radio, toggle,
welcome offer and divider types render nothing here — each is additive and gets its own field
view when a schema needs it.

**38.** `JackpotKit/Sources/JackpotFormsUI/Fields/InputFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    @State private var isEditing = false

    var body: some View {
        if field.inputType == .calendar {
            DateFieldView(field: field, model: model)
        } else {
            JackpotLabeledField(error: model.error(for: field)) {
                VStack(spacing: 6) {
                    JackpotTextField(model.localized(field.placeholderKey),
                                     text: model.text(for: field))
                        .onEditingEnded { model.markTouched(field) }
                        .onFocusChange { isEditing = $0 }
                        .jackpotField(kind)
                        .jackpotFieldPrefix(field.prefix)
                        .jackpotFieldSuffix(field.suffix)
                        .jackpotFieldIdentity(field.identifier)
                        .jackpotSubmitLabel(isLastFocusable ? .done : .next)
                        .disabled(field.isReadOnly)

                    // The rules are guidance while composing a password, not a permanent
                    // fixture — once the field is left the error line carries the verdict.
                    if field.isSecure, isEditing {
                        JackpotChecklist("Password Validity", items: passwordItems)
                            .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isEditing)
            }
        }
    }

    private var isLastFocusable: Bool {
        model.focusableIdentifiers.last == field.identifier
    }

    private var passwordItems: [JackpotChecklistItem] {
        model.passwordRules(for: field).map { rule in
            JackpotChecklistItem(id: rule.id,
                                 text: rule.fallbackDescription,
                                 isSatisfied: rule.isSatisfied(by: model.value(for: field).stringValue))
        }
    }

    private var kind: JackpotFieldKind {
        if field.isSecure { return .newPassword }
        switch field.inputType {
        case .email:  return .email
        case .phone:  return .phoneNumber
        case .number: return .number
        default:      break
        }
        // Falls back to the identifier, because the schema's `inputType` is coarser than the
        // autofill hints iOS can use.
        switch field.identifier.lowercased() {
        case "username", "mobile", "mobilenumber": return .phoneNumber
        case "firstname":                          return .givenName
        case "lastname", "surname":                return .familyName
        case "email":                              return .email
        default:                                   return .text.with { $0.capitalization = .words }
        }
    }
}

#if DEBUG
struct InputFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Empty · untouched") {
                InputFieldView(field: FormPreview.mobile, model: FormPreview.model([FormPreview.mobile]))
            }.previewDisplayName("Mobile — empty")
            JackpotPreviewPanel("Invalid · touched") {
                InputFieldView(field: FormPreview.mobile,
                               model: FormPreview.model([FormPreview.mobile], values: ["username": .text("123")], touched: ["username"]))
            }.previewDisplayName("Mobile — invalid")
            // The checklist is focus-gated, so it stays hidden here; focus the field in the
            // live preview to see it.
            JackpotPreviewPanel("Password · 7 chars · unfocused") {
                InputFieldView(field: FormPreview.password,
                               model: FormPreview.model([FormPreview.password], values: ["password": .text("Passwo1")], touched: ["password"]))
            }.previewDisplayName("Password — rules hidden")
            JackpotPreviewPanel("Optional · empty is fine") {
                InputFieldView(field: FormPreview.referralCode,
                               model: FormPreview.model([FormPreview.referralCode], touched: ["referralCode"]))
            }.previewDisplayName("Referral — optional")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**39.** `JackpotKit/Sources/JackpotFormsUI/Fields/DropdownFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct DropdownFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotDropdown(model.localized(field.placeholderKey),
                            selection: model.selection(for: field),
                            options: model.options(for: field))
                .disabled(field.isReadOnly)
        }
    }
}

#if DEBUG
struct DropdownFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Placeholder") {
                DropdownFieldView(field: FormPreview.idNumberType, model: FormPreview.model([FormPreview.idNumberType]))
            }.previewDisplayName("ID type — placeholder")
            JackpotPreviewPanel("Selected") {
                DropdownFieldView(field: FormPreview.idNumberType,
                                  model: FormPreview.model([FormPreview.idNumberType], values: ["idNumberType": .option("idNumber")]))
            }.previewDisplayName("ID type — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DropdownFieldView(field: FormPreview.sourceOfFunds,
                                  model: FormPreview.model([FormPreview.sourceOfFunds], touched: ["sourceOfFunds"]))
            }.previewDisplayName("Source of funds — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**40.** `JackpotKit/Sources/JackpotFormsUI/Fields/DateFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// `inputType: "Calender"`. The schema validates against an ISO-8601 date-time, so the
/// picker's `Date` is serialised through `FormValue.iso8601` rather than a display format.
struct DateFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(model.localized(field.labelKey), error: model.error(for: field)) {
            // The form's only age gate is the T&C checkbox; capping the picker stops an
            // under-18 date being entered at all.
            JackpotDateField(model.localized(field.placeholderKey),
                             selection: model.date(for: field),
                             in: ...model.maximumDateOfBirth)
                .disabled(field.isReadOnly)
        }
    }
}

#if DEBUG
struct DateFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("No date") {
                DateFieldView(field: FormPreview.dateOfBirth, model: FormPreview.model([FormPreview.dateOfBirth]))
            }.previewDisplayName("Date — placeholder")
            JackpotPreviewPanel("Chosen") {
                DateFieldView(field: FormPreview.dateOfBirth,
                              model: FormPreview.model([FormPreview.dateOfBirth],
                                                       values: ["dateOfBirth": .date(Date(timeIntervalSince1970: 631152000))]))
            }.previewDisplayName("Date — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DateFieldView(field: FormPreview.dateOfBirth,
                              model: FormPreview.model([FormPreview.dateOfBirth], touched: ["dateOfBirth"]))
            }.previewDisplayName("Date — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**41.** `JackpotKit/Sources/JackpotFormsUI/Fields/CheckboxFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// Checkbox values validate as the strings "true"/"false" — the schema's `terms` field
/// literally uses the pattern `^true$` to mean "must be ticked".
struct CheckboxFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(error: model.error(for: field)) {
            Toggle(model.localized(field.labelKey), isOn: model.bool(for: field))
                .toggleStyle(.jackpotCheckbox)
                .disabled(field.isReadOnly)
        }
    }
}

#if DEBUG
struct CheckboxFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Unticked · required · touched") {
                CheckboxFieldView(field: FormPreview.terms, model: FormPreview.model([FormPreview.terms], touched: ["terms"]))
            }.previewDisplayName("Terms — must be ticked")
            JackpotPreviewPanel("Ticked") {
                CheckboxFieldView(field: FormPreview.terms,
                                  model: FormPreview.model([FormPreview.terms], values: ["terms": .bool(true)]))
            }.previewDisplayName("Terms — accepted")
            JackpotPreviewPanel("Optional · wraps") {
                CheckboxFieldView(field: FormPreview.promoOptIn, model: FormPreview.model([FormPreview.promoOptIn]))
            }.previewDisplayName("Promotions opt-in")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**42.** `JackpotKit/Sources/JackpotFormsUI/DynamicFormView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// The single component the ticket asks for.
///
///     DynamicFormView(formName: .registration) { submission in
///         try await api.register(submission.stringValues)
///     }
///
/// Two arguments: the form name used to fetch the schema, and the callback that receives the
/// collected data. Everything else arrives through the environment (`.formDependencies(_:)`,
/// `.jackpotTheme(_:)`) so no dependency is hidden in a global.
public struct DynamicFormView: View {

    public typealias SubmitHandler = (FormSubmission) async throws -> Void

    private let formName: FormName
    private let onSubmit: SubmitHandler

    @Environment(\.formDependencies) private var dependencies
    @Environment(\.jackpotTheme) private var theme
    @StateObject private var model: DynamicFormModel
    @State private var hasLoaded = false

    /// The two-argument form. Dependencies come from the environment.
    public init(formName: FormName, onSubmit: @escaping SubmitHandler) {
        self.formName = formName
        self.onSubmit = onSubmit
        // @StateObject cannot read @Environment in init, so a placeholder is swapped for the
        // environment's dependencies on first appearance.
        _model = StateObject(wrappedValue: DynamicFormModel(
            formName: formName,
            dependencies: FormDependencies(repository: UnavailableFormRepository()),
            isConfigured: false
        ))
    }

    /// Explicit-dependency form, for previews and tests that don't want an environment.
    public init(formName: FormName, dependencies: FormDependencies, onSubmit: @escaping SubmitHandler) {
        self.formName = formName
        self.onSubmit = onSubmit
        _model = StateObject(wrappedValue: DynamicFormModel(formName: formName, dependencies: dependencies))
    }

    public var body: some View {
        DynamicFormBody(model: model, onSubmit: onSubmit)
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                model.configureIfNeeded(with: dependencies)
                model.load()
            }
    }
}

/// The rendered form for a given model. Separate from `DynamicFormView` so previews can drive
/// it from a seeded model without a fetch.
struct DynamicFormBody: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler
    @Environment(\.jackpotTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedField: String?
    @State private var isAdvancing = true

    var body: some View {
        switch model.viewState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
                .accessibilityLabel("Loading form")

        case .failed(let message):
            JackpotErrorView(message, title: "Couldn't load this form")
                .onRetry { model.load() }

        case .loaded:
            VStack(spacing: 0) {
                if model.sections.count > 1 {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.jackpotBar)
                        .padding(.horizontal, 16).padding(.top, 12)
                        .accessibilityLabel("Form progress")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.metrics.spacing) {
                        if let section = model.currentSection {
                            ForEach(section.rows) { row in FormRowView(row: row, model: model) }
                        }
                        if let error = model.submitError {
                            Text(error).font(.footnote).jackpotForegroundStyle(\.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        #if DEBUG
                        if !model.unsupportedFields.isEmpty {
                            Text("Unsupported field types skipped: \(model.unsupportedFields.joined(separator: ", "))")
                                .font(.caption2).foregroundColor(.orange)
                        }
                        #endif
                    }
                    .padding(16)
                    // New identity per section is what lets the transition run at all; the
                    // nav bar and progress bar sit outside it so they don't slide too.
                    .id(model.sectionIndex)
                    .transition(sectionTransition)
                }

                FormNavigationBar(model: model,
                                  onSubmit: onSubmit,
                                  advance: advance,
                                  goBack: goBack)
                    .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .jackpotBackground(\.surface)
            .jackpotFocusedField($focusedField)
            // Fires for whichever field submitted; the shared value says which one that was.
            // Validate before moving, so the error and the new focus land in one update
            // rather than the error arriving a render after the keyboard has moved on.
            .onSubmit {
                guard let current = focusedField else { return }
                model.markTouched(identifiedBy: current)
                focusedField = model.fieldAfter(current)
            }
            // Covers section changes that don't come from the nav bar.
            .onChange(of: model.sectionIndex) { _ in focusedField = nil }
        }
    }

    // MARK: Paging

    // Direction has to be set before the index changes, not in an onChange afterwards —
    // the transition is resolved in the same update that moves the section.
    private func advance() {
        isAdvancing = true
        focusedField = nil
        withAnimation(pagingAnimation) { _ = model.advance() }
    }

    private func goBack() {
        isAdvancing = false
        focusedField = nil
        withAnimation(pagingAnimation) { model.goBack() }
    }

    /// Offset rather than a full `.move`, so the outgoing and incoming sections don't drag
    /// the scroll view's content width around mid-flight.
    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let travel: CGFloat = isAdvancing ? 60 : -60
        return .asymmetric(insertion: .offset(x: travel).combined(with: .opacity),
                           removal: .offset(x: -travel).combined(with: .opacity))
    }

    private var pagingAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2)
                     : .spring(response: 0.42, dampingFraction: 0.86)
    }
}

/// Fields sharing a `rowNumber` render side by side; a single field fills the row. This is
/// what makes the "+27 | Mobile Number" pairing fall out of the schema rather than being
/// special-cased.
struct FormRowView: View {
    let row: FormRow
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        let visible = row.fields.filter { $0.isVisible }
        if visible.count == 1 {
            FieldRenderer(field: visible[0], model: model)
        } else if !visible.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                ForEach(visible) { FieldRenderer(field: $0, model: model) }
            }
        }
    }
}

struct FormNavigationBar: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler
    let advance: () -> Void
    let goBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if !model.isFirstSection {
                Button("Previous", action: goBack)
                    .buttonStyle(.jackpot(.secondary))
            }
            if model.isLastSection {
                Button("Sign Up") { Task { await model.submit(onSubmit) } }
                    .buttonStyle(.jackpot)
                    .disabled(!model.isFormValid)
                    .jackpotLoading(model.isSubmitting)
            } else {
                Button("Next", action: advance)
                    .buttonStyle(.jackpot)
                    .disabled(!model.isCurrentSectionValid)
            }
        }
    }
}


// MARK: - Previews

#if DEBUG
struct DynamicFormView_Previews: PreviewProvider {
    private struct Harness: View {
        let model: DynamicFormModel
        var scheme: ColorScheme = .dark
        var body: some View {
            DynamicFormBody(model: model) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.surface)
                .preferredColorScheme(scheme)
        }
    }

    static var previews: some View {
        Group {
            Harness(model: .preview(schema: FormPreview.registration))
                .previewDisplayName("Section 1 — empty")
            Harness(model: .preview(schema: FormPreview.registration), scheme: .light)
                .previewDisplayName("Section 1 — light")
            Harness(model: .preview(schema: FormPreview.registration, values: FormPreview.validSectionOne))
                .previewDisplayName("Section 1 — valid, Next enabled")
            Harness(model: .preview(schema: FormPreview.registration,
                                    touched: ["username", "password", "firstname", "lastname", "email"]))
                .previewDisplayName("Section 1 — all errors shown")
            Harness(model: .preview(schema: FormPreview.registration, values: FormPreview.validSectionOne, sectionIndex: 1))
                .previewDisplayName("Section 2 — FICA")
            Harness(model: .preview(schema: FormPreview.registration, values: FormPreview.validSectionOne,
                                    touched: ["idNumber", "dateOfBirth", "sourceOfFunds", "terms"], sectionIndex: 1))
                .previewDisplayName("Section 2 — all errors shown")
            Harness(model: .previewLoading()).previewDisplayName("Loading")
            Harness(model: .previewFailed()).previewDisplayName("Failed")
            Harness(model: .preview(schema: FormPreview.registration))
                .environment(\.sizeCategory, .accessibilityLarge)
                .previewDisplayName("Accessibility — XL text")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**43.** `JackpotKit/Sources/JackpotFormsUI/Demo/PreviewSupport.swift`

```swift
import Foundation
import SwiftUI
import JackpotFormsDomain

/// Localization table that turns the schema's keys into the copy in the designs.
/// In production this is fed from the CRM strings endpoint — see the guide.
public extension ComposedKeyLocalizer {
    static let jpcRegistration = ComposedKeyLocalizer(table: [
        // Placeholders / labels
        "username": "Enter Mobile Number",
        "password": "Password",
        "firstname": "First Name (As it appears on your ID)",
        "lastname": "Surname (As it appears on ID)",
        "email": "Email",
        "referralCode": "I have a sign up code",
        "idNumberType": "ID Number Type",
        "idNumber": "ID Number",
        "dateOfBirth": "Enter Date Of Birth",
        "sourceOfFunds": "Enter Source Of Income",
        "receivePromotionalInformation-jza": "Send Jackpot City Promotions to me",
        "terms": "I am over 18 years of age & I accept Jackpotcity's Terms & Conditions & Privacy Policy",
        "acceptTermsConditions": "I am over 18 years of age & I accept Jackpotcity's Terms & Conditions & Privacy Policy",

        // Dropdown options
        "jpc-reg-idnumber": "South African ID",
        "jpc-reg-passport": "Passport",
        "jpc-reg-SalaryOrWages": "Salary or Wages",
        "jpc-reg-PensionOrGrant": "Pension or Grant",
        "jpc-reg-AllowanceOrBursary": "Allowance or Bursary",
        "jpc-reg-SavingsOrRentalOrOther": "Savings, Rental or Other",
        "jpc-reg-SelfEmployed": "Self Employed",

        // Composed validation messages: jpc-reg-{fieldIdentifier}-{validationMessage}
        "jpc-reg-username-regex": "Enter a valid mobile number",
        "jpc-reg-password-regex": "Password must be 8–20 characters",
        "jpc-reg-firstname-regex": "Enter your first name as it appears on your ID",
        "jpc-reg-lastname-regex": "Enter your surname as it appears on your ID",
        "jpc-reg-email-regex": "Enter a valid email address",
        "jpc-reg-referralCode-regex": "Sign up codes are 3–25 letters or numbers",
        "jpc-reg-idNumberType-regex": "Please select an ID type",
        "jpc-reg-idNumber-regex": "Enter in a valid ID number",
        "jpc-reg-dateOfBirth-regex": "Enter date of birth",
        "jpc-reg-sourceOfFunds-regex": "Please select your source of income.",
        "jpc-reg-terms-regex": "You must accept the Terms & Conditions to continue",
    ])
}

public enum FormPreviewData {
    /// Schemas bundled with the package, for the sandbox and previews.
    /// `Bundle.module` is internal, so it cannot appear in a public default argument —
    /// hence the explicit overload rather than `bundle: Bundle = .module`.
    public static func bundledJSON(named name: String) -> Data {
        json(named: name, in: .module)
    }

    public static func json(named name: String, in bundle: Bundle) -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("Missing fixture \(name).json")
            return Data("{}".utf8)
        }
        return data
    }

    /// The two schemas shipped with the package, keyed by `formCodeName` — exactly the
    /// shape `StubFormRepository(forms:)` wants.
    public static var bundledForms: [FormName: Data] {
        Dictionary(uniqueKeysWithValues: FormName.bundled.map { ($0, bundledJSON(named: $0.rawValue)) })
    }
}
```

**44.** `JackpotKit/Sources/JackpotFormsUI/Demo/FormSandboxView.swift`

```swift
import SwiftUI
import JackpotFormsDomain

/// "Create a testing page where we can see this in action." — the ticket.
///
/// Pick a form, watch it render from JSON alone, submit it, and read back exactly what
/// the callback received. Nothing here is app-specific, so it doubles as the review
/// harness for the PR.
public struct FormSandboxView: View {

    public struct Sample: Identifiable, Hashable {
        public let id: FormName
        public let title: String
        public init(id: FormName, title: String) {
            self.id = id
            self.title = title
        }
    }

    private let samples: [Sample]
    private let dependencies: FormDependencies

    @State private var selected: Sample
    @State private var lastSubmission: [String: String]?
    @State private var showsSubmission = false

    public init(samples: [Sample], dependencies: FormDependencies) {
        precondition(!samples.isEmpty, "FormSandboxView needs at least one sample form")
        self.samples = samples
        self.dependencies = dependencies
        _selected = State(initialValue: samples[0])
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                picker
                Divider()
                DynamicFormView(formName: selected.id) { submission in
                    // Deliberately not posting anywhere: the sandbox proves the
                    // callback contract, not the registration endpoint.
                    lastSubmission = submission.stringValues
                    showsSubmission = true
                }
                .id(selected.id)                 // rebuild the engine when the form changes
                .formDependencies(dependencies)
            }
            .navigationTitle("Form Sandbox")
            .iOSInlineTitle()
            .sheet(isPresented: $showsSubmission) {
                SubmissionResultView(values: lastSubmission ?? [:])
            }
        }
        .iOSStackNavigation()
    }

    private var picker: some View {
        Picker("Form", selection: $selected) {
            ForEach(samples) { sample in
                Text(sample.title).tag(sample)
            }
        }
        .pickerStyle(.segmented)
        .padding(12)
    }
}

struct SubmissionResultView: View {
    let values: [String: String]
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            List(values.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 2) {
                    Text(key).font(.caption).foregroundColor(.secondary)
                    Text(values[key]?.isEmpty == false ? values[key]! : "—")
                        .font(.body.monospaced())
                }
            }
            .navigationTitle("Submitted")
            .iOSInlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .iOSStackNavigation()
    }
}


// MARK: - Platform guards
//
// The sandbox is an iOS harness, but the package still has to type-check on a macOS
// host so `swift test` can run the Domain/Data suites from the command line.

extension View {
    @ViewBuilder
    func iOSInlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func iOSStackNavigation() -> some View {
        #if os(iOS)
        navigationViewStyle(.stack)
        #else
        self
        #endif
    }
}

#if DEBUG
struct FormSandboxView_Previews: PreviewProvider {
    /// Serves the hand-built fixtures, so the sandbox previews without the bundle.
    private struct FixtureRepository: FormRepository {
        func form(named name: FormName) async throws -> FormSchema {
            try await Task.sleep(nanoseconds: 300_000_000)
            return FormPreview.registration
        }
    }

    static var previews: some View {
        FormSandboxView(
            samples: [.init(id: .registration, title: "Registration")],
            dependencies: FormDependencies(repository: FixtureRepository(),
                                           localizer: ComposedKeyLocalizer.jpcRegistration)
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Sandbox")
    }
}
#endif
```

**45.**

```bash
cp registration.json JackpotKit/Sources/JackpotFormsUI/Resources/registration.json
cp JackpotKit/Sources/JackpotFormsUI/Resources/registration.json \
   JackpotKit/Tests/JackpotFormsTests/Fixtures/registration.json
```

The schema fixture is the CRM's `registration` response saved verbatim — 12 fields over two
sections — copied to `JackpotKit/Sources/JackpotFormsUI/Resources/registration.json`, which
the target processes as a resource. It is mirrored at
`JackpotKit/Tests/JackpotFormsTests/Fixtures/registration.json` so the suites below load it
from their own `Bundle.module` rather than reaching into another target's.

**46.** `JackpotKit/Tests/JackpotFormsTests/FormDecodingTests.swift`

```swift
import XCTest
@testable import JackpotFormsData
import JackpotFormsDomain

final class FormDecodingTests: XCTestCase {

    private func loadRegistration() throws -> FormSchema {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "registration", withExtension: "json"))
        return try StubFormRepository.decode(try Data(contentsOf: url))
    }

    func testDecodesTheRealRegistrationSchema() throws {
        let form = try loadRegistration()
        XCTAssertEqual(form.id, 1052)
        XCTAssertEqual(form.codeName, .registration)
        XCTAssertEqual(form.regionCode, "JZA")
        XCTAssertEqual(form.sections.count, 2)
        XCTAssertEqual(form.allFields.count, 12)
    }

    func testSectionsAndRowsAreOrdered() throws {
        let form = try loadRegistration()
        XCTAssertEqual(form.sections.map(\.order), [1, 2])
        XCTAssertEqual(form.sections[0].rows.map(\.number), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(form.sections[0].fields.map(\.identifier),
                       ["username", "password", "firstname", "lastname", "email", "referralCode"])
    }

    func testFieldTypesMapCorrectly() throws {
        let form = try loadRegistration()
        XCTAssertEqual(form.field(identifiedBy: "username")?.type, .input)
        XCTAssertEqual(form.field(identifiedBy: "username")?.inputType, .number)
        XCTAssertEqual(form.field(identifiedBy: "password")?.inputType, .password)
        XCTAssertEqual(form.field(identifiedBy: "idNumberType")?.type, .dropdown)
        XCTAssertEqual(form.field(identifiedBy: "terms")?.type, .checkbox)
    }

    /// The schema spells it "Calender". If the backend ever fixes the typo we must not
    /// silently downgrade the date picker to a text box.
    func testCalendarInputTypeAcceptsBothSpellings() {
        XCTAssertEqual(InputType(raw: "Calender"), .calendar)
        XCTAssertEqual(InputType(raw: "Calendar"), .calendar)
        XCTAssertEqual(InputType(raw: "date"), .calendar)
    }

    /// The single most important behaviour in the decoder: a field type this build has
    /// never heard of must not fail the decode, because product edits the schema in a
    /// CMS without shipping an app.
    func testUnknownFieldTypeDoesNotFailTheDecode() throws {
        let json = Data("""
        {"formId":1,"formCodeName":"x","sections":[{"formSectionId":1,"rows":[
          {"rowNumber":1,"fields":[{"fieldId":1,"fieldIdentifier":"a","fieldType":"HolographicSlider"}]},
          {"rowNumber":2,"fields":[{"fieldId":2,"fieldIdentifier":"b","fieldType":"Input"}]}
        ]}]}
        """.utf8)
        let form = try StubFormRepository.decode(json)
        XCTAssertEqual(form.allFields.count, 2)
        XCTAssertEqual(form.field(identifiedBy: "a")?.type, .unknown("HolographicSlider"))
        XCTAssertEqual(form.field(identifiedBy: "b")?.type, .input)
    }

    func testMissingOptionalKeysFallBackSafely() throws {
        let json = Data("""
        {"formId":2,"formCodeName":"y","sections":[{"formSectionId":1,"rows":[
          {"rowNumber":1,"fields":[{"fieldId":9,"fieldIdentifier":"solo","fieldType":"Input"}]}]}]}
        """.utf8)
        let field = try XCTUnwrap(StubFormRepository.decode(json).field(identifiedBy: "solo"))
        XCTAssertEqual(field.labelKey, "solo")
        XCTAssertEqual(field.placeholderKey, "solo")
        XCTAssertEqual(field.validationMessageKey, "regex")
        XCTAssertFalse(field.isRequired)     // unspecified must not block submission
        XCTAssertTrue(field.isVisible)
        XCTAssertNil(field.regex)
    }

    func testDropdownOptionsCarryValueTextAndRegex() throws {
        let form = try loadRegistration()
        let options = try XCTUnwrap(form.field(identifiedBy: "idNumberType")?.dropdownOptions)
        XCTAssertEqual(options.map(\.value), ["idNumber", "passport"])
        XCTAssertEqual(options[0].textKey, "jpc-reg-idnumber")
        XCTAssertEqual(options[0].regex, "idNumberRegex")
    }
}

final class FormNameTests: XCTestCase {

    func testKnownNamesMapToTheirCodeNames() {
        XCTAssertEqual(FormName.registration.rawValue, "registration")
        XCTAssertEqual(FormName.kitchenSink.rawValue, "kitchenSink")
    }

    /// Forms are authored server-side, so a name this build has never heard of must still
    /// be constructible — that's why FormName isn't an enum.
    func testServerAuthoredNamesAreConstructible() {
        let deposit = FormName("deposit")
        XCTAssertEqual(deposit.rawValue, "deposit")
        XCTAssertNotEqual(deposit, .registration)
    }

    func testUsableAsADictionaryKey() {
        let forms: [FormName: Int] = [.registration: 1, FormName("deposit"): 2]
        XCTAssertEqual(forms[.registration], 1)
        XCTAssertEqual(forms[FormName("deposit")], 2)
        XCTAssertNil(forms[.kitchenSink])
    }

    func testRoundTripsThroughRawValue() {
        XCTAssertEqual(FormName(rawValue: "registration"), .registration)
    }

    func testBundledListMatchesTheShippedResources() {
        XCTAssertEqual(Set(FormName.bundled), [.registration, .kitchenSink])
    }
}
```

PR 3 appends the remote and localisation suites to this same file.

**47.** `JackpotKit/Tests/JackpotFormsTests/FieldValidatorTests.swift`

```swift
import XCTest
@testable import JackpotFormsData
import JackpotFormsDomain

final class FieldValidatorTests: XCTestCase {

    private let validator = FieldValidator()

    private func field(_ identifier: String,
                       type: FieldType = .input,
                       inputType: InputType = .text,
                       required: Bool = true,
                       regex: String?) -> FormField {
        FormField(id: 1, identifier: identifier, name: identifier, labelKey: identifier,
                  type: type, inputType: inputType, textStyle: "Regular",
                  validationMessageKey: "regex", isRequired: required, isVisible: true, isReadOnly: false,
                  regex: regex, prefix: "", suffix: "", placeholderKey: identifier,
                  dropdownOptions: [], radioOptions: [])
    }

    // MARK: Real patterns from the registration schema

    func testMobileNumberPattern() {
        let mobile = field("username", inputType: .number, regex: "^(27|0)?[1-9][0-9]{8}$")
        XCTAssertTrue(validator.validate(.text("849134302"), against: mobile).isValid)
        XCTAssertTrue(validator.validate(.text("0849134302"), against: mobile).isValid)
        XCTAssertTrue(validator.validate(.text("27849134302"), against: mobile).isValid)
        XCTAssertFalse(validator.validate(.text("049134302"), against: mobile).isValid)   // leading 0 after prefix
        XCTAssertFalse(validator.validate(.text("12345"), against: mobile).isValid)
    }

    func testPasswordLengthPattern() {
        let password = field("password", inputType: .password, regex: "^(.){8,20}$")
        XCTAssertFalse(validator.validate(.text("short"), against: password).isValid)
        XCTAssertTrue(validator.validate(.text("longenough"), against: password).isValid)
        XCTAssertFalse(validator.validate(.text(String(repeating: "a", count: 21)), against: password).isValid)
    }

    func testSouthAfricanIdPattern() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        XCTAssertTrue(validator.validate(.text("9001015800089"), against: id).isValid)
        XCTAssertFalse(validator.validate(.text("900101580008"), against: id).isValid)
    }

    // MARK: Required / optional

    func testRequiredEmptyFails() {
        XCTAssertFalse(validator.validate(.text(""), against: field("a", regex: "^.+$")).isValid)
        XCTAssertFalse(validator.validate(.text("   "), against: field("a", regex: "^.+$")).isValid)
    }

    func testOptionalEmptyPassesEvenWhenTheRegexWouldNot() {
        // referralCode's own regex allows empty, but many optional fields' won't —
        // the empty short-circuit is what makes "optional" mean optional.
        let optional = field("referralCode", required: false, regex: "^[a-zA-Z0-9]{3,25}$")
        XCTAssertTrue(validator.validate(.text(""), against: optional).isValid)
        XCTAssertFalse(validator.validate(.text("ab"), against: optional).isValid)
        XCTAssertTrue(validator.validate(.text("WELCOME50"), against: optional).isValid)
    }

    // MARK: Checkboxes validate as strings

    func testRequiredCheckboxMustBeTicked() {
        let terms = field("terms", type: .checkbox, regex: "^true$")
        XCTAssertFalse(validator.validate(.bool(false), against: terms).isValid)
        XCTAssertTrue(validator.validate(.bool(true), against: terms).isValid)
    }

    // MARK: Server-supplied patterns are untrusted input

    func testMalformedServerPatternDoesNotBlockTheUser() {
        let broken = field("oops", regex: "^[a-z")     // will not compile
        XCTAssertTrue(validator.validate(.text("anything"), against: broken).isValid)
    }

    func testMissingPatternIsNoConstraint() {
        XCTAssertTrue(validator.validate(.text("anything"), against: field("a", regex: nil)).isValid)
        XCTAssertTrue(validator.validate(.text("anything"), against: field("a", regex: "")).isValid)
    }

    func testReadOnlyAndInvisibleFieldsAreNeverInvalid() {
        var f = field("a", regex: "^impossible$")
        f = FormField(id: f.id, identifier: f.identifier, name: f.name, labelKey: f.labelKey,
                      type: f.type, inputType: f.inputType, textStyle: f.textStyle,
                      validationMessageKey: f.validationMessageKey, isRequired: true,
                      isVisible: false, isReadOnly: false, regex: f.regex,
                      prefix: "", suffix: "", placeholderKey: "", dropdownOptions: [], radioOptions: [])
        XCTAssertTrue(validator.validate(.text(""), against: f).isValid)
    }

    // MARK: Named regexes (the ID-type → ID-number dependency)

    func testNamedRegexResolvesFromTheCatalogue() {
        XCTAssertEqual(validator.optionPattern("idNumberRegex"), "^[0-9]{13}$")
        XCTAssertNotNil(validator.optionPattern("passportNumberRegex"))
    }

    /// The passport pattern is invented (see `RegexCatalog.jpcDefaults`), so this asserts the
    /// *property* that matters rather than the literal: it must accept the shapes real
    /// passport numbers take. Rejecting a valid passport blocks a registration outright;
    /// accepting a bad one only costs a server round trip.
    func testPassportPatternAcceptsRealisticNumbers() {
        let pattern = validator.optionPattern("passportNumberRegex")!
        let expression = try! NSRegularExpression(pattern: pattern)
        func matches(_ value: String) -> Bool {
            expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        }
        for valid in ["A1234567", "123456789", "ZA1234567", "M12345678901"] {
            XCTAssertTrue(matches(valid), "should accept \(valid)")
        }
        for invalid in ["", "abc", "!!!!!!!!"] {
            XCTAssertFalse(matches(invalid), "should reject \(invalid)")
        }
    }

    func testLiteralPatternIsUsedAsIs() {
        XCTAssertEqual(validator.optionPattern("[a-zA-Z]"), "[a-zA-Z]")
    }

    func testOverrideRegexReplacesTheFieldRule() {
        let id = field("idNumber", regex: "^[0-9]{13}$")
        // Passport selected → 13-digit rule no longer applies.
        XCTAssertTrue(validator.validate(.text("A1234567"), against: id,
                                        overrideRegex: "^[a-zA-Z0-9]{6,12}$").isValid)
        XCTAssertFalse(validator.validate(.text("A1234567"), against: id).isValid)
    }

    // MARK: Password policy parsing

    func testPasswordRulesAreDerivedFromTheQuantifier() {
        let rules = PasswordPolicy().rules(for: field("password", inputType: .password, regex: "^(.){8,20}$"))
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0].fallbackDescription, "Minimum of 8 characters")
        XCTAssertEqual(rules[1].fallbackDescription, "Maximum of 20 characters")
        XCTAssertFalse(rules[0].isSatisfied(by: "short"))
        XCTAssertTrue(rules[0].isSatisfied(by: "longenough"))
        XCTAssertFalse(rules[1].isSatisfied(by: String(repeating: "a", count: 21)))
    }

    func testDateSerialisesToTheIso8601ShapeTheSchemaExpects() {
        let pattern = "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$"
        let dob = field("dateOfBirth", inputType: .calendar, regex: pattern)
        XCTAssertTrue(validator.validate(.date(Date(timeIntervalSince1970: 631152000)), against: dob).isValid)
    }
}
```

**48.** `JackpotKit/Tests/JackpotFormsTests/DynamicFormModelTests.swift`

```swift
import Combine
import XCTest
@testable import JackpotFormsUI
import JackpotFormsData
import JackpotFormsDomain

/// End-to-end validation behaviour against the real registration schema: what the user
/// actually experiences, rather than the regexes in isolation.
@MainActor
final class DynamicFormModelTests: XCTestCase {

    private func makeModel(delay: TimeInterval = 0) -> DynamicFormModel {
        let url = Bundle.module.url(forResource: "registration", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return DynamicFormModel(
            formName: .registration,
            dependencies: FormDependencies(
                repository: StubFormRepository(forms: [.registration: data], delay: delay)
            )
        )
    }

    private func loaded() async throws -> DynamicFormModel {
        let model = makeModel()
        model.load()
        try await waitUntil { model.form != nil }
        return model
    }

    private func waitUntil(timeout: TimeInterval = 2,
                           _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { XCTFail("Timed out"); return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func field(_ model: DynamicFormModel, _ id: String) throws -> FormField {
        try XCTUnwrap(model.form?.field(identifiedBy: id))
    }

    // MARK: Loading

    func testLoadsSchemaAndSeedsEveryField() async throws {
        let model = try await loaded()
        XCTAssertEqual(model.sections.count, 2)
        XCTAssertEqual(model.sectionIndex, 0)
        XCTAssertTrue(model.isFirstSection)
        XCTAssertFalse(model.isLastSection)
        // Checkboxes start false, not empty — so `terms` is correctly invalid up front.
        XCTAssertEqual(model.value(for: try field(model, "terms")), .bool(false))
    }

    // MARK: Errors appear only after the user has engaged

    func testUntouchedFieldsShowNoErrorEvenWhenInvalid() async throws {
        let model = try await loaded()
        let mobile = try field(model, "username")
        XCTAssertNil(model.error(for: mobile))          // empty + required, but untouched
        model.markTouched(mobile)
        XCTAssertNotNil(model.error(for: mobile))
    }

    func testAdvancingRevealsEveryErrorInTheSection() async throws {
        let model = try await loaded()
        XCTAssertFalse(model.advance())                  // blocked
        XCTAssertEqual(model.sectionIndex, 0)
        for id in ["username", "password", "firstname", "lastname", "email"] {
            XCTAssertNotNil(model.error(for: try field(model, id)), "\(id) should show an error")
        }
        // The optional referral code must NOT be flagged.
        XCTAssertNil(model.error(for: try field(model, "referralCode")))
    }

    // MARK: Section gating

    func testCannotAdvanceUntilSectionOneIsValid() async throws {
        let model = try await loaded()
        XCTAssertFalse(model.isCurrentSectionValid)

        try fillSectionOne(model)

        XCTAssertTrue(model.isCurrentSectionValid)
        XCTAssertTrue(model.advance())
        XCTAssertEqual(model.sectionIndex, 1)
        XCTAssertTrue(model.isLastSection)

        model.goBack()
        XCTAssertEqual(model.sectionIndex, 0)
    }

    // MARK: The ID-type → ID-number dependency

    func testPassportSelectionRelaxesTheThirteenDigitIdRule() async throws {
        let model = try await loaded()
        try fillSectionOne(model)
        _ = model.advance()

        let type = try field(model, "idNumberType")
        let number = try field(model, "idNumber")

        model.setValue(.option("idNumber"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNotNil(model.error(for: number), "SA ID must be 13 digits")

        model.setValue(.option("passport"), for: type)
        XCTAssertNil(model.error(for: number), "passport should accept an alphanumeric number")

        model.setValue(.option("idNumber"), for: type)
        XCTAssertNotNil(model.error(for: number), "switching back must re-apply the 13-digit rule")
    }

    // MARK: Submission

    func testSubmitIsBlockedWhileAnythingIsInvalid() async throws {
        let model = try await loaded()
        var called = false
        await model.submit { _ in called = true }
        XCTAssertFalse(called)
    }

    func testSubmitDeliversEveryValueKeyedByFieldIdentifier() async throws {
        let model = try await loaded()
        try fillSectionOne(model)
        _ = model.advance()
        try fillSectionTwo(model)

        XCTAssertTrue(model.isFormValid)

        var received: FormSubmission?
        await model.submit { received = $0 }

        let submission = try XCTUnwrap(received)
        XCTAssertEqual(submission.formCodeName, .registration)
        XCTAssertEqual(submission["username"].stringValue, "849134302")
        XCTAssertEqual(submission["firstname"].stringValue, "Malcolm")
        XCTAssertEqual(submission["idNumberType"].stringValue, "idNumber")
        XCTAssertEqual(submission["terms"].stringValue, "true")
        XCTAssertEqual(submission["receivePromotionalInformation"].stringValue, "false")
        // Untouched optional field still present, as an empty string.
        XCTAssertEqual(submission["referralCode"].stringValue, "")
    }

    func testSubmitSurfacesAThrownError() async throws {
        let model = try await loaded()
        try fillSectionOne(model)
        _ = model.advance()
        try fillSectionTwo(model)

        struct Boom: LocalizedError { var errorDescription: String? { "Registration failed" } }
        await model.submit { _ in throw Boom() }
        XCTAssertEqual(model.submitError, "Registration failed")
    }

    // MARK: Progress

    func testProgressTracksSatisfiedRequiredFields() async throws {
        let model = try await loaded()
        XCTAssertEqual(model.progress, 0, accuracy: 0.001)
        try fillSectionOne(model)
        XCTAssertGreaterThan(model.progress, 0.3)
        XCTAssertLessThan(model.progress, 1.0)
        _ = model.advance()
        try fillSectionTwo(model)
        XCTAssertEqual(model.progress, 1.0, accuracy: 0.001)
    }

    // MARK: Helpers

    private func fillSectionOne(_ model: DynamicFormModel) throws {
        model.setValue(.text("849134302"), for: try field(model, "username"))
        model.setValue(.text("Password1"), for: try field(model, "password"))
        model.setValue(.text("Malcolm"), for: try field(model, "firstname"))
        model.setValue(.text("Collin"), for: try field(model, "lastname"))
        model.setValue(.text("hi@example.com"), for: try field(model, "email"))
    }

    private func fillSectionTwo(_ model: DynamicFormModel) throws {
        model.setValue(.option("idNumber"), for: try field(model, "idNumberType"))
        model.setValue(.text("9001015800089"), for: try field(model, "idNumber"))
        model.setValue(.date(Date(timeIntervalSince1970: 631152000)), for: try field(model, "dateOfBirth"))
        model.setValue(.option("SalaryOrWages"), for: try field(model, "sourceOfFunds"))
        model.setValue(.bool(true), for: try field(model, "terms"))
    }

    // MARK: Render scheduling

    /// The return key marks the field on submit and the blur that follows marks it again.
    /// A second render there is what made the error appear a beat after focus moved.
    func testReTouchingAFieldSchedulesNoFurtherRender() async throws {
        let model = try await loaded()
        let mobile = try field(model, "username")
        var renders = 0
        let subscription = model.objectWillChange.sink { _ in renders += 1 }
        defer { subscription.cancel() }

        model.markTouched(mobile)
        XCTAssertEqual(renders, 1)
        model.markTouched(mobile)
        XCTAssertEqual(renders, 1)
    }

    func testTouchingByIdentifierRevealsTheErrorAndIgnoresUnknownFields() async throws {
        let model = try await loaded()
        let mobile = try field(model, "username")
        model.setValue(.text("123"), for: mobile)
        XCTAssertNil(model.error(for: mobile), "untouched, so still silent")

        model.markTouched(identifiedBy: "username")
        XCTAssertNotNil(model.error(for: mobile))

        model.markTouched(identifiedBy: "notAField")   // must not trap
    }

    // MARK: Return-key focus order

    func testFocusOrderCoversOnlyTextEntryInSchemaOrder() async throws {
        let model = try await loaded()
        XCTAssertEqual(model.focusableIdentifiers,
                       ["username", "password", "firstname", "lastname", "email", "referralCode"])
    }

    func testReturnWalksToTheNextFieldAndStopsAtTheEnd() async throws {
        let model = try await loaded()
        XCTAssertEqual(model.fieldAfter("username"), "password")
        XCTAssertEqual(model.fieldAfter("email"), "referralCode")
        XCTAssertNil(model.fieldAfter("referralCode"), "The last field dismisses rather than wrapping")
    }

    func testFocusOrderIgnoresUnknownAndAbsentFields() async throws {
        let model = try await loaded()
        XCTAssertNil(model.fieldAfter(nil))
        XCTAssertNil(model.fieldAfter("notAField"))
    }

    func testDateAndPickerFieldsAreNotKeyboardFocusable() async throws {
        let model = try await loaded()
        for identifier in ["dateOfBirth", "idNumberType", "sourceOfFunds", "terms"] {
            XCTAssertFalse(try field(model, identifier).acceptsKeyboardFocus,
                           "\(identifier) opens a picker or toggles, so the return key should skip it")
        }
    }
}

/// Confirmed behaviour: the ID Number Type dropdown selects whether the user is entering a
/// South African ID or a passport, and the ID Number field validates accordingly.
///
/// The link is declared in `FormDependencies.regexDependencies` rather than inferred from
/// field order, so a CRM reorder can't silently disable it on a regulated field.
@MainActor
final class IDTypeRegexDependencyTests: XCTestCase {

    private func loadedSectionTwo(
        regexDependencies: [String: String] = ["idNumberType": "idNumber"],
        appliesOptionRegex: Bool = true
    ) async throws -> DynamicFormModel {
        let url = Bundle.module.url(forResource: "registration", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let model = DynamicFormModel(
            formName: .registration,
            dependencies: FormDependencies(
                repository: StubFormRepository(forms: [.registration: data], delay: 0),
                appliesOptionRegexToDependentField: appliesOptionRegex,
                regexDependencies: regexDependencies
            )
        )
        model.load()
        let deadline = Date().addingTimeInterval(2)
        while model.form == nil {
            if Date() > deadline { XCTFail("timed out"); break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return model
    }

    private func field(_ model: DynamicFormModel, _ id: String) throws -> FormField {
        try XCTUnwrap(model.form?.field(identifiedBy: id))
    }

    func testSouthAfricanIDRequiresThirteenDigits() async throws {
        let model = try await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("idNumber"), for: type)
        model.setValue(.text("9001015800089"), for: number)
        model.markTouched(number)
        XCTAssertNil(model.error(for: number))

        model.setValue(.text("A1234567"), for: number)
        XCTAssertNotNil(model.error(for: number), "a passport number is not a valid SA ID")
    }

    func testPassportAcceptsAnAlphanumericNumber() async throws {
        let model = try await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("passport"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNil(model.error(for: number))
    }

    /// Switching type revalidates immediately — the user shouldn't have to re-type to see the
    /// rule change.
    func testSwitchingTypeRevalidatesWithoutRetyping() async throws {
        let model = try await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("idNumber"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNotNil(model.error(for: number))

        model.setValue(.option("passport"), for: type)
        XCTAssertNil(model.error(for: number), "switching to passport must clear the error")

        model.setValue(.option("idNumber"), for: type)
        XCTAssertNotNil(model.error(for: number), "switching back must re-apply the 13-digit rule")
    }

    /// A literal pattern on a dropdown option describes the *selection*, not another field.
    /// `sourceOfFunds` options carry `"[a-zA-Z]"`; that must never leak onto its neighbour.
    func testLiteralOptionPatternsDoNotLeakOntoOtherFields() async throws {
        let model = try await loadedSectionTwo()
        let source = try field(model, "sourceOfFunds")
        let promo = try field(model, "receivePromotionalInformation")

        model.setValue(.option("SalaryOrWages"), for: source)
        model.setValue(.bool(true), for: promo)
        model.markTouched(promo)
        XCTAssertNil(model.error(for: promo))
    }

    /// With the link declared, the rule survives a schema reorder. Without it, resolution falls
    /// back to field order — which is exactly the fragility the declaration removes.
    func testExplicitLinkIsNotPositional() async throws {
        let model = try await loadedSectionTwo(regexDependencies: ["idNumberType": "idNumber"])
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")
        model.setValue(.option("passport"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNil(model.error(for: number))
    }

    func testCanBeDisabledEntirely() async throws {
        let model = try await loadedSectionTwo(appliesOptionRegex: false)
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")
        model.setValue(.option("passport"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNotNil(model.error(for: number), "disabled → the field's own regex always applies")
    }
}
```

**49.**

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotForms

`Executed 46 tests, with 0 failures`

Open `DynamicFormView.swift` and resume the whole-form previews.

---

## PR 3 — JackpotCore + live repository

**55.**

```bash
mkdir -p Packages/JackpotCore/Sources/{JackpotNetworking,JackpotAppData,JackpotLocalization}
mkdir -p Packages/JackpotCore/Tests/{JackpotNetworkingTests,JackpotAppDataTests,JackpotLocalizationTests}
cd Packages/JackpotCore
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

**56.** `Packages/JackpotCore/Package.swift`

```swift
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "JackpotCore",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
    ],
    targets: [
        .target(name: "JackpotNetworking"),


        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),
    ]
)
```

**57.** `Packages/JackpotCore/Sources/JackpotNetworking/HTTPMethod.swift`

```swift
import Foundation

public enum HTTPMethod: String, Sendable {
    case GET, POST, PUT, PATCH, DELETE
}
```

**58.** `Packages/JackpotCore/Sources/JackpotNetworking/HTTPClient.swift`

```swift
import Foundation

public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public init(timeout: TimeInterval, waitsForConnectivity: Bool = false) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.waitsForConnectivity = waitsForConnectivity
        self.session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
```

**59.** `Packages/JackpotCore/Sources/JackpotNetworking/APIEnvironment.swift`

```swift
import Foundation

public struct APIEnvironment: Sendable {
    public let baseURL: URL
    public let defaultHeaders: [String: String]

    public let defaultQueryItems: [URLQueryItem]

    public init(baseURL: URL,
                defaultHeaders: [String: String] = ["Accept": "application/json"],
                defaultQueryItems: [URLQueryItem] = []) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.defaultQueryItems = defaultQueryItems
    }
}
```

**60.** `Packages/JackpotCore/Sources/JackpotNetworking/APIEndpoint.swift`

```swift
import Foundation

public enum RequestBody: Sendable {
    case json(Data)
    case form([String: String])

    public static func encodable<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) throws -> RequestBody {
        .json(try encoder.encode(value))
    }
}

public protocol APIEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: RequestBody? { get }

    var requiresAuth: Bool { get }

    var isIdempotent: Bool { get }
}

public extension APIEndpoint {
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
    var body: RequestBody? { nil }
    var requiresAuth: Bool { true }
    var isIdempotent: Bool { method == .GET }

    func urlRequest(in environment: APIEnvironment) throws -> URLRequest {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(
            url: environment.baseURL.appendingPathComponent(trimmed),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL(path)
        }

        let allQuery = environment.defaultQueryItems + queryItems
        if !allQuery.isEmpty { components.queryItems = allQuery }

        guard let url = components.url else { throw APIError.invalidURL(path) }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (key, value) in environment.defaultHeaders { request.setValue(value, forHTTPHeaderField: key) }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

        switch body {
        case .json(let data):
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .form(let fields):
            var form = URLComponents()
            form.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        case nil:
            break
        }
        return request
    }
}
```

**61.** `Packages/JackpotCore/Sources/JackpotNetworking/APIError.swift`

```swift
import Foundation

public struct APIProblem: Decodable, Sendable, Equatable {
    public let code: Int?
    public let message: String?

    public init(code: Int?, message: String?) {
        self.code = code
        self.message = message
    }

    private enum CodingKeys: String, CodingKey { case code, message }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedCode: Int?
        if let number = try? container.decodeIfPresent(Int.self, forKey: .code) {
            decodedCode = number
        } else {
            decodedCode = (try? container.decodeIfPresent(String.self, forKey: .code)).flatMap { $0.flatMap(Int.init) }
        }
        let decodedMessage = (try? container.decodeIfPresent(String.self, forKey: .message))?.flatMap {
            $0.isEmpty ? nil : $0
        }

        guard decodedCode != nil || decodedMessage != nil else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Not a problem envelope: neither `code` nor `message` present"
            ))
        }

        code = decodedCode
        message = decodedMessage
    }
}

public enum APIError: Error, Sendable, Equatable {
    case invalidURL(String)
    case transport(URLError.Code)

    case badRequest(APIProblem?)

    case unauthorized(APIProblem?)

    case server(APIProblem?)

    case unexpectedStatus(Int, APIProblem?)
    case decoding(String)
    case cancelled

    public var problem: APIProblem? {
        switch self {
        case .badRequest(let p), .unauthorized(let p), .server(let p), .unexpectedStatus(_, let p):
            return p
        case .invalidURL, .transport, .decoding, .cancelled:
            return nil
        }
    }

    public var serverMessage: String? {
        problem?.message.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var isOffline: Bool {
        guard case .transport(let code) = self else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut].contains(code)
    }
}
```

**62.** `Packages/JackpotCore/Sources/JackpotNetworking/RequestInterceptor.swift`

```swift
import Foundation

public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest

    func retry(_ request: URLRequest,
               for endpoint: any APIEndpoint,
               response: HTTPURLResponse,
               data: Data) async -> URLRequest?
}

public extension RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest { request }
    func retry(_ request: URLRequest,
               for endpoint: any APIEndpoint,
               response: HTTPURLResponse,
               data: Data) async -> URLRequest? { nil }
}

public struct BearerTokenInterceptor: RequestInterceptor {
    private let token: @Sendable () async -> String?

    public init(token: @escaping @Sendable () async -> String?) {
        self.token = token
    }

    public func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest {
        guard endpoint.requiresAuth, let token = await token() else { return request }
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
```

**63.** `Packages/JackpotCore/Sources/JackpotNetworking/RemoteApiClient.swift`

```swift
import Foundation

public protocol ApiClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response

    func request(_ endpoint: some APIEndpoint) async throws

    func requestData(_ endpoint: some APIEndpoint) async throws -> Data
}

public struct RemoteApiClient: ApiClient {
    private let environment: APIEnvironment
    private let httpClient: any HTTPClient
    private let interceptors: [any RequestInterceptor]
    private let decoder: JSONDecoder
    private let maxTransientRetries: Int

    public init(environment: APIEnvironment,
                httpClient: any HTTPClient = URLSessionHTTPClient(),
                interceptors: [any RequestInterceptor] = [],
                decoder: JSONDecoder = JSONDecoder(),
                maxTransientRetries: Int = 1) {
        self.environment = environment
        self.httpClient = httpClient
        self.interceptors = interceptors
        self.decoder = decoder
        self.maxTransientRetries = maxTransientRetries
    }

    public func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response {
        let data = try await perform(endpoint)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding("\(Response.self): \(error)")
        }
    }

    public func request(_ endpoint: some APIEndpoint) async throws {
        _ = try await perform(endpoint)
    }

    public func requestData(_ endpoint: some APIEndpoint) async throws -> Data {
        try await perform(endpoint)
    }

    private func perform(_ endpoint: some APIEndpoint) async throws -> Data {
        var request = try endpoint.urlRequest(in: environment)
        for interceptor in interceptors {
            request = try await interceptor.adapt(request, for: endpoint)
        }
        return try await send(request, for: endpoint, didRetryAuth: false, transientRetries: 0)
    }

    private func send(_ request: URLRequest,
                      for endpoint: some APIEndpoint,
                      didRetryAuth: Bool,
                      transientRetries: Int) async throws -> Data {
        let (data, response) = try await transport(request)

        switch response.statusCode {
        case 200..<300:
            return data

        case 401:

            if !didRetryAuth {
                for interceptor in interceptors {
                    if let retry = await interceptor.retry(request, for: endpoint, response: response, data: data) {
                        return try await send(retry, for: endpoint, didRetryAuth: true, transientRetries: transientRetries)
                    }
                }
            }
            throw APIError.unauthorized(problem(from: data))

        case 400:
            throw APIError.badRequest(problem(from: data))

        case 500:

            if endpoint.isIdempotent, transientRetries < maxTransientRetries {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await send(request, for: endpoint, didRetryAuth: didRetryAuth,
                                      transientRetries: transientRetries + 1)
            }
            throw APIError.server(problem(from: data))

        default:

            if (502...504).contains(response.statusCode),
               endpoint.isIdempotent,
               transientRetries < maxTransientRetries {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await send(request, for: endpoint, didRetryAuth: didRetryAuth,
                                      transientRetries: transientRetries + 1)
            }
            throw APIError.unexpectedStatus(response.statusCode, problem(from: data))
        }
    }

    private func transport(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await httpClient.send(request)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch let error as URLError {
            throw APIError.transport(error.code)
        }
    }

    private func problem(from data: Data) -> APIProblem? {
        try? JSONDecoder().decode(APIProblem.self, from: data)
    }
}
```

**64.** `Packages/JackpotCore/Tests/JackpotNetworkingTests/MockHTTPClient.swift`

```swift
import Foundation
import XCTest
@testable import JackpotNetworking

actor MockHTTPClient: HTTPClient {
    struct Stub {
        var data: Data
        var statusCode: Int
        var headers: [String: String]
        var error: (any Error)?

        static func ok(_ json: String, status: Int = 200) -> Stub {
            Stub(data: Data(json.utf8), statusCode: status, headers: [:], error: nil)
        }
        static func status(_ code: Int, json: String = "{}", headers: [String: String] = [:]) -> Stub {
            Stub(data: Data(json.utf8), statusCode: code, headers: headers, error: nil)
        }
        static func failure(_ error: any Error) -> Stub {
            Stub(data: Data(), statusCode: 0, headers: [:], error: error)
        }
    }

    private(set) var requests: [URLRequest] = []
    private var queue: [Stub]
    private let fallback: Stub

    init(_ stubs: [Stub], fallback: Stub = .status(500)) {
        self.queue = stubs
        self.fallback = fallback
    }

    convenience init(_ stub: Stub) { self.init([stub], fallback: stub) }

    var requestCount: Int { requests.count }

    func assertRequests(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(requests.count, expected, file: file, line: line)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let stub = queue.isEmpty ? fallback : queue.removeFirst()
        if let error = stub.error { throw error }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: stub.headers
        )!
        return (stub.data, response)
    }
}

struct Widget: Decodable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct WidgetRequest: APIEndpoint {
    var path: String { "widgets/42" }
}

struct CreateWidgetRequest: APIEndpoint {
    let name: String
    var path: String { "widgets" }
    var method: HTTPMethod { .POST }
    var body: RequestBody? { .form(["name": name]) }
}

struct SearchRequest: APIEndpoint {
    let term: String
    var path: String { "search" }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "q", value: term)] }
}

extension APIEnvironment {
    static let test = APIEnvironment(
        baseURL: URL(string: "https://api.example.com/v1")!,
        defaultHeaders: ["Accept": "application/json"],
        defaultQueryItems: [URLQueryItem(name: "api-version", value: "2.0")]
    )
}
```

**65.** `Packages/JackpotCore/Tests/JackpotNetworkingTests/APIEndpointTests.swift`

```swift
import XCTest
@testable import JackpotNetworking

final class APIEndpointTests: XCTestCase {
    func testBuildsURLFromEnvironmentAndPath() throws {
        let request = try WidgetRequest().urlRequest(in: .test)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.example.com/v1/widgets/42?api-version=2.0")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testMergesEnvironmentAndEndpointQueryItems() throws {
        let request = try SearchRequest(term: "swift").urlRequest(in: .test)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.map(\.name), ["api-version", "q"])
        XCTAssertEqual(components.queryItems?.last?.value, "swift")
    }

    func testLeadingSlashInPathDoesNotBreakTheURL() throws {
        struct Slashed: APIEndpoint { var path: String { "/widgets" } }
        let request = try Slashed().urlRequest(in: .test)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.example.com/v1/widgets?api-version=2.0")
    }

    func testFormBodyIsPercentEncodedWithTheRightContentType() throws {
        let request = try CreateWidgetRequest(name: "a b&c").urlRequest(in: .test)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(body, "name=a%20b%26c")
    }

    func testJSONBodySetsContentType() throws {
        struct JSONPost: APIEndpoint {
            var path: String { "x" }
            var method: HTTPMethod { .POST }
            var body: RequestBody? { .json(Data(#"{"a":1}"#.utf8)) }
        }
        let request = try JSONPost().urlRequest(in: .test)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testDefaultsAreSaneWithoutOverrides() {
        let endpoint = WidgetRequest()
        XCTAssertEqual(endpoint.method, .GET)
        XCTAssertTrue(endpoint.queryItems.isEmpty)
        XCTAssertNil(endpoint.body)
        XCTAssertTrue(endpoint.requiresAuth)
        XCTAssertTrue(endpoint.isIdempotent)
    }

    func testPostIsNotIdempotentByDefault() {
        XCTAssertFalse(CreateWidgetRequest(name: "x").isIdempotent)
    }
}
```

**66.** `Packages/JackpotCore/Tests/JackpotNetworkingTests/APIProblemTests.swift`

```swift
import XCTest
@testable import JackpotNetworking

final class APIProblemTests: XCTestCase {
    private func decode(_ json: String) -> APIProblem? {
        try? JSONDecoder().decode(APIProblem.self, from: Data(json.utf8))
    }

    func testTheDocumentedShape() {
        XCTAssertEqual(decode(#"{"code":0,"message":"Error message"}"#),
                       APIProblem(code: 0, message: "Error message"))
    }

    func testNonZeroCode() {
        XCTAssertEqual(decode(#"{"code":1042,"message":"Mobile already registered"}"#)?.code, 1042)
    }

    func testStringCodeIsCoerced() {
        XCTAssertEqual(decode(#"{"code":"42","message":"x"}"#)?.code, 42)
    }

    func testMessageOnly() {
        XCTAssertEqual(decode(#"{"message":"Just a message"}"#),
                       APIProblem(code: nil, message: "Just a message"))
    }

    func testCodeOnly() {
        XCTAssertEqual(decode(#"{"code":7}"#), APIProblem(code: 7, message: nil))
    }

    func testEmptyObjectIsNotAProblem() {
        XCTAssertNil(decode("{}"), "an empty body is 'the server said nothing', not an empty complaint")
    }

    func testEmptyMessageIsTreatedAsAbsent() {
        XCTAssertNil(decode(#"{"message":""}"#))
    }

    func testUnrelatedJSONIsNotAProblem() {
        XCTAssertNil(decode(#"{"data":{"id":1}}"#))
    }

    func testHTMLFromAGatewayIsNotAProblem() {
        XCTAssertNil(decode("<html><body>503</body></html>"))
    }

    func testExtraFieldsAreIgnored() {
        XCTAssertEqual(decode(#"{"code":3,"message":"m","traceId":"abc","status":400}"#),
                       APIProblem(code: 3, message: "m"))
    }
}
```

**67.** `Packages/JackpotCore/Tests/JackpotNetworkingTests/RemoteApiClientTests.swift`

```swift
import XCTest
@testable import JackpotNetworking

final class RemoteApiClientTests: XCTestCase {
    private func client(_ http: MockHTTPClient,
                        interceptors: [any RequestInterceptor] = []) -> RemoteApiClient {
        RemoteApiClient(environment: .test, httpClient: http, interceptors: interceptors)
    }

    func testDecodesA200() async throws {
        let http = MockHTTPClient(.ok(#"{"id":42,"name":"Sprocket"}"#))
        let widget: Widget = try await client(http).request(WidgetRequest())
        XCTAssertEqual(widget, Widget(id: 42, name: "Sprocket"))
        await http.assertRequests(1)
    }

    func testEmptyBodyRequestIgnoresThePayload() async throws {
        let http = MockHTTPClient(.status(204))
        try await client(http).request(WidgetRequest())
        await http.assertRequests(1)
    }

    func test400CarriesTheServersMessage() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":1042,"message":"Mobile number already registered"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            guard case .badRequest(let problem) = error as? APIError else {
                return XCTFail("expected .badRequest, got \(error)")
            }
            XCTAssertEqual(problem, APIProblem(code: 1042, message: "Mobile number already registered"))
            XCTAssertEqual((error as? APIError)?.serverMessage, "Mobile number already registered")
        }
    }

    func testNumericZeroCodeDecodes() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":0,"message":"Error message"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual((error as? APIError)?.problem, APIProblem(code: 0, message: "Error message"))
        }
    }

    func testStringCodeAlsoDecodes() async {
        let http = MockHTTPClient(.status(400, json: #"{"code":"7","message":"x"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual((error as? APIError)?.problem?.code, 7)
        }
    }

    func testNonJSONErrorBodyStillReportsTheStatus() async {
        let http = MockHTTPClient(.status(400, json: "<html>502 Bad Gateway</html>"))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .badRequest(nil))
            XCTAssertNil((error as? APIError)?.serverMessage)
        }
    }

    func test500CarriesTheProblemAfterRetrying() async {
        let http = MockHTTPClient([.status(500), .status(500, json: #"{"code":9,"message":"Down"}"#)])
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .server(APIProblem(code: 9, message: "Down")))
        }
        await http.assertRequests(2)
    }

    func test500DoesNotRetryANonIdempotentRequest() async {
        let http = MockHTTPClient([.status(500), .ok(#"{"id":1,"name":"x"}"#)])
        await AssertThrows(try await client(http).request(CreateWidgetRequest(name: "x")) as Widget) { error in
            XCTAssertEqual(error as? APIError, .server(nil))
        }
        await http.assertRequests(1)
    }

    func test404IsReportedAsUnexpectedRatherThanFlattenedIntoServer() async {
        let http = MockHTTPClient(.status(404))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(404, nil))
        }
        await http.assertRequests(1)
    }

    func testGatewayErrorsRetryOnceThenReportTheirRealStatus() async {
        let http = MockHTTPClient([.status(503), .status(503)])
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(503, nil))
        }
        await http.assertRequests(2)
    }

    func testMalformedJSONSurfacesAsDecodingWithTheTypeName() async {
        let http = MockHTTPClient(.ok(#"{"id":"not-an-int"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            guard case .decoding(let message) = error as? APIError else {
                return XCTFail("expected .decoding, got \(error)")
            }

            XCTAssertTrue(message.contains("Widget"), message)
        }
    }

    func testOfflineMapsToTransportAndIsFlaggedOffline() async {
        let http = MockHTTPClient(.failure(URLError(.notConnectedToInternet)))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .transport(.notConnectedToInternet))
            XCTAssertTrue((error as? APIError)?.isOffline == true)
        }
    }

    func testURLErrorCancelledMapsToCancelled() async {
        let http = MockHTTPClient(.failure(URLError(.cancelled)))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .cancelled)
        }
    }

    func test401RetriesOnceWithTheRefreshedToken() async throws {
        let http = MockHTTPClient([.status(401), .ok(#"{"id":1,"name":"ok"}"#)])
        let interceptor = StubAuthInterceptor(refreshedToken: "new-token")
        let widget: Widget = try await client(http, interceptors: [interceptor]).request(WidgetRequest())

        XCTAssertEqual(widget.name, "ok")
        await http.assertRequests(2)
        let retried = await http.requests[1]
        XCTAssertEqual(retried.value(forHTTPHeaderField: "Authorization"), "Bearer new-token")
    }

    func testSecond401GivesUpAsUnauthorized() async {
        let http = MockHTTPClient([.status(401), .status(401), .status(401)])
        let interceptor = StubAuthInterceptor(refreshedToken: "new-token")
        await AssertThrows(try await client(http, interceptors: [interceptor]).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unauthorized(nil))
        }
        await http.assertRequests(2)
    }

    func test401WithNoInterceptorFailsImmediately() async {
        let http = MockHTTPClient(.status(401))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unauthorized(nil))
        }
        await http.assertRequests(1)
    }

    func testBearerTokenIsAttachedButNotToAuthExemptEndpoints() async throws {
        struct LoginRequest: APIEndpoint {
            var path: String { "auth/login" }
            var method: HTTPMethod { .POST }
            var requiresAuth: Bool { false }
        }
        let http = MockHTTPClient([.ok(#"{"id":1,"name":"a"}"#), .ok(#"{"id":1,"name":"a"}"#)])
        let sut = client(http, interceptors: [BearerTokenInterceptor { "abc" }])

        _ = try await sut.request(WidgetRequest()) as Widget
        _ = try await sut.request(LoginRequest()) as Widget

        let widgetAuth = await http.requests[0].value(forHTTPHeaderField: "Authorization")
        let loginAuth  = await http.requests[1].value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(widgetAuth, "Bearer abc")
        XCTAssertNil(loginAuth, "a login request must never carry a bearer token")
    }
}

private struct StubAuthInterceptor: RequestInterceptor {
    let refreshedToken: String

    func retry(_ request: URLRequest, for endpoint: any APIEndpoint,
               response: HTTPURLResponse, data: Data) async -> URLRequest? {
        guard response.statusCode == 401 else { return nil }
        var retry = request
        retry.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
        return retry
    }
}

private func AssertThrows<T>(_ expression: @autoclosure () async throws -> T,
                             file: StaticString = #filePath, line: UInt = #line,
                             _ verify: (any Error) -> Void) async {
    do {
        _ = try await expression()
        XCTFail("expected a thrown error", file: file, line: line)
    } catch {
        verify(error)
    }
}
```

**68.**

```bash
cd Packages/JackpotCore && swift test
```

Now add the live repository to JackpotForms.

**69.** `Packages/JackpotForms/Package.swift` — replace with:

```swift
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "JackpotForms",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [

        .library(
            name: "JackpotForms",
            targets: ["JackpotForms", "JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI", "JackpotFormsRemote"]
        ),
    ],
    dependencies: [
        .package(path: "../JackpotUI"),
        .package(path: "../JackpotCore"),
    ],
    targets: [

        .target(name: "JackpotFormsDomain"),

        .target(name: "JackpotFormsData", dependencies: ["JackpotFormsDomain"]),

        .target(
            name: "JackpotFormsUI",
            dependencies: [
                "JackpotFormsDomain",
                .product(name: "JackpotUI", package: "JackpotUI"),
            ],
            resources: [.process("Resources")]
        ),

        .target(
            name: "JackpotFormsRemote",
            dependencies: [
                "JackpotFormsDomain",
                "JackpotFormsData",
                .product(name: "JackpotNetworking", package: "JackpotCore"),
            ]
        ),

        .target(
            name: "JackpotForms",
            dependencies: [
                "JackpotFormsData",
                "JackpotFormsUI",
                "JackpotFormsRemote",
                .product(name: "JackpotLocalization", package: "JackpotCore"),
            ]
        ),

        .testTarget(
            name: "JackpotFormsTests",
            dependencies: ["JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI",
                           "JackpotFormsRemote", "JackpotForms"],
            resources: [.process("Fixtures")]
        ),
    ]
)
```

**70.** `Packages/JackpotForms/Sources/JackpotFormsRemote/CRMEnvironment.swift`

```swift
import Foundation
import JackpotNetworking

public extension APIEnvironment {
    static func crm(baseURL: URL, apiVersion: String = "2.0") -> APIEnvironment {
        APIEnvironment(
            baseURL: baseURL,
            defaultHeaders: ["Accept": "application/json"],
            defaultQueryItems: [URLQueryItem(name: "api-version", value: apiVersion)]
        )
    }
}
```

**71.** `Packages/JackpotForms/Sources/JackpotFormsRemote/FormEndpoints.swift`

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain

public struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    public init(brand: String, region: String, formName: FormName) {
        self.brand = brand
        self.region = region
        self.formName = formName
    }

    public var path: String { "forms/\(brand)/\(region)/\(formName.rawValue)" }
    public var method: HTTPMethod { .GET }
}
```

**72.** `Packages/JackpotForms/Sources/JackpotFormsRemote/FormErrorMapper.swift`

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain

enum FormErrorMapper {
    static func map(_ error: any Error,
                    formName: FormName,
                    localizer: (any FormLocalizing)? = nil) -> any Error {
        guard let apiError = error as? APIError else { return error }

        switch apiError {
        case .cancelled:

            return CancellationError()

        case .transport where apiError.isOffline:
            return FormLoadError.offline

        case .unexpectedStatus(404, _):
            return FormLoadError.notFound(formName)

        case .badRequest, .unauthorized, .server, .unexpectedStatus:

            if let code = apiError.problem?.code,
               let localized = localizer?.message(forErrorCode: code) {
                return FormLoadError.server(message: localized)
            }
            if let message = apiError.serverMessage {
                return FormLoadError.server(message: message)
            }
            return FormLoadError.unexpected

        case .transport, .decoding, .invalidURL:
            return FormLoadError.unexpected
        }
    }
}
```

**73.** `Packages/JackpotForms/Sources/JackpotFormsRemote/RemoteFormRepository.swift`

```swift
import Foundation
import JackpotNetworking
import JackpotFormsData
import JackpotFormsDomain

public struct RemoteFormRepository: FormRepository {
    private let apiClient: any ApiClient
    private let brand: String
    private let region: String

    private let localizer: (any FormLocalizing)?

    public init(apiClient: any ApiClient,
                brand: String = "jackpotcity",
                region: String = "JZA",
                localizer: (any FormLocalizing)? = nil) {
        self.apiClient = apiClient
        self.brand = brand
        self.region = region
        self.localizer = localizer
    }

    public func form(named name: FormName) async throws -> FormSchema {
        do {
            let dto: FormDTO = try await apiClient.request(
                FormRequest(brand: brand, region: region, formName: name)
            )
            return FormMapper.map(dto)
        } catch {
            throw FormErrorMapper.map(error, formName: name, localizer: localizer)
        }
    }
}
```

**74.** `Packages/JackpotForms/Sources/JackpotForms/TranslationsLocalizer.swift`

```swift
import Foundation
import JackpotLocalization
import JackpotFormsDomain

public struct TranslationsLocalizer: FormLocalizing {
    private let translations: Translations

    public init(_ translations: Translations) {
        self.translations = translations
    }

    public func string(forKey key: String) -> String? {
        translations.string(forKey: key, regional: true)
    }

    public func message(forErrorCode code: Int) -> String? {
        translations.message(forErrorCode: code)
    }
}

public extension FormLocalizing where Self == TranslationsLocalizer {
    static func translations(_ table: Translations) -> TranslationsLocalizer {
        TranslationsLocalizer(table)
    }
}
```

**75.** `Packages/JackpotForms/Sources/JackpotForms/JackpotForms.swift`

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain
import JackpotFormsUI
import JackpotLocalization
import JackpotFormsData
import JackpotFormsRemote

public extension FormDependencies {
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     translations: Translations? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: FormPreviewData.bundledForms, delay: delay, error: error),
            localizer: localizer
                ?? translations.map(TranslationsLocalizer.init)
                ?? ComposedKeyLocalizer.jpcRegistration
        )
    }

    static func live(baseURL: URL,
                     translations: Translations = Translations(),
                     brand: String = "jackpotcity",
                     region: String = "JZA",
                     bearerToken: (@Sendable () async -> String?)? = nil,
                     localizer explicitLocalizer: (any FormLocalizing)? = nil) -> FormDependencies {
        let interceptors: [any RequestInterceptor] = bearerToken.map { [BearerTokenInterceptor(token: $0)] } ?? []
        let client = RemoteApiClient(
            environment: .crm(baseURL: baseURL),
            interceptors: interceptors
        )

        let localizer: any FormLocalizing = explicitLocalizer
            ?? (translations.isEmpty ? ComposedKeyLocalizer.jpcRegistration : TranslationsLocalizer(translations))

        return FormDependencies(
            repository: RemoteFormRepository(apiClient: client, brand: brand, region: region,
                                           localizer: localizer),
            localizer: localizer
        )
    }
}

public extension FormSandboxView {
    static func mocked() -> FormSandboxView {
        FormSandboxView(
            samples: [
                .init(id: .registration, title: "Registration"),
                .init(id: .kitchenSink, title: "All field types"),
            ],
            dependencies: .mock()
        )
    }
}
```

**76.** `Packages/JackpotForms/Sources/JackpotForms/Previews.swift`

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsData
import JackpotNetworking
import JackpotFormsUI

struct MockedForm_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DynamicFormView(formName: .registration) { _ in }
                .formDependencies(.mock(delay: 0))
                .previewDisplayName("Registration — from JSON")

            DynamicFormView(formName: .kitchenSink) { _ in }
                .formDependencies(.mock(delay: 0))
                .previewDisplayName("All field types — from JSON")

            DynamicFormView(formName: .registration) { _ in }
                .formDependencies(.mock(delay: 3600))
                .previewDisplayName("Loading")

            DynamicFormView(formName: .registration) { _ in }
                .formDependencies(.mock(delay: 0, error: APIError.transport(.notConnectedToInternet)))
                .previewDisplayName("Offline")

            DynamicFormView(formName: FormName("doesNotExist")) { _ in }
                .formDependencies(.mock(delay: 0))
                .previewDisplayName("Unknown form — 404")
        }
        .frame(height: 620)
        .background(JackpotTheme.jackpotCity.surface)
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}

struct MockedSandbox_Previews: PreviewProvider {
    static var previews: some View {
        FormSandboxView.mocked()
            .preferredColorScheme(.dark)
            .previewDisplayName("Sandbox — the testing page")
    }
}
#endif
```

Append the remaining suites to `Tests/JackpotFormsTests/FormDecodingTests.swift`, and add the two imports at the top of that file:

```swift
@testable import JackpotFormsRemote
import JackpotLocalization
import JackpotForms
```

**77.** append to `Packages/JackpotForms/Tests/JackpotFormsTests/FormDecodingTests.swift`

```swift
final class CRMEnvironmentTests: XCTestCase {
    private let baseURL = URL(string: "https://config.jpc.africa/crm")!

    func testBuildsTheURLFromTheTicket() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: .registration)
            .urlRequest(in: .crm(baseURL: baseURL))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://config.jpc.africa/crm/forms/jackpotcity/JZA/registration?api-version=2.0")
    }

    func testApiVersionIsOverridable() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: .registration)
            .urlRequest(in: .crm(baseURL: baseURL, apiVersion: "3.0"))
        XCTAssertTrue(request.url?.absoluteString.hasSuffix("api-version=3.0") == true)
    }

    func testServerAuthoredFormNameLandsInThePath() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: FormName("deposit"))
            .urlRequest(in: .crm(baseURL: baseURL))
        XCTAssertTrue(request.url?.path.hasSuffix("/deposit") == true)
    }
}

final class FormErrorMappingTests: XCTestCase {
    func testServerMessageSurvivesToTheUserFacingString() {
        let apiError = APIError.badRequest(APIProblem(code: 1042, message: "Mobile number already registered"))
        let mapped = FormErrorMapper.map(apiError, formName: .registration)
        XCTAssertEqual((mapped as? FormLoadError), .server(message: "Mobile number already registered"))
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Mobile number already registered")
    }

    func testA400WithNoMessageFallsBackRatherThanShowingNothing() {
        let mapped = FormErrorMapper.map(APIError.badRequest(nil), formName: .registration)
        XCTAssertEqual(mapped as? FormLoadError, .unexpected)
        XCTAssertNotNil((mapped as? LocalizedError)?.errorDescription)
    }

    func testOfflineGetsItsOwnMessage() {
        let mapped = FormErrorMapper.map(APIError.transport(.notConnectedToInternet), formName: .registration)
        XCTAssertEqual(mapped as? FormLoadError, .offline)
    }

    func testUnknownFormBecomesNotFound() {
        let mapped = FormErrorMapper.map(APIError.unexpectedStatus(404, nil), formName: FormName("deposit"))
        XCTAssertEqual(mapped as? FormLoadError, .notFound(FormName("deposit")))
    }

    func testCancellationStaysCancellation() {
        XCTAssertTrue(FormErrorMapper.map(APIError.cancelled, formName: .registration) is CancellationError)
    }

    func testNonAPIErrorsPassThroughUntouched() {
        struct Custom: LocalizedError { var errorDescription: String? { "custom" } }
        let mapped = FormErrorMapper.map(Custom(), formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "custom")
    }

    func testServerErrorPrefersTheServersWordingOverOurs() {
        let mapped = FormErrorMapper.map(APIError.server(APIProblem(code: 0, message: "Scheduled maintenance")),
                                         formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Scheduled maintenance")
    }
}

final class LocalizedErrorMappingTests: XCTestCase {
    private let translations = Translations([
        "6000328": "Maximum OTP tries reached, Please contact support on +233 30 825 5838",
        "1042": "Hierdie selfoonnommer is reeds geregistreer",
    ], regionCode: "JZA")

    func testErrorCodeResolvesToLocalisedCopy() {
        let error = APIError.badRequest(APIProblem(code: 6000328, message: "Max OTP tries"))
        let mapped = FormErrorMapper.map(error, formName: .registration, localizer: TranslationsLocalizer(translations))
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription,
                       "Maximum OTP tries reached, Please contact support on +233 30 825 5838")
    }

    func testLocalisedCopyBeatsTheServersMessage() {
        let error = APIError.badRequest(APIProblem(code: 1042, message: "Mobile number already registered"))
        let mapped = FormErrorMapper.map(error, formName: .registration, localizer: TranslationsLocalizer(translations))
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription,
                       "Hierdie selfoonnommer is reeds geregistreer")
    }

    func testUnknownCodeFallsBackToTheServersMessage() {
        let error = APIError.badRequest(APIProblem(code: 999999, message: "Something specific"))
        let mapped = FormErrorMapper.map(error, formName: .registration, localizer: TranslationsLocalizer(translations))
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Something specific")
    }

    func testNoCodeAndNoMessageFallsBackToOurs() {
        let mapped = FormErrorMapper.map(APIError.badRequest(nil), formName: .registration,
                                         localizer: TranslationsLocalizer(translations))
        XCTAssertEqual(mapped as? FormLoadError, .unexpected)
    }

    func testEmptyTableDegradesToTheServersMessage() {
        let error = APIError.badRequest(APIProblem(code: 6000328, message: "Max OTP tries"))
        let mapped = FormErrorMapper.map(error, formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Max OTP tries")
    }
}

final class TranslationsAsFormLocalizerTests: XCTestCase {
    private let translations = Translations([
        "username": "Enter Mobile Number",
        "jpc-reg-idnumber": "South African ID",
        "receivePromotionalInformation-jza": "Send Jackpot City Promotions to me",
        "terms": "I am over 18 years of age & I accept the Terms & Conditions",
    ], regionCode: "JZA")

    private var localizer: any FormLocalizing { TranslationsLocalizer(translations) }

    func testFieldLabelKeyResolves() {
        XCTAssertEqual(localizer.display("username"), "Enter Mobile Number")
    }

    func testDropdownOptionKeyResolves() {
        XCTAssertEqual(localizer.display("jpc-reg-idnumber"), "South African ID")
    }

    func testPreSuffixedKeyResolves() {
        XCTAssertEqual(localizer.display("receivePromotionalInformation-jza"),
                       "Send Jackpot City Promotions to me")
    }

    func testMissingKeyIsVisibleNotBlank() {
        XCTAssertEqual(localizer.display("dateOfBirth"), "Date Of Birth")
    }
}
```

**78.**

```bash
cd Packages/JackpotCore && swift test
cd ../JackpotForms && xcodebuild -scheme JackpotForms -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotCore + live repository

JackpotCore: `Executed 34 tests, with 0 failures`
JackpotForms: `Executed 61 tests, with 0 failures`

---

## PR 4 — JackpotRegistration

**79.**

```bash
mkdir -p Packages/JackpotRegistration/Sources/JackpotRegistration Packages/JackpotRegistration/Tests/JackpotRegistrationTests
cd Packages/JackpotRegistration
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

**80.** `Packages/JackpotRegistration/Package.swift`

```swift
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "JackpotRegistration",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
    ],
    dependencies: [
        .package(path: "../JackpotUI"),
        .package(path: "../JackpotForms"),
        .package(path: "../JackpotCore"),
    ],
    targets: [
        .target(
            name: "JackpotRegistration",
            dependencies: [
                .product(name: "JackpotUI", package: "JackpotUI"),
                .product(name: "JackpotForms", package: "JackpotForms"),
                .product(name: "JackpotNetworking", package: "JackpotCore"),
            ]
        ),
        .testTarget(name: "JackpotRegistrationTests", dependencies: ["JackpotRegistration"]),
    ]
)
```

**81.** `Packages/JackpotRegistration/Sources/JackpotRegistration/RegistrationService.swift`

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain
import JackpotForms

public protocol RegistrationService: Sendable {
    func register(_ submission: FormSubmission) async throws -> RegistrationResult
}

public struct RegistrationResult: Equatable, Sendable {
    public let accountNumber: String?
    public let requiresOTP: Bool

    public init(accountNumber: String?, requiresOTP: Bool) {
        self.accountNumber = accountNumber
        self.requiresOTP = requiresOTP
    }
}

public struct MockRegistrationService: RegistrationService {
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.6) { self.delay = delay }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if submission["username"].stringValue == "0000000000" {
            throw RegistrationError.mobileAlreadyRegistered
        }
        return RegistrationResult(accountNumber: "27\(submission["username"].stringValue)", requiresOTP: true)
    }
}

public struct RemoteRegistrationService: RegistrationService {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) { self.apiClient = apiClient }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        do {
            let dto: RegisterResponseDTO = try await apiClient.request(RegisterRequest(fields: submission.stringValues))
            return RegistrationResult(accountNumber: dto.accountNumber, requiresOTP: dto.requiresOtp ?? false)
        } catch let error as APIError {
            throw RegistrationError(error)
        }
    }
}

struct RegisterRequest: APIEndpoint {
    let fields: [String: String]
    var path: String { "registration" }
    var method: HTTPMethod { .POST }
    var body: RequestBody? { try? .encodable(fields) }
    var requiresAuth: Bool { false }
}

struct RegisterResponseDTO: Decodable, Sendable {
    let accountNumber: String?
    let requiresOtp: Bool?
}

public enum RegistrationError: LocalizedError, Equatable {
    case mobileAlreadyRegistered
    case offline
    case server(message: String)
    case unexpected

    init(_ apiError: APIError) {
        if apiError.isOffline { self = .offline; return }
        switch apiError {
        case .badRequest(let problem) where problem?.code == 1042:
            self = .mobileAlreadyRegistered
        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            if let message = apiError.serverMessage { self = .server(message: message) } else { self = .unexpected }
        default:
            self = .unexpected
        }
    }

    public var errorDescription: String? {
        switch self {
        case .mobileAlreadyRegistered: return "That mobile number is already registered. Try logging in instead."
        case .offline:                 return "You're offline. Check your connection and try again."
        case .server(let message):     return message
        case .unexpected:              return "Something went wrong. Please try again."
        }
    }
}
```

**82.** `Packages/JackpotRegistration/Sources/JackpotRegistration/RegistrationFeature.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsUI
import JackpotForms

public struct RegistrationDependencies {
    public var forms: FormDependencies

    public var service: any RegistrationService
    public var theme: JackpotTheme

    public init(forms: FormDependencies,
                service: any RegistrationService,
                theme: JackpotTheme = .jackpotCity) {
        self.forms = forms
        self.service = service
        self.theme = theme
    }

    public static func mock(localizer: (any FormLocalizing)? = nil) -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock(localizer: localizer), service: MockRegistrationService())
    }
}

public struct RegistrationView: View {
    private let dependencies: RegistrationDependencies
    private let onComplete: (RegistrationResult) -> Void

    public init(dependencies: RegistrationDependencies, onComplete: @escaping (RegistrationResult) -> Void) {
        self.dependencies = dependencies
        self.onComplete = onComplete
    }

    public var body: some View {
        DynamicFormView(formName: .registration) { submission in

            let result = try await dependencies.service.register(submission)
            await MainActor.run { onComplete(result) }
        }
        .formDependencies(dependencies.forms)
        .jackpotTheme(dependencies.theme)
    }
}
```

**83.** `Packages/JackpotRegistration/Sources/JackpotRegistration/RegistrationPanelController.swift`

```swift
import UIKit
import SwiftUI

public final class RegistrationPanelController: UIHostingController<RegistrationView> {
    public init(dependencies: RegistrationDependencies, onComplete: @escaping (RegistrationResult) -> Void) {
        super.init(rootView: RegistrationView(dependencies: dependencies, onComplete: onComplete))
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) { sizingOptions = [.intrinsicContentSize] }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(dependencies:onComplete:)") }

    public var panelView: UIView { view }
}
```

**84.** `Packages/JackpotRegistration/Sources/JackpotRegistration/Previews.swift`

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsUI
import JackpotForms

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RegistrationView(dependencies: .mock()) { _ in }
                .previewDisplayName("Registration — mock, bundled copy")

            RegistrationView(dependencies: .mock(localizer: ClosureLocalizer { key in
                ["username": "Enter Mobile Number", "password": "Password", "email": "Email"][key]
            })) { _ in }
            .previewDisplayName("Registration — mock, app localizer")

            RegistrationView(dependencies: .init(forms: .mock(delay: 3600), service: MockRegistrationService())) { _ in }
                .previewDisplayName("Loading")
        }
        .frame(height: 640)
        .background(JackpotTheme.jackpotCity.surface)
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**85.** `Packages/JackpotRegistration/Tests/JackpotRegistrationTests/RegistrationServiceTests.swift`

```swift
import XCTest
@testable import JackpotRegistration
import JackpotFormsDomain
import JackpotForms
import JackpotNetworking

final class RegistrationServiceTests: XCTestCase {
    private func submission(mobile: String) -> FormSubmission {
        FormSubmission(formCodeName: .registration, values: ["username": .text(mobile), "terms": .bool(true)])
    }

    func testMockSucceedsAndReportsOTP() async throws {
        let result = try await MockRegistrationService(delay: 0).register(submission(mobile: "849134302"))
        XCTAssertEqual(result, RegistrationResult(accountNumber: "27849134302", requiresOTP: true))
    }

    func testMockDuplicateMobileFailsWithAReadableMessage() async {
        do {
            _ = try await MockRegistrationService(delay: 0).register(submission(mobile: "0000000000"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .mobileAlreadyRegistered)
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    func testEveryErrorHasUserFacingCopy() {
        let cases: [RegistrationError] = [.mobileAlreadyRegistered, .offline, .server(message: "x"), .unexpected]
        for c in cases { XCTAssertFalse((c.errorDescription ?? "").isEmpty, "\(c)") }
    }

    func testAPIErrorsMapToRegistrationErrors() {
        XCTAssertEqual(RegistrationError(.transport(.notConnectedToInternet)), .offline)
        XCTAssertEqual(RegistrationError(.badRequest(APIProblem(code: 1042, message: "dup"))), .mobileAlreadyRegistered)
        XCTAssertEqual(RegistrationError(.badRequest(APIProblem(code: 7, message: "Bad input"))), .server(message: "Bad input"))
        XCTAssertEqual(RegistrationError(.server(nil)), .unexpected)
    }

    func testClosureLocalizerMapsKeyOnMissToNil() {
        func legacyGetTranslation(Key: String) -> String { Key == "username" ? "Enter Mobile Number" : Key }
        let localizer = ClosureLocalizer { key in
            let value = legacyGetTranslation(Key: key)
            return value == key ? nil : value
        }
        XCTAssertEqual(localizer.string(forKey: "username"), "Enter Mobile Number")
        XCTAssertNil(localizer.string(forKey: "dateOfBirth"))
        XCTAssertEqual(localizer.display("dateOfBirth"), "Date Of Birth")
    }
}
```

**86.**

```bash
xcodebuild -scheme JackpotRegistration -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotRegistration

`Executed 5 tests, with 0 failures`

Open `Previews.swift` and run the flow.

---

## PR 5 — Replace the current flow

**In Xcode:** File → Add Package Dependencies → Add Local… → add `Packages/JackpotUI`,
`Packages/JackpotForms`, `Packages/JackpotCore`, `Packages/JackpotRegistration`.
Add **JackpotRegistration** to the app target's frameworks.

**87.** `Sources/Features/Registration/RegistrationPresenter.swift`

```swift
import UIKit
import JackpotFormsDomain
import JackpotRegistration

extension MainViewController {

    private var registrationLocalizer: ClosureLocalizer {
        ClosureLocalizer { key in
            let value = getTranslation(Key: key)
            return value == key ? nil : value
        }
    }

    func presentRegistration() {
        let controller = RegistrationPanelController(
            dependencies: RegistrationDependencies(
                forms: .live(
                    baseURL: URL(string: "https://config.jpc.africa/crm")!,
                    localizer: registrationLocalizer
                ),
                service: MockRegistrationService()
            )
        ) { [weak self] result in
            self?.routeAfterRegistration(result)
        }
        addChild(controller)
        popupContainer.show(controller.view)
        controller.didMove(toParent: self)
    }

    private func routeAfterRegistration(_ result: RegistrationResult) {
        popupContainer.dismiss()
    }
}
```

**88.** Point every existing entry point at `presentRegistration()`:

- the header **SIGN UP** button
- the bottom bar **Sign Up** item
- `NavigationHandler` — the `registration` sitemap branch
- the Login panel's **Sign Up ›** link

**89.** Delete:

```
RegistrationViewController.swift
RegistrationViewController.xib
FlowOneViewController.swift
FlowOneViewController.xib
FlowTwoViewController.swift
FlowTwoViewController.xib
```

And from `GlobalData.swift`:

```
registrationPopup
flowOneViewController
flowTwoViewController
```

**90.**

```bash
grep -rn "registrationPopup\|flowOneViewController\|flowTwoViewController" --include=*.swift .
```

Expect no results.

---

### ▶ Create PR — Replace registration flow

Build and run. Open sign-up from the header and the bottom bar; complete both pages.

---

## Follow-up — localisation

Not part of the five. See `docs/OPEN-QUESTIONS.md` and
`docs/adr/0001-app-data-decoding-and-configuration-decomposition.md`.

Adds `JackpotAppData` and `JackpotLocalization` to JackpotCore, turns `getTranslation` into a
shim over `Translations`, then replaces `registrationLocalizer` with `TranslationsLocalizer`.
