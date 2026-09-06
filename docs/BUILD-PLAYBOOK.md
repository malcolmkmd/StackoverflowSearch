# Build Playbook

Create the files in the order given. Run the commands where they appear. Open a PR where marked.

103 tests when complete: 3 + 61 + 34 + 5.

`JackpotCore` is pure Foundation and runs under `swift test`. The other three contain iOS views,
so their suites run in a simulator via `xcodebuild`.

---

## PR 1 — JackpotUI

**1.**

```bash
mkdir -p Packages/JackpotUI/Sources/JackpotUI/Preview Packages/JackpotUI/Tests/JackpotUITests
cd Packages/JackpotUI
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

**2.** `Packages/JackpotUI/Package.swift`

```swift
// swift-tools-version: 5.7
import PackageDescription

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

**3.** `Packages/JackpotUI/Sources/JackpotUI/JackpotTheme.swift`

```swift
import SwiftUI

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

**4.** `Packages/JackpotUI/Sources/JackpotUI/JackpotFieldChrome.swift`

```swift
import SwiftUI

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

public struct JackpotDivider: View {
    @Environment(\.jackpotTheme) private var theme
    public init() {}
    public var body: some View {
        Rectangle().fill(theme.fieldBorder).frame(height: 1).padding(.vertical, 4)
    }
}
```

**5.** `Packages/JackpotUI/Sources/JackpotUI/JackpotButton.swift`

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

**6.** `Packages/JackpotUI/Sources/JackpotUI/JackpotTextField.swift`

```swift
import SwiftUI
import UIKit

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

**7.** `Packages/JackpotUI/Sources/JackpotUI/JackpotTextArea.swift`

```swift
import SwiftUI

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

**8.** `Packages/JackpotUI/Sources/JackpotUI/JackpotDropdown.swift`

```swift
import SwiftUI

public struct JackpotOption: Identifiable, Hashable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

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

**9.** `Packages/JackpotUI/Sources/JackpotUI/JackpotChoice.swift`

```swift
import SwiftUI

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

**10.** `Packages/JackpotUI/Sources/JackpotUI/JackpotDateField.swift`

```swift
import SwiftUI

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

**11.** `Packages/JackpotUI/Sources/JackpotUI/JackpotProgressBar.swift`

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

**12.** `Packages/JackpotUI/Sources/JackpotUI/JackpotChecklist.swift`

```swift
import SwiftUI

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

**13.** `Packages/JackpotUI/Sources/JackpotUI/JackpotSelectableCard.swift`

```swift
import SwiftUI

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

**14.** `Packages/JackpotUI/Sources/JackpotUI/JackpotStates.swift`

```swift
import SwiftUI

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

**15.** `Packages/JackpotUI/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift`

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
            if let title { Text(title).font(.caption).foregroundColor(.white.opacity(0.5)) }
            content
        }
        .padding(16)
        .frame(width: 390)
        .background(JackpotTheme.jackpotCity.surface)
        .preferredColorScheme(.dark)
    }
}

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

**16.** `Packages/JackpotUI/Tests/JackpotUITests/JackpotThemeTests.swift`

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

**17.**

```bash
xcodebuild -scheme JackpotUI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotUI

`Executed 3 tests, with 0 failures`

Open `JackpotPreviewPanel.swift` and resume the **Gallery** preview.

---

## PR 2 — JackpotForms

**18.**

```bash
mkdir -p Packages/JackpotForms/Sources/{JackpotFormsDomain,JackpotFormsData,JackpotFormsRemote,JackpotForms}
mkdir -p Packages/JackpotForms/Sources/JackpotFormsUI/{Fields,Demo,Resources}
mkdir -p Packages/JackpotForms/Tests/JackpotFormsTests/Fixtures
cd Packages/JackpotForms
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

**19.** `Packages/JackpotForms/Package.swift`

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
            targets: ["JackpotForms", "JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI"]
        ),
    ],
    dependencies: [
        .package(path: "../JackpotUI"),
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
            name: "JackpotForms",
            dependencies: [
                "JackpotFormsData",
                "JackpotFormsUI",
            ]
        ),

        .testTarget(
            name: "JackpotFormsTests",
            dependencies: ["JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI", "JackpotForms"],
            resources: [.process("Fixtures")]
        ),
    ]
)
```

**20.** `Packages/JackpotForms/Sources/JackpotFormsDomain/FormName.swift`

```swift
import Foundation

public struct FormName: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public extension FormName {
    static let registration = FormName("registration")

    static let kitchenSink = FormName("kitchenSink")

    static let bundled: [FormName] = [.registration, .kitchenSink]
}
```

**21.** `Packages/JackpotForms/Sources/JackpotFormsDomain/Form.swift`

```swift
import Foundation

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

**22.** `Packages/JackpotForms/Sources/JackpotFormsDomain/FormField.swift`

```swift
import Foundation

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

    public var isDecorative: Bool {
        switch self {
        case .divider, .button: return true
        default:                return false
        }
    }
}

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

        case "calender", "calendar", "date": self = .calendar
        case "phone", "tel":          self = .phone
        default:                      self = .unknown(raw)
        }
    }
}

public struct DropdownOption: Identifiable, Equatable, Hashable, Sendable {
    public let value: String

    public let textKey: String

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

    public let identifier: String
    public let name: String

    public let labelKey: String
    public let type: FieldType
    public let inputType: InputType
    public let textStyle: String

    public let validationMessageKey: String
    public let isRequired: Bool
    public let isVisible: Bool
    public let isReadOnly: Bool

    public let regex: String?
    public let prefix: String
    public let suffix: String

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

    public var carriesValue: Bool {
        isVisible && !type.isDecorative && !(type == .recaptchaV2 || type == .recaptchaV3)
    }

    public var isSecure: Bool { inputType == .password }
}
```

**23.** `Packages/JackpotForms/Sources/JackpotFormsDomain/FormValue.swift`

```swift
import Foundation

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

    public static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

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

    public var stringValues: [String: String] {
        values.mapValues(\.stringValue)
    }
}
```

**24.** `Packages/JackpotForms/Sources/JackpotFormsDomain/RegexResolving.swift`

```swift
import Foundation

public protocol RegexResolving: Sendable {
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

