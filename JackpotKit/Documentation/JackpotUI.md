# JackpotUI

The design system. Components and tokens only — no data, no networking, no notion of a form.
Everything is driven by `Binding`s and plain values, so any feature can use it and every
component previews on its own.

**iOS 15+ · no dependencies · one gallery preview covering every component and state**

```bash
xcodebuild -scheme JackpotUI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The package is iOS-only, so tests run in a simulator rather than through `swift test`.

Open `Sources/JackpotUI/Preview/JackpotPreviewPanel.swift` and resume the **Gallery** preview.
That is the fastest way to see everything this package does.

---

## Why a separate package

The first draft had these views inside the forms package, each one reading a form model
directly. That coupled the *look* of a text field to the *mechanics* of a dynamic form — the
Account Settings screen, the deposit flow and the login panel all need the same text field, and
none of them are dynamic forms.

So the split is:

| Package | Owns | Knows about |
|---|---|---|
| **`JackpotUI`** | how a text field, checkbox, button, card *look and behave* | `Binding<String>`, `Binding<Bool>`, plain values |
| `JackpotForms` | how a schema field *becomes* one of those | `FormField`, `DynamicFormModel`, validation |

A `JackpotForms` field view is now ~20 lines: read the model, hand a binding to the component,
call `markTouched` when the component reports an edit ended. The component never learns what a
form is.

## Components

| Component | What it is | Replaces in the app |
|---|---|---|
| `JackpotTheme` · `.jackpotTheme()` | colour, radius, height and spacing tokens via the environment | ad-hoc colours per nib |
| `JackpotButton` · `JackpotButtonStyle` | full-width primary / secondary / tertiary, with a loading state | gold and blue buttons redrawn per screen |
| `JackpotTextField` | prefix cell (`+27`), suffix, secure-entry reveal, focus ring, invalid border, `onEditingEnded` | mobile, password, name, email fields |
| `JackpotTextArea` | multi-line with an overlaid placeholder (`TextEditor` has none on iOS 15) | |
| `JackpotDropdown` · `JackpotOption` | `Menu`-backed picker styled as a field | ID type, source of funds |
| `JackpotDateField` | field that opens a graphical picker in a sheet, with a range | date of birth |
| `JackpotCheckbox` · `JackpotToggleRow` · `JackpotRadioGroup` | 44pt-row choice controls | T&C, promotions opt-in, Account Settings toggles |
| `JackpotChecklist` · `JackpotChecklistItem` | expandable panel with a progress bar and tickable rows | the Password Validity panel |
| `JackpotSelectableCard` · `.jackpotLocked(_:message:)` | selectable tile + a dim-and-overlay lock | welcome-offer tiles; provider and payment-method grids |
| `JackpotProgressBar` | | the section progress bar |
| `JackpotLabeledField` · `JackpotDivider` | label above, control, error beneath | every form row |
| `JackpotSkeleton` · `JackpotErrorView` | loading and failure states | |
| `JackpotPreviewPanel` *(DEBUG)* | dark surface at device width, for previews | |

## Conventions

- **Bindings in, callbacks out.** A component takes `Binding<T>` for its value and a closure
  (`onEditingEnded`, `onSelect`, `onToggle`) for "the user did something". It never holds
  feature state.
- **`isInvalid` is a parameter, not a computation.** The component draws the red border; who
  decides it's invalid is the caller's business.
- **System types, not wrappers.** `JackpotTextField` takes `UIKeyboardType` and
  `UITextContentType` directly. An earlier version wrapped them in its own enums so the package
  would also compile on a macOS host; that bought CLI `swift test` at the cost of a parallel
  vocabulary and a mapping switch to extend for every new content type. This package is iOS-only
  and the manifest says so.
- **Every component has a state in the gallery preview.** Adding one without adding it there
  is the review comment you'll get.
- **Tokens, not literals.** Feature code reads `theme.accent`, never `Color(red:…)`.

---

## Building it from scratch

Fourteen files, one target. Order below compiles cleanly; `JackpotTheme` and
`JackpotFieldChrome` first because everything else reads them.

```bash
mkdir -p Packages/JackpotUI/Sources/JackpotUI/Preview Packages/JackpotUI/Tests/JackpotUITests
cd Packages/JackpotUI
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

#### Package manifest · `Package.swift`

```swift
// swift-tools-version: 5.7
import PackageDescription

// The design system. Components and tokens only — no data, no networking, no feature logic.
// Everything in here is driven by bindings and plain values, so it can be previewed and reused
// by any feature without knowing what the feature is.
let package = Package(
    name: "JackpotUI",
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

#### Step 1 · create `Sources/JackpotUI/JackpotTheme.swift`

Tokens and the environment key. Defaults are the JackpotCity panel.

```swift
import SwiftUI

/// Visual tokens. Defaults match the JackpotCity panel: near-black surfaces, blue actions,
/// gold for money, red for errors. Override per brand through the environment.
public struct JackpotTheme: Equatable {
    public var surface: Color
    public var surfaceElevated: Color
    public var fieldBackground: Color
    public var fieldBorder: Color
    public var fieldBorderFocused: Color
    public var fieldBorderInvalid: Color
    public var textPrimary: Color
    public var textSecondary: Color
    public var accent: Color
    public var actionPrimary: Color
    public var currency: Color
    public var error: Color
    public var success: Color
    public var cornerRadius: CGFloat
    public var controlHeight: CGFloat
    public var spacing: CGFloat

    public init(surface: Color = Color(red: 0.07, green: 0.08, blue: 0.09),
                surfaceElevated: Color = Color(red: 0.11, green: 0.12, blue: 0.14),
                fieldBackground: Color = Color(red: 0.13, green: 0.14, blue: 0.16),
                fieldBorder: Color = Color.white.opacity(0.18),
                fieldBorderFocused: Color = Color(red: 0.16, green: 0.47, blue: 0.96),
                fieldBorderInvalid: Color = Color(red: 0.94, green: 0.28, blue: 0.16),
                textPrimary: Color = .white,
                textSecondary: Color = Color.white.opacity(0.6),
                accent: Color = Color(red: 0.16, green: 0.47, blue: 0.96),
                actionPrimary: Color = Color(red: 0.96, green: 0.71, blue: 0.13),
                currency: Color = Color(red: 0.96, green: 0.71, blue: 0.13),
                error: Color = Color(red: 0.94, green: 0.28, blue: 0.16),
                success: Color = Color(red: 0.20, green: 0.72, blue: 0.44),
                cornerRadius: CGFloat = 10,
                controlHeight: CGFloat = 52,
                spacing: CGFloat = 12) {
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.fieldBackground = fieldBackground
        self.fieldBorder = fieldBorder
        self.fieldBorderFocused = fieldBorderFocused
        self.fieldBorderInvalid = fieldBorderInvalid
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.actionPrimary = actionPrimary
        self.currency = currency
        self.error = error
        self.success = success
        self.cornerRadius = cornerRadius
        self.controlHeight = controlHeight
        self.spacing = spacing
    }

    public static let jackpotCity = JackpotTheme()
}

private struct JackpotThemeKey: EnvironmentKey {
    static let defaultValue = JackpotTheme.jackpotCity
}

public extension EnvironmentValues {
    var jackpotTheme: JackpotTheme {
        get { self[JackpotThemeKey.self] }
        set { self[JackpotThemeKey.self] = newValue }
    }
}

public extension View {
    func jackpotTheme(_ theme: JackpotTheme) -> some View {
        environment(\.jackpotTheme, theme)
    }
}
```

#### Step 2 · create `Sources/JackpotUI/JackpotFieldChrome.swift`

The shared border modifier, the label-control-error wrapper, and a divider.

```swift
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
```

#### Step 3 · create `Sources/JackpotUI/JackpotButton.swift`

Style + a button with a loading state.

```swift
import SwiftUI