    public static let jpcDefaults = RegexCatalog(patterns: [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^[a-zA-Z0-9]{5,20}$",
    ])
}

public extension String {
    var looksLikeRegexPattern: Bool {
        let metacharacters = CharacterSet(charactersIn: "^$[]{}()|*+?\\.")
        return rangeOfCharacter(from: metacharacters) != nil
    }
}
```

**25.** `Packages/JackpotForms/Sources/JackpotFormsDomain/FieldValidator.swift`

```swift
import Foundation

public enum ValidationResult: Equatable, Sendable {
    case valid

    case invalid(messageKey: String)

    public var isValid: Bool { self == .valid }
}

public struct FieldValidator: Sendable {
    private let regexResolver: any RegexResolving
    private let cache = RegexCache()

    public init(regexResolver: any RegexResolving = RegexCatalog.jpcDefaults) {
        self.regexResolver = regexResolver
    }

    public func validate(_ value: FormValue,
                         against field: FormField,
                         overrideRegex: String? = nil) -> ValidationResult {
        guard field.carriesValue, !field.isReadOnly else { return .valid }

        if field.isRequired, value.isEmpty {
            return .invalid(messageKey: field.validationMessageKey)
        }

        if !field.isRequired, value.isEmpty { return .valid }

        guard let pattern = resolvedPattern(overrideRegex ?? field.regex), !pattern.isEmpty else {
            return .valid
        }

        guard let expression = cache.expression(for: pattern) else {
            return .valid
        }

        let subject = value.stringValue
        let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
        let matched = expression.firstMatch(in: subject, options: [], range: range) != nil
        return matched ? .valid : .invalid(messageKey: field.validationMessageKey)
    }

    public func optionPattern(_ raw: String?) -> String? {
        resolvedPattern(raw)
    }

    private func resolvedPattern(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if let named = regexResolver.pattern(named: raw) { return named }
        return raw.looksLikeRegexPattern ? raw : nil
    }

    public func invalidPatterns(in form: FormSchema) -> [String] {
        form.allFields.compactMap { field in
            guard let pattern = resolvedPattern(field.regex), !pattern.isEmpty else { return nil }
            return cache.expression(for: pattern) == nil ? pattern : nil
        }
    }
}

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

**26.** `Packages/JackpotForms/Sources/JackpotFormsDomain/PasswordPolicy.swift`

```swift
import Foundation

public struct PasswordRule: Identifiable, Equatable, Sendable {
    public let id: String

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

**27.** `Packages/JackpotForms/Sources/JackpotFormsDomain/FormLoadError.swift`

```swift
import Foundation

public enum FormLoadError: LocalizedError, Equatable {
    case offline
    case notFound(FormName)

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

**28.** `Packages/JackpotForms/Sources/JackpotFormsDomain/FormRepository.swift`

```swift
import Foundation

public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
}
```

**29.** `Packages/JackpotForms/Sources/JackpotFormsDomain/FormLocalizing.swift`

```swift
import Foundation

public protocol FormLocalizing: Sendable {
    func string(forKey key: String) -> String?

    func message(forErrorCode code: Int) -> String?
}

public extension FormLocalizing {
    func message(forErrorCode code: Int) -> String? { nil }

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

**30.** `Packages/JackpotForms/Sources/JackpotFormsData/FormDTO.swift`

```swift
import Foundation

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

**31.** `Packages/JackpotForms/Sources/JackpotFormsData/FormMapper.swift`

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

**32.** `Packages/JackpotForms/Sources/JackpotFormsData/StubFormRepository.swift`

```swift
import Foundation
import JackpotFormsDomain

public struct StubFormRepository: FormRepository {
    private let forms: [FormName: Data]

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

    public static func decode(_ data: Data) throws -> FormSchema {
        FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
    }
}
```

**33.** `Packages/JackpotForms/Sources/JackpotFormsUI/FormDependencies.swift`

```swift
import SwiftUI
import JackpotFormsDomain

public struct FormDependencies {
    public var repository: any FormRepository
    public var validator: FieldValidator
    public var localizer: any FormLocalizing
    public var passwordPolicy: any PasswordPolicyProviding

    public var appliesOptionRegexToDependentField: Bool

    public var regexDependencies: [String: String]

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
    static var defaultValue: FormDependencies {
        FormDependencies(repository: UnavailableFormRepository(assertsWhenCalled: true))
    }
}

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
    static var preview: FormDependencies {
        FormDependencies(repository: UnavailableFormRepository(),
                         localizer: ComposedKeyLocalizer.jpcRegistration)
    }
}

#endif
```

**34.** `Packages/JackpotForms/Sources/JackpotFormsUI/DynamicFormModel.swift`

```swift
import Foundation
import Combine
import JackpotFormsDomain

@MainActor
public final class DynamicFormModel: ObservableObject {
    public enum ViewState: Equatable {
        case loading
        case loaded(FormSchema)
        case failed(String)
    }

    @Published public internal(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var errors: [String: String] = [:]
    @Published public internal(set) var sectionIndex: Int = 0
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

    @Published public private(set) var unsupportedFields: [String] = []

    private let formName: FormName
    private var dependencies: FormDependencies
    private var isConfigured: Bool
    private var touched: Set<String> = []
    private var loadTask: Task<Void, Never>?

    public init(formName: FormName, dependencies: FormDependencies, isConfigured: Bool = true) {
        self.formName = formName
        self.dependencies = dependencies
        self.isConfigured = isConfigured
    }

    public func configureIfNeeded(with dependencies: FormDependencies) {
        guard !isConfigured else { return }
        self.dependencies = dependencies
        isConfigured = true
    }

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

    public var progress: Double {
        guard let form else { return 0 }
        let required = form.allFields.filter { $0.carriesValue && $0.isRequired }
        guard !required.isEmpty else { return isLastSection ? 1 : 0 }
        let satisfied = required.filter { isValid($0) }.count
        return Double(satisfied) / Double(required.count)
    }

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

    public func error(for field: FormField) -> String? {
        touched.contains(field.identifier) ? errors[field.identifier] : nil
    }

    public func localized(_ key: String) -> String { dependencies.localizer.display(key) }

    public func passwordRules(for field: FormField) -> [PasswordRule] {
        dependencies.passwordPolicy.rules(for: field)
    }

    public var maximumDateOfBirth: Date { dependencies.maximumDateOfBirth }

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

    public func setValue(_ value: FormValue, for field: FormField) {
        values[field.identifier] = value
        validate(field)

        if field.type == .dropdown, dependencies.appliesOptionRegexToDependentField {
            revalidateDependents(of: field)
        }
    }

    public func markTouched(_ field: FormField) {
        touched.insert(field.identifier)
        objectWillChange.send()
    }

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

    private func regexDriver(for field: FormField) -> FormField? {
        guard dependencies.appliesOptionRegexToDependentField,
              let form,
              let driverIdentifier = dependencies.regexDependencies.first(where: { $0.value == field.identifier })?.key,
              let driver = form.field(identifiedBy: driverIdentifier),
              driver.type == .dropdown
        else { return nil }
        return driver
    }

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

    @discardableResult
    public func advance() -> Bool {
        guard let section = currentSection else { return false }
        section.fields.filter(\.carriesValue).forEach { touched.insert($0.identifier) }
        revalidateAll()
        guard isCurrentSectionValid else {
            objectWillChange.send()
            return false
        }
        if !isLastSection { sectionIndex += 1 }
        return true
    }

    public func goBack() {
        guard sectionIndex > 0 else { return }
        sectionIndex -= 1
    }

    public func submit(_ handler: @escaping (FormSubmission) async throws -> Void) async {
        guard let form else { return }
        form.allFields.filter(\.carriesValue).forEach { touched.insert($0.identifier) }
        revalidateAll()
        guard isFormValid else {
            objectWillChange.send()
            return
        }

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

public extension DynamicFormModel {
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

    static func previewLoading(dependencies: FormDependencies = .preview) -> DynamicFormModel {
        DynamicFormModel(formName: FormName("preview"), dependencies: dependencies)
    }

    static func previewFailed(_ message: String = "The network connection was lost.") -> DynamicFormModel {
        let model = DynamicFormModel(formName: FormName("preview"), dependencies: .preview)
        model.viewState = .failed(message)
        return model
    }
}
#endif
```

**35.** `Packages/JackpotForms/Sources/JackpotFormsUI/Demo/PreviewFixtures.swift`

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain

public enum FormPreview {
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