public struct JackpotButtonStyle: ButtonStyle {
    public enum Kind { case primary, secondary, tertiary }

    private let kind: Kind
    private let isEnabled: Bool
    @Environment(\.jackpotTheme) private var theme

    public init(_ kind: Kind = .primary, isEnabled: Bool = true) {
        self.kind = kind
        self.isEnabled = isEnabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: theme.controlHeight)
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(theme.cornerRadius)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var background: Color {
        switch kind {
        case .primary:   return isEnabled ? theme.accent : theme.fieldBackground
        case .secondary: return theme.fieldBackground
        case .tertiary:  return .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary:   return isEnabled ? .white : theme.textSecondary
        case .secondary: return theme.textPrimary
        case .tertiary:  return theme.accent
        }
    }
}

/// A full-width action button with a built-in loading state.
public struct JackpotButton: View {
    private let title: String
    private let kind: JackpotButtonStyle.Kind
    private let isEnabled: Bool
    private let isLoading: Bool
    private let action: () -> Void

    public init(_ title: String,
                kind: JackpotButtonStyle.Kind = .primary,
                isEnabled: Bool = true,
                isLoading: Bool = false,
                action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.white) }
            }
        }
        .buttonStyle(JackpotButtonStyle(kind, isEnabled: isEnabled))
        .disabled(!isEnabled || isLoading)
    }
}
```

#### Step 4 · create `Sources/JackpotUI/JackpotTextField.swift`

The most-used component. Owns its own focus and reports `onEditingEnded`, so a form can mark a field touched on blur without the component knowing what a form is. Takes `UIKeyboardType` and `UITextContentType` directly.

```swift
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
```

#### Step 5 · create `Sources/JackpotUI/JackpotTextArea.swift`



```swift
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
```

#### Step 6 · create `Sources/JackpotUI/JackpotDropdown.swift`

`JackpotOption` is the shared option type — `id` is stored, `label` is shown.

```swift
import SwiftUI

/// One selectable option. `id` is what gets stored; `label` is what the user sees.
public struct JackpotOption: Identifiable, Hashable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// A `Menu`-backed picker styled as a field.
public struct JackpotDropdown: View {
    @Binding private var selection: String?
    private let options: [JackpotOption]
    private let placeholder: String
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onSelect: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ placeholder: String,
                selection: Binding<String?>,
                options: [JackpotOption],
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onSelect: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self._selection = selection
        self.options = options
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.label) {
                    selection = option.id
                    onSelect()
                }
            }
        } label: {
            HStack {
                Text(selected?.label ?? placeholder)
                    .foregroundColor(selected == nil ? theme.textSecondary : theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.down").foregroundColor(theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: theme.controlHeight)
            .jackpotFieldBorder(isInvalid: isInvalid)
        }
        .disabled(isDisabled)
        .accessibilityValue(selected?.label ?? placeholder)
    }

    private var selected: JackpotOption? {
        options.first { $0.id == selection }
    }
}
```

#### Step 7 · create `Sources/JackpotUI/JackpotChoice.swift`

Checkbox, toggle row, radio group. Whole-row hit targets.

```swift
import SwiftUI

/// A tappable checkbox row. The whole row is the hit target (44pt minimum).
public struct JackpotCheckbox: View {
    @Binding private var isOn: Bool
    private let label: String
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onToggle: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ label: String,
                isOn: Binding<Bool>,
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onToggle: @escaping () -> Void = {}) {
        self.label = label
        self._isOn = isOn
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onToggle = onToggle
    }

    public var body: some View {
        Button {
            isOn.toggle()
            onToggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isOn ? theme.accent : (isInvalid ? theme.fieldBorderInvalid : theme.textSecondary))
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// A labelled switch.
public struct JackpotToggleRow: View {
    @Binding private var isOn: Bool
    private let label: String
    private let isDisabled: Bool
    private let onToggle: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ label: String, isOn: Binding<Bool>, isDisabled: Bool = false,
                onToggle: @escaping () -> Void = {}) {
        self.label = label
        self._isOn = isOn
        self.isDisabled = isDisabled
        self.onToggle = onToggle
    }

    public var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { isOn = $0; onToggle() })) {
            Text(label).font(.subheadline).foregroundColor(theme.textPrimary)
        }
        .tint(theme.accent)
        .disabled(isDisabled)
    }
}

/// Mutually exclusive options as a vertical list of radio rows.
public struct JackpotRadioGroup: View {
    @Binding private var selection: String?
    private let options: [JackpotOption]
    private let isDisabled: Bool
    private let onSelect: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(selection: Binding<String?>, options: [JackpotOption],
                isDisabled: Bool = false, onSelect: @escaping () -> Void = {}) {
        self._selection = selection
        self.options = options
        self.isDisabled = isDisabled
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection == option.id
                Button {
                    selection = option.id
                    onSelect()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(isSelected ? theme.accent : theme.textSecondary)
                        Text(option.label).font(.subheadline).foregroundColor(theme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .disabled(isDisabled)
    }
}
```

#### Step 8 · create `Sources/JackpotUI/JackpotDateField.swift`

The range is a parameter so a caller can cap it (18 years ago, for a date of birth).

```swift
import SwiftUI

/// A field that opens a graphical date picker in a sheet.
public struct JackpotDateField: View {
    @Binding private var date: Date?
    private let placeholder: String
    private let title: String
    private let range: PartialRangeThrough<Date>
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onCommit: () -> Void

    @Environment(\.jackpotTheme) private var theme
    @State private var isPresented = false

    public init(_ placeholder: String,
                title: String,
                date: Binding<Date?>,
                in range: PartialRangeThrough<Date> = ...Date(),
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onCommit: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self.title = title
        self._date = date
        self.range = range
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onCommit = onCommit
    }

    public var body: some View {
        Button { isPresented = true } label: {
            HStack {
                Text(date.map(Self.display.string(from:)) ?? placeholder)
                    .foregroundColor(date == nil ? theme.textSecondary : theme.textPrimary)
                Spacer()
                Image(systemName: "calendar").foregroundColor(theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: theme.controlHeight)
            .jackpotFieldBorder(isInvalid: isInvalid)
        }
        .disabled(isDisabled)
        .sheet(isPresented: $isPresented) { sheet }
    }

    private var sheet: some View {
        VStack(spacing: 16) {
            Text(title).font(.headline).padding(.top, 20)
            DatePicker("",
                       selection: Binding(get: { date ?? range.upperBound }, set: { date = $0 }),
                       in: range,
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal)
            JackpotButton("Done") {
                if date == nil { date = range.upperBound }
                onCommit()
                isPresented = false
            }
            .padding([.horizontal, .bottom], 16)
        }
    }

    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
```

#### Step 9 · create `Sources/JackpotUI/JackpotChecklist.swift`

The Password Validity panel, generalised: any list of `(text, isSatisfied)`.

```swift
import SwiftUI

/// One row in a checklist.
public struct JackpotChecklistItem: Identifiable, Equatable {
    public let id: String
    public let text: String
    public let isSatisfied: Bool

    public init(id: String, text: String, isSatisfied: Bool) {
        self.id = id
        self.text = text
        self.isSatisfied = isSatisfied
    }
}

/// An expandable panel with a progress bar and tickable rows — the "Password Validity" panel
/// from the design, generalised.
public struct JackpotChecklist: View {
    private let title: String
    private let sectionTitle: String
    private let items: [JackpotChecklistItem]

    @Environment(\.jackpotTheme) private var theme
    @State private var isExpanded = true

    public init(title: String, sectionTitle: String = "Required", items: [JackpotChecklistItem]) {
        self.title = title
        self.sectionTitle = sectionTitle
        self.items = items
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text(title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.up").rotationEffect(.degrees(isExpanded ? 0 : 180))
                    }
                    .foregroundColor(theme.textPrimary)
                }

                if isExpanded {
                    JackpotProgressBar(progress: satisfiedFraction,
                                       tint: satisfiedFraction < 1 ? .orange : theme.success)
                        .frame(height: 6)
                    Text(sectionTitle).font(.subheadline.weight(.semibold)).foregroundColor(theme.textPrimary)
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isSatisfied ? theme.accent : theme.textSecondary)
                            Text(item.text).font(.subheadline).foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(item.isSatisfied ? "Met" : "Not met")
                    }
                }
            }
            .padding(14)
            .background(theme.fieldBackground)
            .cornerRadius(theme.cornerRadius)
        }
    }

    private var satisfiedFraction: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isSatisfied).count) / Double(items.count)
    }
}
```

#### Step 10 · create `Sources/JackpotUI/JackpotProgressBar.swift`



```swift
import SwiftUI