    public static let notes = field("notes", type: .textArea, label: "Notes",
                                    placeholder: "Anything else?", required: false)

    public static let contactMethod = field(
        "contactMethod", type: .radioGroup, label: "Preferred contact method", required: true,
        regex: "^.+$",
        radios: [
            RadioOption(value: "sms", textKey: "SMS"),
            RadioOption(value: "email", textKey: "Email"),
            RadioOption(value: "whatsapp", textKey: "WhatsApp"),
        ]
    )

    public static let welcomeOffer = field(
        "welcomeOffer", type: .welcomeOffer, label: "Select your Welcome Offer:", required: false,
        dropdowns: [
            DropdownOption(value: "depositMatch", textKey: "100% Deposit Match", regex: nil),
            DropdownOption(value: "freeSpins", textKey: "50 Free Spins", regex: nil),
        ]
    )

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

    public static func schema(_ fields: [FormField]) -> FormSchema {
        FormSchema(id: 1, codeName: FormName("preview"), title: "", subTitle: "", regionCode: "JZA",
                   sections: [FormSection(id: 1, codeName: "1", title: "", subTitle: "", order: 1,
                                          rows: fields.enumerated().map { FormRow(number: $0.offset + 1, fields: [$0.element]) })])
    }

    @MainActor
    public static func model(_ fields: [FormField],
                            values: [String: FormValue] = [:],
                            touched: [String] = []) -> DynamicFormModel {
        .preview(schema: schema(fields), values: values, touched: touched)
    }

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

**36.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/FieldRenderer.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        switch field.type {
        case .input:                    InputFieldView(field: field, model: model)
        case .textArea:                 TextAreaFieldView(field: field, model: model)
        case .dropdown:                 DropdownFieldView(field: field, model: model)
        case .checkbox:                 CheckboxFieldView(field: field, model: model)
        case .toggle:                   ToggleFieldView(field: field, model: model)
        case .radio, .radioGroup:       RadioGroupFieldView(field: field, model: model)
        case .divider:                  JackpotDivider()
        case .welcomeOffer:             WelcomeOfferFieldView(field: field, model: model)
        case .button:                   EmptyView()
        case .recaptchaV2, .recaptchaV3: RecaptchaPlaceholderView(field: field)
        case .unknown:                  EmptyView()
        }
    }
}

struct RecaptchaPlaceholderView: View {
    let field: FormField
    @Environment(\.jackpotTheme) private var theme

    var body: some View {
        #if DEBUG
        Text("reCAPTCHA (\(field.identifier)) — not implemented")
            .font(.caption)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .jackpotFieldBorder(isInvalid: false)
        #else
        EmptyView()
        #endif
    }
}

extension DynamicFormModel {
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    func selection(for field: FormField) -> Binding<String?> {
        Binding(get: { let v = self.value(for: field).stringValue; return v.isEmpty ? nil : v },
                set: { self.setValue(.option($0 ?? ""), for: field) })
    }

    func bool(for field: FormField) -> Binding<Bool> {
        Binding(get: { self.value(for: field).boolValue },
                set: { self.setValue(.bool($0), for: field) })
    }

    func date(for field: FormField) -> Binding<Date?> {
        Binding(get: { self.value(for: field).dateValue },
                set: { self.setValue($0.map(FormValue.date) ?? .empty, for: field) })
    }

    func options(for field: FormField) -> [JackpotOption] {
        field.dropdownOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }
    }

    func radioOptions(for field: FormField) -> [JackpotOption] {
        field.radioOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }
    }
}
```

**37.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/InputFieldView.swift`