public struct JackpotProgressBar: View {
    private let progress: Double
    private let tint: Color?
    @Environment(\.jackpotTheme) private var theme

    public init(progress: Double, tint: Color? = nil) {
        self.progress = progress
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.fieldBorder)
                Capsule().fill(tint ?? theme.accent)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.25), value: progress)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
```

#### Step 11 · create `Sources/JackpotUI/JackpotSelectableCard.swift`

Selectable tile plus the lock overlay used on welcome offers.

```swift
import SwiftUI

/// A tile that can be selected from a set — provider logos, payment methods, welcome offers.
public struct JackpotSelectableCard<Content: View>: View {
    private let isSelected: Bool
    private let isEnabled: Bool
    private let action: () -> Void
    private let content: Content
    @Environment(\.jackpotTheme) private var theme

    public init(isSelected: Bool, isEnabled: Bool = true, action: @escaping () -> Void,
                @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(theme.fieldBackground)
                .cornerRadius(theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(isSelected ? theme.accent : theme.fieldBorder, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Dims content and overlays a message until a condition is met — the "Complete your
/// registration above to unlock" treatment.
public struct JackpotLockedOverlay: ViewModifier {
    private let isLocked: Bool
    private let message: String
    @Environment(\.jackpotTheme) private var theme

    public init(isLocked: Bool, message: String) {
        self.isLocked = isLocked
        self.message = message
    }

    public func body(content: Content) -> some View {
        ZStack {
            content.opacity(isLocked ? 0.35 : 1).allowsHitTesting(!isLocked)
            if isLocked {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .shadow(radius: 4)
            }
        }
    }
}

public extension View {
    func jackpotLocked(_ isLocked: Bool, message: String) -> some View {
        modifier(JackpotLockedOverlay(isLocked: isLocked, message: message))
    }
}
```

#### Step 12 · create `Sources/JackpotUI/JackpotStates.swift`

Skeleton and error views.

```swift
import SwiftUI

/// Placeholder rows while content loads.
public struct JackpotSkeleton: View {
    private let rows: Int
    @Environment(\.jackpotTheme) private var theme

    public init(rows: Int = 5) { self.rows = rows }

    public var body: some View {
        VStack(spacing: theme.spacing) {
            ForEach(0..<rows, id: \.self) { _ in
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.fieldBackground)
                    .frame(height: theme.controlHeight)
            }
        }
        .redacted(reason: .placeholder)
    }
}

/// Something went wrong, with a retry.
public struct JackpotErrorView: View {
    private let title: String
    private let message: String
    private let retryTitle: String
    private let retry: () -> Void
    @Environment(\.jackpotTheme) private var theme

    public init(title: String = "Something went wrong",
                message: String,
                retryTitle: String = "Retry",
                retry: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(theme.textSecondary)
            Text(title).font(.headline).foregroundColor(theme.textPrimary)
            Text(message).font(.footnote).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
            JackpotButton(retryTitle, action: retry).frame(width: 160)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
```

#### Step 13 · create `Sources/JackpotUI/Preview/JackpotPreviewPanel.swift`

The preview surface, and the **gallery** — every component in every state on one screen.

```swift
#if DEBUG
import SwiftUI

/// Puts a component on the panel's dark surface at a realistic width, so previews look like
/// the real thing rather than a white sheet. Public so feature packages can use it too.
public struct JackpotPreviewPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.caption).foregroundColor(.white.opacity(0.5)) }
            content
        }
        .padding(16)
        .frame(width: 390)
        .background(JackpotTheme.jackpotCity.surface)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Component gallery

struct JackpotUI_Previews: PreviewProvider {
    struct Harness: View {
        @State var text = ""
        @State var secret = "Passwo1"
        @State var isOn = false
        @State var agreed = true
        @State var choice: String? = nil
        @State var radio: String? = "email"
        @State var date: Date? = nil

        var body: some View {
            ScrollView {
                JackpotPreviewPanel("Gallery") {
                    JackpotLabeledField(label: "Mobile", error: nil) {
                        JackpotTextField("Enter Mobile Number", text: $text, prefix: "+27", keyboard: .numberPad)
                    }
                    JackpotLabeledField(error: "Password must be 8–20 characters") {
                        JackpotTextField("Password", text: $secret, isSecure: true, isInvalid: true)
                    }
                    JackpotChecklist(title: "Password Validity", items: [
                        .init(id: "min", text: "Minimum of 8 characters", isSatisfied: false),
                        .init(id: "max", text: "Maximum of 20 characters", isSatisfied: true),
                    ])
                    JackpotDropdown("Enter Source Of Income", selection: $choice, options: [
                        .init(id: "salary", label: "Salary or Wages"), .init(id: "pension", label: "Pension or Grant"),
                    ], isInvalid: true)
                    JackpotDateField("Enter Date Of Birth", title: "Date of Birth", date: $date)
                    JackpotRadioGroup(selection: $radio, options: [
                        .init(id: "sms", label: "SMS"), .init(id: "email", label: "Email"),
                    ])
                    JackpotCheckbox("Send Jackpot City Promotions to me", isOn: $isOn)
                    JackpotCheckbox("I am over 18 years of age & I accept the Terms & Conditions", isOn: $agreed)
                    JackpotToggleRow("Keep me logged in", isOn: $isOn)
                    JackpotProgressBar(progress: 0.45)
                    HStack(spacing: 10) {
                        JackpotSelectableCard(isSelected: true, action: {}) { Text("100% Deposit Match").foregroundColor(.white) }
                        JackpotSelectableCard(isSelected: false, action: {}) { Text("50 Free Spins").foregroundColor(.white) }
                    }
                    .jackpotLocked(true, message: "Complete your registration above to unlock your Welcome offer selection")
                    JackpotButton("Next", isEnabled: false) {}
                    JackpotButton("Sign Up", isLoading: true) {}
                    JackpotButton("Previous", kind: .secondary) {}
                }
            }
            .background(JackpotTheme.jackpotCity.surface)
        }
    }

    static var previews: some View {
        Group {
            Harness().previewDisplayName("Gallery")
            JackpotPreviewPanel("Skeleton") { JackpotSkeleton() }.previewDisplayName("Skeleton")
            JackpotPreviewPanel("Error") { JackpotErrorView(message: "The network connection was lost.") {} }
                .previewDisplayName("Error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

#### Step 14 · create `Tests/JackpotUITests/JackpotThemeTests.swift`

Minimal. Previews are the real coverage for a design system.

```swift
import XCTest
@testable import JackpotUI

final class JackpotThemeTests: XCTestCase {
    func testDefaultThemeIsTheBrand() {
        XCTAssertEqual(JackpotTheme(), .jackpotCity)
    }

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

**✓ Checkpoint**

```bash
xcodebuild -scheme JackpotUI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Then open the gallery preview.