```swift
import SwiftUI
import UIKit
import JackpotUI
import JackpotFormsDomain

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        if field.inputType == .calendar {
            DateFieldView(field: field, model: model)
        } else {
            JackpotLabeledField(error: model.error(for: field)) {
                VStack(spacing: 6) {
                    JackpotTextField(
                        model.localized(field.placeholderKey),
                        text: model.text(for: field),
                        prefix: field.prefix,
                        suffix: field.suffix,
                        keyboard: keyboard,
                        contentType: contentType,
                        autocapitalization: autocapitalization,
                        isSecure: field.isSecure,
                        isInvalid: model.error(for: field) != nil,
                        isDisabled: field.isReadOnly,
                        onEditingEnded: { model.markTouched(field) }
                    )
                    if field.isSecure {
                        JackpotChecklist(
                            title: "Password Validity",
                            items: model.passwordRules(for: field).map { rule in
                                JackpotChecklistItem(id: rule.id,
                                                     text: rule.fallbackDescription,
                                                     isSatisfied: rule.isSatisfied(by: model.value(for: field).stringValue))
                            }
                        )
                    }
                }
            }
        }
    }

    private var keyboard: UIKeyboardType {
        switch field.inputType {
        case .number:  return .numberPad
        case .phone:   return .phonePad
        case .email:   return .emailAddress
        default:       return .default
        }
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch field.inputType {
        case .email, .password, .number: return .never
        default:                         return .words
        }
    }

    private var contentType: UITextContentType? {
        switch field.identifier.lowercased() {
        case "username", "mobile", "mobilenumber": return .telephoneNumber
        case "password":                            return .newPassword
        case "firstname":                           return .givenName
        case "lastname", "surname":                 return .familyName
        case "email":                               return .emailAddress
        case "otp", "pin", "code":                  return .oneTimeCode
        default:                                    return nil
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
            JackpotPreviewPanel("Password · 7 chars") {
                InputFieldView(field: FormPreview.password,
                               model: FormPreview.model([FormPreview.password], values: ["password": .text("Passwo1")], touched: ["password"]))
            }.previewDisplayName("Password — checklist")
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

**38.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/DropdownFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct DropdownFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(label: model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotDropdown(
                model.localized(field.placeholderKey),
                selection: model.selection(for: field),
                options: model.options(for: field),
                isInvalid: model.error(for: field) != nil,
                isDisabled: field.isReadOnly,
                onSelect: { model.markTouched(field) }
            )
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

**39.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/CheckboxFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct CheckboxFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(error: model.error(for: field)) {
            JackpotCheckbox(
                model.localized(field.labelKey),
                isOn: model.bool(for: field),
                isInvalid: model.error(for: field) != nil,
                isDisabled: field.isReadOnly,
                onToggle: { model.markTouched(field) }
            )
        }
    }
}

struct ToggleFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(error: model.error(for: field)) {
            JackpotToggleRow(model.localized(field.labelKey),
                             isOn: model.bool(for: field),
                             isDisabled: field.isReadOnly,
                             onToggle: { model.markTouched(field) })
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

**40.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/RadioGroupFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct RadioGroupFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(label: model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotRadioGroup(selection: model.selection(for: field),
                              options: model.radioOptions(for: field),
                              isDisabled: field.isReadOnly,
                              onSelect: { model.markTouched(field) })
        }
    }
}

#if DEBUG
struct RadioGroupFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Nothing chosen") {
                RadioGroupFieldView(field: FormPreview.contactMethod, model: FormPreview.model([FormPreview.contactMethod]))
            }.previewDisplayName("Radio — empty")
            JackpotPreviewPanel("Chosen") {
                RadioGroupFieldView(field: FormPreview.contactMethod,
                                    model: FormPreview.model([FormPreview.contactMethod], values: ["contactMethod": .option("email")]))
            }.previewDisplayName("Radio — selected")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**41.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/DateFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct DateFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(label: model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotDateField(
                model.localized(field.placeholderKey),
                title: model.localized(field.labelKey),
                date: model.date(for: field),

                in: ...model.maximumDateOfBirth,
                isInvalid: model.error(for: field) != nil,
                isDisabled: field.isReadOnly,
                onCommit: { model.markTouched(field) }
            )
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

**42.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/TextAreaFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct TextAreaFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotLabeledField(label: model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotTextArea(model.localized(field.placeholderKey),
                            text: model.text(for: field),
                            isInvalid: model.error(for: field) != nil,
                            isDisabled: field.isReadOnly,
                            onEditingEnded: { model.markTouched(field) })
        }
    }
}

#if DEBUG
struct TextAreaFieldView_Previews: PreviewProvider {
    static var previews: some View {
        JackpotPreviewPanel("Empty") {
            TextAreaFieldView(field: FormPreview.notes, model: FormPreview.model([FormPreview.notes]))
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**43.** `Packages/JackpotForms/Sources/JackpotFormsUI/Fields/WelcomeOfferFieldView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

struct WelcomeOfferFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel
    @Environment(\.jackpotTheme) private var theme

    private var isUnlocked: Bool { model.isFormValid }
    private var selected: String { model.value(for: field).stringValue }

    var body: some View {
        VStack(spacing: 10) {
            Text(model.localized(field.labelKey))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 10) {
                ForEach(model.options(for: field)) { option in
                    JackpotSelectableCard(isSelected: selected == option.id, isEnabled: isUnlocked) {
                        model.setValue(.option(option.id), for: field)
                        model.markTouched(field)
                    } content: {
                        Text(option.label)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .jackpotLocked(!isUnlocked, message: "Complete your registration above to unlock your Welcome offer selection")

            JackpotButton("Not yet", kind: .secondary, isEnabled: isUnlocked) {
                model.setValue(.option(""), for: field)
                model.markTouched(field)
            }
        }
    }
}

#if DEBUG
struct WelcomeOfferFieldView_Previews: PreviewProvider {
    private static let fields = [FormPreview.mobile, FormPreview.email, FormPreview.welcomeOffer]

    static var previews: some View {
        Group {
            JackpotPreviewPanel("Locked") {
                WelcomeOfferFieldView(field: FormPreview.welcomeOffer, model: FormPreview.model(fields))
            }.previewDisplayName("Welcome offer — locked")
            JackpotPreviewPanel("Unlocked · selected") {
                WelcomeOfferFieldView(field: FormPreview.welcomeOffer, model: FormPreview.model(fields, values: [
                    "username": .text("849134302"), "email": .text("hi@example.com"), "welcomeOffer": .option("depositMatch"),
                ]))
            }.previewDisplayName("Welcome offer — selected")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**44.** `Packages/JackpotForms/Sources/JackpotFormsUI/DynamicFormView.swift`

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

public struct DynamicFormView: View {
    public typealias SubmitHandler = (FormSubmission) async throws -> Void

    private let formName: FormName
    private let onSubmit: SubmitHandler

    @Environment(\.formDependencies) private var dependencies
    @Environment(\.jackpotTheme) private var theme
    @StateObject private var model: DynamicFormModel
    @State private var hasLoaded = false

    public init(formName: FormName, onSubmit: @escaping SubmitHandler) {
        self.formName = formName
        self.onSubmit = onSubmit

        _model = StateObject(wrappedValue: DynamicFormModel(
            formName: formName,
            dependencies: FormDependencies(repository: UnavailableFormRepository()),
            isConfigured: false
        ))
    }

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

struct DynamicFormBody: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler
    @Environment(\.jackpotTheme) private var theme

    var body: some View {
        switch model.viewState {
        case .loading:
            JackpotSkeleton().padding(16)

        case .failed(let message):
            JackpotErrorView(title: "Couldn't load this form", message: message) { model.load() }

        case .loaded:
            VStack(spacing: 0) {
                if model.sections.count > 1 {
                    JackpotProgressBar(progress: model.progress)
                        .padding(.horizontal, 16).padding(.top, 12)
                        .accessibilityLabel("Form progress")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing) {
                        if let section = model.currentSection {
                            ForEach(section.rows) { row in FormRowView(row: row, model: model) }
                        }
                        if let error = model.submitError {
                            Text(error).font(.footnote).foregroundColor(theme.error)
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
                }

                FormNavigationBar(model: model, onSubmit: onSubmit)
                    .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(theme.surface)
            .animation(.easeOut(duration: 0.2), value: model.sectionIndex)
        }
    }
}

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

    var body: some View {
        HStack(spacing: 12) {
            if !model.isFirstSection {
                JackpotButton("Previous", kind: .secondary) { model.goBack() }
            }
            if model.isLastSection {
                JackpotButton("Sign Up", isEnabled: model.isFormValid, isLoading: model.isSubmitting) {
                    Task { await model.submit(onSubmit) }
                }
            } else {
                JackpotButton("Next", isEnabled: model.isCurrentSectionValid) { model.advance() }
            }
        }
    }
}

#if DEBUG
struct DynamicFormView_Previews: PreviewProvider {
    private struct Harness: View {
        let model: DynamicFormModel
        var body: some View {
            DynamicFormBody(model: model) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.surface)
                .preferredColorScheme(.dark)
        }
    }

    static var previews: some View {
        Group {
            Harness(model: .preview(schema: FormPreview.registration))
                .previewDisplayName("Section 1 — empty")
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

**45.** `Packages/JackpotForms/Sources/JackpotFormsUI/Demo/PreviewSupport.swift`

```swift
import Foundation
import SwiftUI
import JackpotFormsDomain

public extension ComposedKeyLocalizer {
    static let jpcRegistration = ComposedKeyLocalizer(table: [

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

        "jpc-reg-idnumber": "South African ID",
        "jpc-reg-passport": "Passport",
        "jpc-reg-SalaryOrWages": "Salary or Wages",
        "jpc-reg-PensionOrGrant": "Pension or Grant",
        "jpc-reg-AllowanceOrBursary": "Allowance or Bursary",
        "jpc-reg-SavingsOrRentalOrOther": "Savings, Rental or Other",
        "jpc-reg-SelfEmployed": "Self Employed",

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

    public static var bundledForms: [FormName: Data] {
        Dictionary(uniqueKeysWithValues: FormName.bundled.map { ($0, bundledJSON(named: $0.rawValue)) })
    }
}
```

**46.** `Packages/JackpotForms/Sources/JackpotFormsUI/Demo/FormSandboxView.swift`

```swift
import SwiftUI
import JackpotFormsDomain

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

                    lastSubmission = submission.stringValues
                    showsSubmission = true
                }
                .id(selected.id)
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

**47.** `Packages/JackpotForms/Sources/JackpotFormsUI/Resources/registration.json`

```json
{
  "formId": 1052,
  "formCodeName": "registration",
  "formTitle": "registration",
  "formSubTitle": "registration",
  "regionCode": "JZA",
  "sections": [
    {
      "formSectionId": 45,
      "formSectionCodeName": "1",
      "formSectionTitle": "1",
      "formSectionSubTitle": "1",
      "formSectionOrder": 1,
      "rows": [
        { "rowNumber": 1, "fields": [ { "fieldId": 329, "fieldIdentifier": "username", "fieldName": "username", "fieldLabel": "username", "fieldType": "Input", "inputType": "Number", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(27|0)?[1-9][0-9]{8}$", "prefix": "+27", "suffix": "", "fieldPlaceholder": "username", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 2, "fields": [ { "fieldId": 330, "fieldIdentifier": "password", "fieldName": "password", "fieldLabel": "password", "fieldType": "Input", "inputType": "Password", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(.){8,20}$", "prefix": "", "suffix": "", "fieldPlaceholder": "password", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 3, "fields": [ { "fieldId": 331, "fieldIdentifier": "firstname", "fieldName": "first name", "fieldLabel": "firstname", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$", "prefix": "", "suffix": "", "fieldPlaceholder": "firstname", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 4, "fields": [ { "fieldId": 332, "fieldIdentifier": "lastname", "fieldName": "last name", "fieldLabel": "lastname", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$", "prefix": "", "suffix": "", "fieldPlaceholder": "lastname", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 5, "fields": [ { "fieldId": 333, "fieldIdentifier": "email", "fieldName": "email", "fieldLabel": "email", "fieldType": "Input", "inputType": "Email", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", "prefix": "", "suffix": "", "fieldPlaceholder": "email", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 6, "fields": [ { "fieldId": 334, "fieldIdentifier": "referralCode", "fieldName": "referral code", "fieldLabel": "referralCode", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z0-9]{3,25}$|^$", "prefix": "", "suffix": "", "fieldPlaceholder": "referralCode", "fieldDropdowns": [], "fieldRadioGroup": [] } ] }
      ]
    },
    {
      "formSectionId": 46,
      "formSectionCodeName": "2",
      "formSectionTitle": "2",
      "formSectionSubTitle": "2",
      "formSectionOrder": 2,
      "rows": [
        { "rowNumber": 1, "fields": [ { "fieldId": 335, "fieldIdentifier": "idNumberType", "fieldName": "id number type", "fieldLabel": "idNumberType", "fieldType": "Dropdown", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z]+$", "prefix": "", "suffix": "", "fieldPlaceholder": "idNumberType", "fieldDropdowns": [ { "value": "idNumber", "text": "jpc-reg-idnumber", "regex": "idNumberRegex" }, { "value": "passport", "text": "jpc-reg-passport", "regex": "passportNumberRegex" } ], "fieldRadioGroup": [] } ] },
        { "rowNumber": 2, "fields": [ { "fieldId": 336, "fieldIdentifier": "idNumber", "fieldName": "id number", "fieldLabel": "idNumber", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[0-9]{13}$", "prefix": "", "suffix": "", "fieldPlaceholder": "idNumber", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 3, "fields": [ { "fieldId": 337, "fieldIdentifier": "dateOfBirth", "fieldName": "date of birth", "fieldLabel": "dateOfBirth", "fieldType": "Input", "inputType": "Calender", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$", "prefix": "", "suffix": "", "fieldPlaceholder": "dateOfBirth", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 4, "fields": [ { "fieldId": 338, "fieldIdentifier": "sourceOfFunds", "fieldName": "source of funds", "fieldLabel": "sourceOfFunds", "fieldType": "Dropdown", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z]+$", "prefix": "", "suffix": "", "fieldPlaceholder": "sourceOfFunds", "fieldDropdowns": [ { "value": "SalaryOrWages", "text": "jpc-reg-SalaryOrWages", "regex": "[a-zA-Z]" }, { "value": "PensionOrGrant", "text": "jpc-reg-PensionOrGrant", "regex": "[a-zA-Z]" }, { "value": "AllowanceOrBursary", "text": "jpc-reg-AllowanceOrBursary", "regex": "[a-zA-Z]" }, { "value": "SavingsOrRentalOrOther", "text": "jpc-reg-SavingsOrRentalOrOther", "regex": "[a-zA-Z]" }, { "value": "SelfEmployed", "text": "jpc-reg-SelfEmployed", "regex": "[a-zA-Z]" } ], "fieldRadioGroup": [] } ] },
        { "rowNumber": 5, "fields": [ { "fieldId": 339, "fieldIdentifier": "receivePromotionalInformation", "fieldName": "receive promotional information", "fieldLabel": "receivePromotionalInformation-jza", "fieldType": "Checkbox", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "^true|^false$", "prefix": "", "suffix": "", "fieldPlaceholder": "receivePromotionalInformation", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 6, "fields": [ { "fieldId": 340, "fieldIdentifier": "terms", "fieldName": "terms", "fieldLabel": "terms", "fieldType": "Checkbox", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^true$", "prefix": "", "suffix": "", "fieldPlaceholder": "acceptTermsConditions", "fieldDropdowns": [], "fieldRadioGroup": [] } ] }
      ]
    }
  ]
}
```

**48.** `Packages/JackpotForms/Sources/JackpotFormsUI/Resources/kitchenSink.json`

```json
{
  "formId": 9001,
  "formCodeName": "kitchenSink",
  "formTitle": "Every field type",
  "formSubTitle": "renderer coverage",
  "regionCode": "JZA",
  "sections": [
    {
      "formSectionId": 1, "formSectionCodeName": "1", "formSectionTitle": "Inputs", "formSectionSubTitle": "",
      "formSectionOrder": 1,
      "rows": [
        { "rowNumber": 1, "fields": [ { "fieldId": 1, "fieldIdentifier": "plainText", "fieldName": "plain text", "fieldLabel": "Plain text", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^.{2,}$", "prefix": "", "suffix": "", "fieldPlaceholder": "Type something", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 2, "fields": [ { "fieldId": 2, "fieldIdentifier": "withPrefix", "fieldName": "prefixed", "fieldLabel": "Prefixed number", "fieldType": "Input", "inputType": "Number", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[0-9]{0,9}$", "prefix": "+27", "suffix": "", "fieldPlaceholder": "Mobile", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 3, "fields": [ { "fieldId": 3, "fieldIdentifier": "secret", "fieldName": "password", "fieldLabel": "Password", "fieldType": "Input", "inputType": "Password", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(.){8,20}$", "prefix": "", "suffix": "", "fieldPlaceholder": "Password", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 4, "fields": [ { "fieldId": 4, "fieldIdentifier": "notes", "fieldName": "notes", "fieldLabel": "Notes", "fieldType": "Text Area", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "", "prefix": "", "suffix": "", "fieldPlaceholder": "Anything else?", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 5, "fields": [ { "fieldId": 5, "fieldIdentifier": "spacer", "fieldName": "divider", "fieldLabel": "", "fieldType": "Divider", "inputType": "Text", "textStyle": "Regular", "validationMessage": "", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "", "prefix": "", "suffix": "", "fieldPlaceholder": "", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 6, "fields": [ { "fieldId": 6, "fieldIdentifier": "futureThing", "fieldName": "future", "fieldLabel": "Not shipped yet", "fieldType": "SignaturePad", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^.+$", "prefix": "", "suffix": "", "fieldPlaceholder": "", "fieldDropdowns": [], "fieldRadioGroup": [] } ] }
      ]
    },
    {
      "formSectionId": 2, "formSectionCodeName": "2", "formSectionTitle": "Choices", "formSectionSubTitle": "",
      "formSectionOrder": 2,
      "rows": [
        { "rowNumber": 1, "fields": [ { "fieldId": 7, "fieldIdentifier": "pickOne", "fieldName": "dropdown", "fieldLabel": "Dropdown", "fieldType": "Dropdown", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z]+$", "prefix": "", "suffix": "", "fieldPlaceholder": "Choose one", "fieldDropdowns": [ { "value": "alpha", "text": "Alpha", "regex": "[a-zA-Z]" }, { "value": "beta", "text": "Beta", "regex": "[a-zA-Z]" } ], "fieldRadioGroup": [] } ] },
        { "rowNumber": 2, "fields": [ { "fieldId": 8, "fieldIdentifier": "radio", "fieldName": "radio group", "fieldLabel": "Radio group", "fieldType": "Radio Group", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^.+$", "prefix": "", "suffix": "", "fieldPlaceholder": "", "fieldDropdowns": [], "fieldRadioGroup": [ { "value": "one", "text": "Option one" }, { "value": "two", "text": "Option two" } ] } ] },
        { "rowNumber": 3, "fields": [ { "fieldId": 9, "fieldIdentifier": "when", "fieldName": "date", "fieldLabel": "A date", "fieldType": "Input", "inputType": "Calender", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$", "prefix": "", "suffix": "", "fieldPlaceholder": "Pick a date", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 4, "fields": [ { "fieldId": 10, "fieldIdentifier": "optIn", "fieldName": "toggle", "fieldLabel": "A toggle", "fieldType": "Toggle", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "^true|^false$", "prefix": "", "suffix": "", "fieldPlaceholder": "", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 5, "fields": [ { "fieldId": 11, "fieldIdentifier": "agree", "fieldName": "checkbox", "fieldLabel": "I agree to the thing", "fieldType": "Checkbox", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^true$", "prefix": "", "suffix": "", "fieldPlaceholder": "", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 6, "fields": [ { "fieldId": 12, "fieldIdentifier": "welcomeOffer", "fieldName": "welcome offer", "fieldLabel": "Select your Welcome Offer:", "fieldType": "Welcome Offer", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "", "prefix": "", "suffix": "", "fieldPlaceholder": "", "fieldDropdowns": [ { "value": "depositMatch", "text": "100% Deposit Match", "regex": "" }, { "value": "freeSpins", "text": "50 Free Spins", "regex": "" } ], "fieldRadioGroup": [] } ] }
      ]
    }
  ]
}
```

**49.** `Packages/JackpotForms/Sources/JackpotForms/JackpotForms.swift`

```swift
import Foundation
import JackpotFormsDomain
import JackpotFormsUI
import JackpotFormsData

public extension FormDependencies {
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: FormPreviewData.bundledForms, delay: delay, error: error),
            localizer: localizer ?? ComposedKeyLocalizer.jpcRegistration
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

**50.** `Packages/JackpotForms/Tests/JackpotFormsTests/Fixtures/registration.json`

```json
{
  "formId": 1052,
  "formCodeName": "registration",
  "formTitle": "registration",
  "formSubTitle": "registration",
  "regionCode": "JZA",
  "sections": [
    {
      "formSectionId": 45,
      "formSectionCodeName": "1",
      "formSectionTitle": "1",
      "formSectionSubTitle": "1",
      "formSectionOrder": 1,
      "rows": [
        { "rowNumber": 1, "fields": [ { "fieldId": 329, "fieldIdentifier": "username", "fieldName": "username", "fieldLabel": "username", "fieldType": "Input", "inputType": "Number", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(27|0)?[1-9][0-9]{8}$", "prefix": "+27", "suffix": "", "fieldPlaceholder": "username", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 2, "fields": [ { "fieldId": 330, "fieldIdentifier": "password", "fieldName": "password", "fieldLabel": "password", "fieldType": "Input", "inputType": "Password", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(.){8,20}$", "prefix": "", "suffix": "", "fieldPlaceholder": "password", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 3, "fields": [ { "fieldId": 331, "fieldIdentifier": "firstname", "fieldName": "first name", "fieldLabel": "firstname", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$", "prefix": "", "suffix": "", "fieldPlaceholder": "firstname", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 4, "fields": [ { "fieldId": 332, "fieldIdentifier": "lastname", "fieldName": "last name", "fieldLabel": "lastname", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z][a-zA-Z\\-\\.'\\s]{1,20}$", "prefix": "", "suffix": "", "fieldPlaceholder": "lastname", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 5, "fields": [ { "fieldId": 333, "fieldIdentifier": "email", "fieldName": "email", "fieldLabel": "email", "fieldType": "Input", "inputType": "Email", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", "prefix": "", "suffix": "", "fieldPlaceholder": "email", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 6, "fields": [ { "fieldId": 334, "fieldIdentifier": "referralCode", "fieldName": "referral code", "fieldLabel": "referralCode", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z0-9]{3,25}$|^$", "prefix": "", "suffix": "", "fieldPlaceholder": "referralCode", "fieldDropdowns": [], "fieldRadioGroup": [] } ] }
      ]
    },
    {
      "formSectionId": 46,
      "formSectionCodeName": "2",
      "formSectionTitle": "2",
      "formSectionSubTitle": "2",
      "formSectionOrder": 2,
      "rows": [
        { "rowNumber": 1, "fields": [ { "fieldId": 335, "fieldIdentifier": "idNumberType", "fieldName": "id number type", "fieldLabel": "idNumberType", "fieldType": "Dropdown", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z]+$", "prefix": "", "suffix": "", "fieldPlaceholder": "idNumberType", "fieldDropdowns": [ { "value": "idNumber", "text": "jpc-reg-idnumber", "regex": "idNumberRegex" }, { "value": "passport", "text": "jpc-reg-passport", "regex": "passportNumberRegex" } ], "fieldRadioGroup": [] } ] },
        { "rowNumber": 2, "fields": [ { "fieldId": 336, "fieldIdentifier": "idNumber", "fieldName": "id number", "fieldLabel": "idNumber", "fieldType": "Input", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[0-9]{13}$", "prefix": "", "suffix": "", "fieldPlaceholder": "idNumber", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 3, "fields": [ { "fieldId": 337, "fieldIdentifier": "dateOfBirth", "fieldName": "date of birth", "fieldLabel": "dateOfBirth", "fieldType": "Input", "inputType": "Calender", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}(?:\\.\\d*)?)((-(\\d{2}):(\\d{2})|Z)?)$", "prefix": "", "suffix": "", "fieldPlaceholder": "dateOfBirth", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 4, "fields": [ { "fieldId": 338, "fieldIdentifier": "sourceOfFunds", "fieldName": "source of funds", "fieldLabel": "sourceOfFunds", "fieldType": "Dropdown", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^[a-zA-Z]+$", "prefix": "", "suffix": "", "fieldPlaceholder": "sourceOfFunds", "fieldDropdowns": [ { "value": "SalaryOrWages", "text": "jpc-reg-SalaryOrWages", "regex": "[a-zA-Z]" }, { "value": "PensionOrGrant", "text": "jpc-reg-PensionOrGrant", "regex": "[a-zA-Z]" }, { "value": "AllowanceOrBursary", "text": "jpc-reg-AllowanceOrBursary", "regex": "[a-zA-Z]" }, { "value": "SavingsOrRentalOrOther", "text": "jpc-reg-SavingsOrRentalOrOther", "regex": "[a-zA-Z]" }, { "value": "SelfEmployed", "text": "jpc-reg-SelfEmployed", "regex": "[a-zA-Z]" } ], "fieldRadioGroup": [] } ] },
        { "rowNumber": 5, "fields": [ { "fieldId": 339, "fieldIdentifier": "receivePromotionalInformation", "fieldName": "receive promotional information", "fieldLabel": "receivePromotionalInformation-jza", "fieldType": "Checkbox", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": false, "isVisible": true, "isReadOnly": false, "fieldRegex": "^true|^false$", "prefix": "", "suffix": "", "fieldPlaceholder": "receivePromotionalInformation", "fieldDropdowns": [], "fieldRadioGroup": [] } ] },
        { "rowNumber": 6, "fields": [ { "fieldId": 340, "fieldIdentifier": "terms", "fieldName": "terms", "fieldLabel": "terms", "fieldType": "Checkbox", "inputType": "Text", "textStyle": "Regular", "validationMessage": "regex", "isRequired": true, "isVisible": true, "isReadOnly": false, "fieldRegex": "^true$", "prefix": "", "suffix": "", "fieldPlaceholder": "acceptTermsConditions", "fieldDropdowns": [], "fieldRadioGroup": [] } ] }
      ]
    }
  ]
}
```

**51.** `Packages/JackpotForms/Tests/JackpotFormsTests/FormDecodingTests.swift`

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

    func testCalendarInputTypeAcceptsBothSpellings() {
        XCTAssertEqual(InputType(raw: "Calender"), .calendar)
        XCTAssertEqual(InputType(raw: "Calendar"), .calendar)
        XCTAssertEqual(InputType(raw: "date"), .calendar)
    }

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
        XCTAssertFalse(field.isRequired)
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

**52.** `Packages/JackpotForms/Tests/JackpotFormsTests/FieldValidatorTests.swift`

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

    func testMobileNumberPattern() {
        let mobile = field("username", inputType: .number, regex: "^(27|0)?[1-9][0-9]{8}$")
        XCTAssertTrue(validator.validate(.text("849134302"), against: mobile).isValid)
        XCTAssertTrue(validator.validate(.text("0849134302"), against: mobile).isValid)
        XCTAssertTrue(validator.validate(.text("27849134302"), against: mobile).isValid)
        XCTAssertFalse(validator.validate(.text("049134302"), against: mobile).isValid)
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

    func testRequiredEmptyFails() {
        XCTAssertFalse(validator.validate(.text(""), against: field("a", regex: "^.+$")).isValid)
        XCTAssertFalse(validator.validate(.text("   "), against: field("a", regex: "^.+$")).isValid)
    }

    func testOptionalEmptyPassesEvenWhenTheRegexWouldNot() {
        let optional = field("referralCode", required: false, regex: "^[a-zA-Z0-9]{3,25}$")
        XCTAssertTrue(validator.validate(.text(""), against: optional).isValid)
        XCTAssertFalse(validator.validate(.text("ab"), against: optional).isValid)
        XCTAssertTrue(validator.validate(.text("WELCOME50"), against: optional).isValid)
    }

    func testRequiredCheckboxMustBeTicked() {
        let terms = field("terms", type: .checkbox, regex: "^true$")
        XCTAssertFalse(validator.validate(.bool(false), against: terms).isValid)
        XCTAssertTrue(validator.validate(.bool(true), against: terms).isValid)
    }

    func testMalformedServerPatternDoesNotBlockTheUser() {
        let broken = field("oops", regex: "^[a-z")
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

    func testNamedRegexResolvesFromTheCatalogue() {
        XCTAssertEqual(validator.optionPattern("idNumberRegex"), "^[0-9]{13}$")
        XCTAssertNotNil(validator.optionPattern("passportNumberRegex"))
    }

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

        XCTAssertTrue(validator.validate(.text("A1234567"), against: id,
                                        overrideRegex: "^[a-zA-Z0-9]{6,12}$").isValid)
        XCTAssertFalse(validator.validate(.text("A1234567"), against: id).isValid)
    }

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

**53.** `Packages/JackpotForms/Tests/JackpotFormsTests/DynamicFormModelTests.swift`

```swift
import XCTest
@testable import JackpotFormsUI
import JackpotFormsData
import JackpotFormsDomain

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

    func testLoadsSchemaAndSeedsEveryField() async throws {
        let model = try await loaded()
        XCTAssertEqual(model.sections.count, 2)
        XCTAssertEqual(model.sectionIndex, 0)
        XCTAssertTrue(model.isFirstSection)
        XCTAssertFalse(model.isLastSection)

        XCTAssertEqual(model.value(for: try field(model, "terms")), .bool(false))
    }

    func testUntouchedFieldsShowNoErrorEvenWhenInvalid() async throws {
        let model = try await loaded()
        let mobile = try field(model, "username")
        XCTAssertNil(model.error(for: mobile))
        model.markTouched(mobile)
        XCTAssertNotNil(model.error(for: mobile))
    }

    func testAdvancingRevealsEveryErrorInTheSection() async throws {
        let model = try await loaded()
        XCTAssertFalse(model.advance())
        XCTAssertEqual(model.sectionIndex, 0)
        for id in ["username", "password", "firstname", "lastname", "email"] {
            XCTAssertNotNil(model.error(for: try field(model, id)), "\(id) should show an error")
        }

        XCTAssertNil(model.error(for: try field(model, "referralCode")))
    }

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
}

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

    func testLiteralOptionPatternsDoNotLeakOntoOtherFields() async throws {
        let model = try await loadedSectionTwo()
        let source = try field(model, "sourceOfFunds")
        let promo = try field(model, "receivePromotionalInformation")

        model.setValue(.option("SalaryOrWages"), for: source)
        model.setValue(.bool(true), for: promo)
        model.markTouched(promo)
        XCTAssertNil(model.error(for: promo))
    }

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

**54.**

```bash
xcodebuild -scheme JackpotForms -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotForms

`Executed 41 tests, with 0 failures`

Open `Previews.swift` in `JackpotFormsUI` and resume the whole-form previews.

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
