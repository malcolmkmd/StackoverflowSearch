# Build Playbook

Create the files in the order given. Run the commands where they appear. Open a PR where
marked. Every code block is the file exactly as it is in the repository, and every
`Package.swift` block is the manifest as it stands after that step.

Six steps. The registration sheet runs from step 2 with no backend. It goes live in the app
at step 4, on the app's existing translation function. Steps 5 and 6 are the localisation
and app-data migrations from
[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md); registration
does not wait for them.

| Step | Adds | Demoable as |
| --- | --- | --- |
| 1 | `JackpotUI` | the gallery: every component, every state |
| 2 | `JackpotForms` on the bundled schema, `JackpotRegistration` | the Sign Up sheet, both pages, faked submit |
| 3 | `JackpotNetworking` | `RemoteApiClient` against a stubbed transport |
| 4 | `JackpotForms/Remote`, `.live()`, the app swap | registration live in the app, copy from `getTranslation` |
| 5 | `JackpotLocalization`, `Translations.formLocalizer` | error codes in the player's language; `getTranslation` becomes a shim |
| 6 | `JackpotAppData` | config served from disk on launch, revalidated behind it |

`JackpotKit` is one package; each folder under `Sources/` is a module. The floor is iOS 15,
the host app's. The test suite stays in this repository; the playbook lists source files only.

### Registration catalog

Twelve fields over two sections, checked against the bundled capture and the live CRM
response. The `fieldType` values on registration are **Input**, **Dropdown** and
**Checkbox**; `FieldType` has exactly those three cases plus `unknown`. Date of birth is
`Input` + `inputType: Calender` (the schema spelling).

| Step | Identifier | `fieldType` | `inputType` | Renders as |
| --- | --- | --- | --- | --- |
| 1.1 | `username` | Input | Number | `JackpotTextField` · `.phoneNumber` · `+27` prefix |
| 1.2 | `password` | Input | Password | `JackpotTextField` · `.newPassword` · `JackpotChecklist` while focused |
| 1.3 | `firstname` | Input | Text | `JackpotTextField` · `.givenName` |
| 1.4 | `lastname` | Input | Text | `JackpotTextField` · `.familyName` |
| 1.5 | `email` | Input | Email | `JackpotTextField` · `.email` |
| 1.6 | `referralCode` | Input | Text | `JackpotTextField` · optional |
| 2.1 | `idNumberType` | Dropdown | Text | `JackpotDropdown` · drives the `idNumber` regex |
| 2.2 | `idNumber` | Input | Text | `JackpotTextField` |
| 2.3 | `dateOfBirth` | Input | Calender | `JackpotDateField` · capped at 18 years ago |
| 2.4 | `sourceOfFunds` | Dropdown | Text | `JackpotDropdown` |
| 2.5 | `receivePromotionalInformation` | Checkbox | Text | `Toggle` · `.jackpotCheckbox` |
| 2.6 | `terms` | Checkbox | Text | `Toggle` · `.jackpotCheckbox` · required `^true$` |

The bundled capture ships `username.prefix = "+27"`; the live payload currently leaves
prefix empty (the view still maps `username` to `.phoneNumber`).

Every field keeps its label **inside** the control: it sits where a placeholder would and
floats to the top edge on focus or once there is a value (`JackpotFloatingField`). Error
text sits beneath the control and the ring turns red, both from one modifier,
`.jackpotFieldError(_:)`. Field data — label, kind, prefix — is an initialiser argument on
the field; only the theme, a button's loading state and the shared focus value travel
through the environment.

### How to go to the next screen

The buttons at the bottom of registration are `FormNavigationBar` in `DynamicFormContent.swift`,
which registration places in the panel's footer under the login row. `RegistrationView`
owns a `DynamicFormModel` and composes `DynamicFormContent` (the pages) and
`FormNavigationBar` around it. The bundled `registration.json` and the live CRM schema are
the twelve fields above — paging is not a field.

| Visible control | Style | When | Action |
| --- | --- | --- | --- |
| **Next** | `.jackpot` (primary) | Section 1 — not last | `DynamicFormModel.advance()` |
| **Previous** | `.jackpot(.secondary)` | Section 2+ | `goBack()` — values kept |
| **Sign Up** | `.jackpot` (primary) | Last section | `model.submit()` |

`Next` stays **disabled** — the accent fill dimmed to `accentFillDisabled` under
`textPrimary` — until every visible field on the current section validates
(`isCurrentSectionValid`); tapping it increments `sectionIndex`. `Sign Up` stays disabled
until `isFormValid`, then `submit()` posts through `FormRepository.submitForm` and hands the
result to `onComplete`. A progress bar (`.jackpotBar`) sits above the scroll view when
`sections.count > 1`.

### Registration rules and the preview path

1. **Schema.** `JackpotForms/Resources/registration.json`, the CRM's response saved
   verbatim. `BundledForms.all` reads it; `StubFormRepository` serves it.
2. **Mock wiring.** `FormDependencies.mock()` is the stub repository plus the placeholder
   copy table `ClosureLocalizer.jpcRegistration`. `.live(baseURL:localizer:)` swaps in
   `RemoteFormRepository` at step 4; nothing else changes.
3. **Registration's rules.** The engine ships with no cross-field regex links and no date
   cap. `RegistrationDependencies` adds `regexDependencies: ["idNumberType": "idNumber"]`
   and an 18-years-ago `maximumDate` on top of whatever `forms` the host passes in.
4. **Sandbox.** In this repository the app's `SearchView` presents `RegistrationSandbox` with
   `.jackpotPopup`, the way the app presents its panels; the sandbox hosts
   `RegistrationView(dependencies: .mock())` and shows the `RegistrationResult` it gets
   back, so the whole panel runs on a device with no backend.
5. **Previews.** `FormPreview.registration` decodes the bundled JSON through the real mapper
   for the seeded-model previews in `DynamicFormContent.swift` and each field view.
   `JackpotPreviewPanel.swift` is the component gallery.
6. **The sheet.** `RegistrationView` is the form inside `JackpotPanel`: title and close
   button on `surface`, the pages on `background`, and in the footer band `JackpotLinkRow`
   with `FormNavigationBar` beneath it. **Sign Up — dark / light** in
   `JackpotRegistration/Previews.swift` and **Sheet shell** in the gallery render it in both
   appearances.

---

## Step 1 — JackpotUI

The design system, with no knowledge of forms. Components take a title, a binding and their
own configuration; the theme travels through the environment. Every component previews
alone in the gallery.

### Colour tokens

Locked `JackpotColors` set. Same hex is one `Palette` entry — roles that share a value point
at it, and a role gets its own name when it can diverge (`surface` and `fieldBackground`).
There is no `link` token; that Android role is `accent`.

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| `background` | #FFFFFF | #131316 | The base layer screens and components draw on; the form body, the Previous button, and the close button and login row on a band (Android `formBackground`) |
| `surface` | #F0F0F2 | #202126 | The raised layer: sheet header and footer bands, the date picker sheet (Android `surface`) |
| `fieldBackground` | #F0F0F2 | #202126 | Field fill and the checklist — same pair as `surface`, its own role |
| `fieldBorder` | #E1E2E6 | #3E3E48 | Hairline, progress track, Previous button |
| `fieldBorderFocused` | #0060EC | #0060EC | Focus ring, the brand blue in both appearances (same value as `accentFill`) |
| `fieldBorderInvalid` | #DF0000 | #FF6B6B | Invalid ring — same value as `error` |
| `textPrimary` | #2F2F37 | #E1E1E5 | Titles and values (Android `titleText` / Text Priority) |
| `textSecondary` | #565A63 | #E1E1E5 | Labels and placeholders |
| `textOnAccent` | #FFFFFF | #FFFFFF | Label on `accentFill` |
| `accent` | #0060EC | #4D8FFF | Tint, raised label when focused, ticks (Android `link`) |
| `accentFill` | #0060EC | #0060EC | Primary button fill |
| `accentFillDisabled` | #D4E4F8 | #262B3B | Disabled primary button fill, under `textPrimary`. Both read from the app's screens pending the Android pair |
| `error` | #DF0000 | #FF6B6B | Validation and load errors |
| `warning` | #945C05 | #F59E21 | Checklist incomplete |
| `success` | #0F7542 | #33B870 | Checklist complete |

Android light-mode `bodyText` / `labelText` / `placeholderText` / `primary` / `onPrimary` /
`link` were all #E1E1E5 — 1.15:1 on #F0F0F2. Light text uses the documented Text Priority
hex and the existing #565A63 secondary; interactive fills keep the isolated brand blue so
`textOnAccent` still clears 4.5:1. Dark `error` lightens from #DF0000 because the brand red
is ~3.2:1 on #202126. Light `error` on the field fill is 4.46:1, the locked #DF0000.

**1.**

```bash
mkdir -p JackpotKit/Sources/JackpotUI/{Theme,Styles,Fields,Components,Preview}
cd JackpotKit
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

**2.** `JackpotKit/Package.swift` — the whole file after this step

One module. Every target opts into strict concurrency checking to match
the app's `SWIFT_STRICT_CONCURRENCY = complete`.

```swift
// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module. In Xcode: File → Add Package
// Dependencies → Add Local… → JackpotKit, then add the product you need to the app target.
// The floor is iOS 15, the host app's. docs/BUILD-PLAYBOOK.md builds this manifest one step at a
// time, and scripts/build-playbook.py checks that its final step matches this file exactly.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),
    ]
)
```

**3.** `JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift`

Adaptive light/dark palette. Hexes are the locked token table above; `Palette.emphasis`
is the shared #E1E1E5 for dark text.

```swift
import SwiftUI
import UIKit

public struct JackpotTheme: Equatable, Sendable {
    public var colors: JackpotColors = .jackpotCity
    public var sizes: JackpotSizes = .standard
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
    /// The base layer; also the fill of a control resting on a `surface` band.
    public var background = Palette.background
    /// Sheet header and footer bands, presented pickers.
    public var surface = Palette.surface

    /// Same pair as `surface` today; its own role so a theme can separate them.
    public var fieldBackground = Palette.surface
    public var fieldBorder = Palette.fieldBorder
    /// The brand blue in both appearances; #E1E1E5 was invisible on the light field fill.
    public var fieldBorderFocused = Palette.accentFill
    public var fieldBorderInvalid = Palette.error

    public var textPrimary = Palette.textPrimary
    public var textSecondary = Palette.textSecondary
    public var textOnAccent = Palette.textOnAccent

    public var accent = Palette.accent
    public var accentFill = Palette.accentFill
    /// A primary button that cannot be tapped yet, under `textPrimary`.
    public var accentFillDisabled = Palette.accentFillDisabled

    public var error = Palette.error
    public var warning = Palette.warning
    public var success = Palette.success

    public static let jackpotCity = JackpotColors()
}

/// Each hex once, as shared constants so two `JackpotColors` compare equal; roles that share a pair point at one entry.
enum Palette {
    static let background = Color.adaptive(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x131316))
    static let surface = Color.adaptive(light: Color(hex: 0xF0F0F2), dark: Color(hex: 0x202126))
    static let fieldBorder = Color.adaptive(light: Color(hex: 0xE1E2E6), dark: Color(hex: 0x3E3E48))

    /// Android's dark text value. Light text uses readable greys instead.
    static let emphasis = Color(hex: 0xE1E1E5)
    static let textPrimary = Color.adaptive(light: Color(hex: 0x2F2F37), dark: emphasis)
    static let textSecondary = Color.adaptive(light: Color(hex: 0x565A63), dark: emphasis)
    static let textOnAccent = Color.white

    static let accent = Color.adaptive(light: Color(hex: 0x0060EC), dark: Color(hex: 0x4D8FFF))
    static let accentFill = Color(hex: 0x0060EC)
    /// Read from the app's screens; replace with the Android pair.
    static let accentFillDisabled = Color.adaptive(light: Color(hex: 0xD4E4F8), dark: Color(hex: 0x262B3B))

    static let error = Color.adaptive(light: Color(hex: 0xDF0000), dark: Color(hex: 0xFF6B6B))
    static let warning = Color.adaptive(light: Color(hex: 0x945C05), dark: Color(hex: 0xF59E21))
    static let success = Color.adaptive(light: Color(hex: 0x0F7542), dark: Color(hex: 0x33B870))
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Resolves through the trait collection, so a `preferredColorScheme` override applies.
    static func adaptive(light: Color, dark: Color) -> Color {
        let light = UIColor(light)
        let dark = UIColor(dark)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Spacing

/// `CGFloat`-backed so SwiftUI overloads take `.sm` like a native inset.
public enum JackpotSpacing: CGFloat, CaseIterable, Sendable {
    case xxs = 4
    case xs = 6
    case s = 8
    case sm = 12
    case m = 16
    case lm = 20
    case l = 24
    case xl = 32
    case xxl = 40
    case xxxl = 48
}

// MARK: - Sizes

public struct JackpotSizes: Equatable, Sendable {
    public var cornerRadius: CGFloat = JackpotSpacing.sm.rawValue
    public var controlHeight: CGFloat = 52
    public var spacing: CGFloat = JackpotSpacing.sm.rawValue
    public var contentPadding: CGFloat = JackpotSpacing.m.rawValue
    public var borderWidth: CGFloat = 1
    public var emphasizedBorderWidth: CGFloat = 2
    public var minimumHitTarget: CGFloat = 44
    public var progressBarHeight: CGFloat = JackpotSpacing.xxs.rawValue
    public var panelCornerRadius: CGFloat = JackpotSpacing.lm.rawValue

    public static let standard = JackpotSizes()

    public var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Typography

public struct JackpotTypography: Equatable, Sendable {
    public var title = Font.title2.weight(.bold)
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

The environment carries what genuinely cascades. `jackpotFieldError` is internal: it is
set by the `jackpotFieldError(_:)` modifier and read by the chrome.

```swift
import SwiftUI

// Only what genuinely cascades travels here; per-field data is an initialiser argument.
extension EnvironmentValues {
    @Entry public var jackpotTheme: JackpotTheme = .jackpotCity
    @Entry public var jackpotIsLoading: Bool = false
    @Entry public var jackpotFocusedField: Binding<String?>? = nil
    @Entry public var jackpotFieldIdentity: String? = nil

    /// Set by `jackpotFieldError(_:)`, read by the field chrome.
    @Entry var jackpotFieldError: String? = nil
}

// MARK: - Theme

public extension View {
    /// Sets `tint` too, so system controls follow the accent.
    func jackpotTheme(_ theme: JackpotTheme) -> some View {
        environment(\.jackpotTheme, theme).tint(theme.colors.accent)
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
    /// One focused-field value shared by a group so the return key can walk it; tag fields with `jackpotFieldIdentity(_:)`.
    func jackpotFocusedField(_ binding: Binding<String?>) -> some View {
        environment(\.jackpotFocusedField, binding)
    }

    func jackpotFieldIdentity(_ identity: String) -> some View {
        environment(\.jackpotFieldIdentity, identity)
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

    func padding(_ spacing: JackpotSpacing) -> some View {
        padding(spacing.rawValue)
    }

    func padding(_ edges: Edge.Set, _ spacing: JackpotSpacing) -> some View {
        padding(edges, spacing.rawValue)
    }

    func frame(width: JackpotSpacing,
               height: JackpotSpacing,
               alignment: Alignment = .center) -> some View {
        frame(width: width.rawValue, height: height.rawValue, alignment: alignment)
    }
}

public extension VStack {
    init(alignment: HorizontalAlignment = .center,
         spacing: JackpotSpacing,
         @ViewBuilder content: () -> Content) {
        self.init(alignment: alignment, spacing: spacing.rawValue, content: content)
    }
}

public extension HStack {
    init(alignment: VerticalAlignment = .center,
         spacing: JackpotSpacing,
         @ViewBuilder content: () -> Content) {
        self.init(alignment: alignment, spacing: spacing.rawValue, content: content)
    }
}

public extension EdgeInsets {
    init(_ spacing: JackpotSpacing) {
        self.init(top: spacing.rawValue,
                  leading: spacing.rawValue,
                  bottom: spacing.rawValue,
                  trailing: spacing.rawValue)
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

`.jackpot` is Next / Sign Up: `accentFill` + `textOnAccent` when enabled,
`accentFillDisabled` under `textPrimary` when disabled. `.jackpot(.secondary)` is Previous:
`background` fill, `fieldBorder` hairline, `textPrimary` label.

```swift
import SwiftUI

public struct JackpotButtonStyle: ButtonStyle {
    public enum Prominence: Hashable, Sendable {
        case primary
        case secondary
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
                .frame(maxWidth: .infinity, minHeight: theme.sizes.controlHeight)
                .foregroundStyle(foreground)
                .background { shell }
                .contentShape(theme.sizes.fieldShape)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
                .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
        }

        /// `jackpotLoading(_:)` disables the button, but mid-submit it should still look live.
        private var isDimmed: Bool { !isEnabled && !isLoading }

        @ViewBuilder
        private var shell: some View {
            switch prominence {
            case .primary:
                theme.sizes.fieldShape.fill(isDimmed ? theme.colors.accentFillDisabled : theme.colors.accentFill)
            case .secondary:
                theme.sizes.fieldShape
                    .fill(theme.colors.background)
                    .overlay {
                        theme.sizes.fieldShape
                            .strokeBorder(theme.colors.fieldBorder, lineWidth: theme.sizes.borderWidth)
                    }
            }
        }

        private var foreground: Color {
            switch prominence {
            case .primary:   return isDimmed ? theme.colors.textPrimary : theme.colors.textOnAccent
            case .secondary: return isDimmed ? theme.colors.textSecondary : theme.colors.textPrimary
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

**7.** `JackpotKit/Sources/JackpotUI/Styles/JackpotCheckboxToggleStyle.swift`

Registration's two consents use `.jackpotCheckbox`.

```swift
import SwiftUI

/// A tappable box with a wrapping label; VoiceOver is handed a switch.
public struct JackpotCheckboxToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CheckboxBody(configuration: configuration)
    }

    private struct CheckboxBody: View {
        let configuration: ToggleStyleConfiguration

        @Environment(\.jackpotTheme) private var theme
        @Environment(\.jackpotFieldError) private var error

        var body: some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack(alignment: .top, spacing: theme.sizes.spacing) {
                    Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(boxColor)
                        .frame(width: .l, height: .l)
                        .animation(.easeOut(duration: 0.15), value: configuration.isOn)
                    configuration.label
                        .jackpotTextStyle(\.rowLabel)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: theme.sizes.minimumHitTarget)
            }
            .buttonStyle(.plain)
            // The explicit style stops the stand-in resolving back to this one.
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
                    .toggleStyle(.switch)
            }
        }

        private var boxColor: Color {
            if configuration.isOn { return theme.colors.accent }
            return error == nil ? theme.colors.textSecondary : theme.colors.fieldBorderInvalid
        }
    }
}

public extension ToggleStyle where Self == JackpotCheckboxToggleStyle {
    static var jackpotCheckbox: JackpotCheckboxToggleStyle { JackpotCheckboxToggleStyle() }
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
            .frame(height: height ?? theme.sizes.progressBarHeight)
            .animation(.easeOut(duration: 0.25), value: fraction)
        }
    }
}

public extension ProgressViewStyle where Self == JackpotBarProgressViewStyle {
    static var jackpotBar: JackpotBarProgressViewStyle { JackpotBarProgressViewStyle() }

    static func jackpotBar(height: CGFloat) -> JackpotBarProgressViewStyle {
        JackpotBarProgressViewStyle(height: height)
    }

    static func jackpotBar(height: JackpotSpacing) -> JackpotBarProgressViewStyle {
        JackpotBarProgressViewStyle(height: height.rawValue)
    }
}

private extension Double {
    var clampedToUnitInterval: Double { min(max(self, 0), 1) }
}
```

**9.** `JackpotKit/Sources/JackpotUI/Fields/JackpotFieldKind.swift`

Keyboard / autofill kinds, passed as `kind:` to `JackpotTextField`. Registration uses
text, name, email, phone, number and new-password.

```swift
import SwiftUI

/// `TextInputAutocapitalization` is not `Equatable`, so the kind stores its own case.
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

/// Keyboard, autofill, autocorrection and secure entry as one value, passed as `kind:`.
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

    /// `.newPassword` opts into iOS's strong-password suggestion.
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

extension View {
    func textInput(_ kind: JackpotFieldKind) -> some View {
        keyboardType(kind.keyboard)
            .textContentType(kind.contentType)
            .textInputAutocapitalization(kind.capitalization.textInput)
            .autocorrectionDisabled(kind.disablesAutocorrection)
    }
}
```

**10.** `JackpotKit/Sources/JackpotUI/Fields/JackpotFieldChrome.swift`

The shared background, the `jackpotFieldError(_:)` row, and `JackpotFloatingField` — the
one place the in-field label's rise is laid out.

```swift
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
    /// The invalid ring and the message beneath the control; nil clears both.
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

/// The in-field label shared by text field, dropdown and date field; it rises when focused or holding a value.
struct JackpotFloatingField<Content: View>: View {
    private let title: String
    private let isFloating: Bool
    private let isFocused: Bool
    private let content: Content
    /// Clear of the value beneath it in a 52pt control.
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
                // Scaled rather than re-set in the label font, so the rise animates.
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
```

**11.** `JackpotKit/Sources/JackpotUI/Fields/JackpotTextField.swift`

Title, kind, prefix and suffix on `init`. Secure entry and the reveal button follow
from `kind.isSecure`.

```swift
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

    /// Fires on blur. Chain it before any `View` modifier.
    public func onEditingEnded(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.editingEndedAction = action
        return copy
    }

    /// Fires on focus and blur, for callers that show supporting content while editing.
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
                    // The prefix cell is hidden from VoiceOver, so fold it into the label.
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
        // The form moves the shared value and the field follows; guarded both ways so the two cannot ping-pong.
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
    private let title: String
    private let options: [JackpotOption]

    @Environment(\.jackpotTheme) private var theme

    public init(_ title: String, selection: Binding<String?>, options: [JackpotOption]) {
        self.title = title
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
            HStack(spacing: 0) {
                JackpotFloatingField(title, isFloating: selected != nil) {
                    if let selected {
                        Text(selected.label).jackpotTextStyle(\.fieldText)
                    }
                }
                Image(systemName: "chevron.down")
                    .jackpotForegroundStyle(\.textPrimary)
                    .padding(.trailing, theme.sizes.contentPadding)
            }
            .jackpotFieldBackground()
        }
        .accessibilityLabel(title)
        .accessibilityValue(selected?.label ?? "None")
    }

    private var selected: JackpotOption? {
        options.first { $0.id == selection }
    }
}
```

**13.** `JackpotKit/Sources/JackpotUI/Fields/JackpotDateField.swift`

The `Calender` input type: a read-only field presenting a wheel picker in a sheet.

```swift
import SwiftUI

public struct JackpotDateField: View {
    @Binding private var selection: Date?
    private let title: String
    private let range: PartialRangeThrough<Date>

    @Environment(\.jackpotTheme) private var theme
    @State private var isPresented = false

    public init(_ title: String,
                selection: Binding<Date?>,
                in range: PartialRangeThrough<Date> = ...Date()) {
        self.title = title
        self._selection = selection
        self.range = range
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 0) {
                JackpotFloatingField(title, isFloating: selection != nil) {
                    if let selection {
                        Text(Self.formatted(selection)).jackpotTextStyle(\.fieldText)
                    }
                }
                Image(systemName: "calendar")
                    .jackpotForegroundStyle(\.textPrimary)
                    .padding(.trailing, theme.sizes.contentPadding)
            }
            .jackpotFieldBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selection.map(Self.formatted) ?? "None")
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

    /// Before iOS 16 there are no detents, so the sheet is full height and the spacer pins the button down.
    private var sheetHeight: CGFloat { wheelHeight + 160 }

    private var wheelHeight: CGFloat { 216 }

    private var sheet: some View {
        ZStack {
            theme.colors.surface.ignoresSafeArea()

            VStack(spacing: theme.sizes.spacing) {
                Text(title)
                    .jackpotTextStyle(\.button)
                    .padding(.top, .lm)

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
                    // Confirming without dragging still counts as a choice.
                    if selection == nil { selection = range.upperBound }
                    isPresented = false
                }
                .buttonStyle(.jackpot)
                .padding([.horizontal, .bottom], .m)
            }
        }
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
```

**14.** `JackpotKit/Sources/JackpotUI/Components/JackpotChecklist.swift`

The live password-rules panel on `password`.

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
                VStack(alignment: .leading, spacing: .sm) {
                    ProgressView(value: satisfiedFraction)
                        .progressViewStyle(.jackpotBar(height: .xs))
                        .tint(satisfiedFraction < 1 ? theme.colors.warning : theme.colors.success)
                        .accessibilityLabel("Requirements met")

                    Text(section).jackpotTextStyle(\.sectionTitle)

                    ForEach(items) { item in
                        row(for: item)
                    }
                }
                .padding(.top, .sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(title).jackpotTextStyle(\.sectionTitle)
            }
            // The chevron follows the tint, which the theme points at the accent.
            .tint(theme.colors.textPrimary)
            .padding(theme.sizes.contentPadding)
            .jackpotBackground(\.fieldBackground, in: theme.sizes.fieldShape)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: isExpanded)
        }
    }

    private func row(for item: JackpotChecklistItem) -> some View {
        HStack(spacing: .sm) {
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

Shown when a form fails to load.

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

    /// Adds the retry button.
    public func onRetry(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.retryAction = action
        return copy
    }

    public var body: some View {
        VStack(spacing: .sm) {
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
        .padding(.l)
    }
}
```

**16.** `JackpotKit/Sources/JackpotUI/Components/JackpotLinkRow.swift`

The "Already have an account? Login" row, filled with `background` on the footer band, and
its mirror under Login.

```swift
import SwiftUI

/// A prompt with a link at its trailing edge, on `background` so it rests on a `surface` band.
public struct JackpotLinkRow: View {
    private let prompt: String
    private let link: String
    private let action: () -> Void

    @Environment(\.jackpotTheme) private var theme

    public init(_ prompt: String, link: String, action: @escaping () -> Void) {
        self.prompt = prompt
        self.link = link
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(prompt).jackpotTextStyle(\.rowLabel)
                Spacer(minLength: 0)
                HStack(spacing: .xxs) {
                    Text(link).jackpotTextStyle(\.rowLabel, color: \.accent)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .jackpotForegroundStyle(\.accent)
                }
            }
            .padding(.m)
            .frame(minHeight: theme.sizes.controlHeight)
            .jackpotBackground(\.background, in: theme.sizes.fieldShape)
            .overlay {
                theme.sizes.fieldShape
                    .strokeBorder(theme.colors.fieldBorder, lineWidth: theme.sizes.borderWidth)
            }
            .contentShape(theme.sizes.fieldShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prompt) \(link)")
    }
}
```

**17.** `JackpotKit/Sources/JackpotUI/Components/JackpotPanel.swift`

The shell registration is presented in: the header and footer bands on `surface`, the
close button and the content on `background`. Resume **Sheet shell** in the gallery to see
the layers.

```swift
import SwiftUI

/// A sheet shell: header band with title and close button, content on `background`, optional footer band.
public struct JackpotPanel<Content: View, Footer: View>: View {
    private let title: String
    private let onClose: () -> Void
    private let content: Content
    private let footer: Footer

    @Environment(\.jackpotTheme) private var theme

    public init(_ title: String,
                onClose: @escaping () -> Void,
                @ViewBuilder content: () -> Content,
                @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.onClose = onClose
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            content
                .frame(maxWidth: .infinity)
                .jackpotBackground(\.background)

            if Footer.self != EmptyView.self {
                footer
                    .padding(theme.sizes.contentPadding)
                    .frame(maxWidth: .infinity)
                    .jackpotBackground(\.surface)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.sizes.panelCornerRadius, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: theme.sizes.spacing) {
            Text(title).jackpotTextStyle(\.title)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .jackpotForegroundStyle(\.textPrimary)
                    .frame(width: theme.sizes.minimumHitTarget, height: theme.sizes.minimumHitTarget)
                    .jackpotBackground(\.background, in: theme.sizes.fieldShape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, theme.sizes.contentPadding)
        .padding(.vertical, .sm)
        .frame(maxWidth: .infinity)
        .jackpotBackground(\.surface)
    }
}

public extension JackpotPanel where Footer == EmptyView {
    init(_ title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(title, onClose: onClose, content: content, footer: { EmptyView() })
    }
}
```

**18.** `JackpotKit/Sources/JackpotUI/Components/JackpotPopup.swift`

`.jackpotPopup(isPresented:)` presents a panel the way the app does: over the page, which
dims behind a `background` scrim, inset and pinned below the host's header. Not a system
sheet.

```swift
import SwiftUI

public extension View {
    /// Presents a panel over this view the way the app does: dimmed page, inset, pinned `topInset` below the top. Not a system sheet.
    func jackpotPopup<Panel: View>(isPresented: Binding<Bool>,
                                   topInset: CGFloat = JackpotSpacing.m.rawValue,
                                   @ViewBuilder panel: @escaping () -> Panel) -> some View {
        modifier(JackpotPopup(isPresented: isPresented, topInset: topInset, panel: panel))
    }
}

private struct JackpotPopup<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    let topInset: CGFloat
    let panel: () -> Panel

    @Environment(\.jackpotTheme) private var theme

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    ZStack(alignment: .top) {
                        // A white wash on the light page, a darkening on the dark one.
                        theme.colors.background.opacity(0.6)
                            .ignoresSafeArea()
                            .accessibilityHidden(true)

                        panel()
                            .padding([.horizontal, .bottom], .m)
                            .padding(.top, topInset)
                            .accessibilityAddTraits(.isModal)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: isPresented)
    }
}
```

**19.** `JackpotKit/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift`

The panel wraps a preview in the themed surface. Resume **Gallery** for every registration
component in one place.

```swift
import SwiftUI

/// A themed surface at phone width for previewing components.
public struct JackpotPreviewPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            content
        }
        .padding(.m)
        .frame(width: 390)
        .jackpotTheme(.jackpotCity)
        .jackpotBackground(\.background)
    }
}

// MARK: - Component gallery

#if DEBUG
struct JackpotUI_Previews: PreviewProvider {
    struct Harness: View {
        @State private var mobile = ""
        @State private var email = ""
        @State private var secret = "Passwo1"
        @State private var promotions = false
        @State private var agreed = true
        @State private var income: String? = nil
        @State private var dateOfBirth: Date? = nil

        var body: some View {
            ScrollView {
                JackpotPreviewPanel("Gallery") {
                    JackpotTextField("Mobile Number", text: $mobile, kind: .phoneNumber, prefix: "+27")

                    JackpotTextField("Email", text: $email, kind: .email)

                    JackpotTextField("Password", text: $secret, kind: .newPassword)
                        .jackpotFieldError("Password must be 8–20 characters")

                    JackpotChecklist("Password Validity", items: [
                        .init(id: "min", text: "Minimum of 8 characters", isSatisfied: false),
                        .init(id: "max", text: "Maximum of 20 characters", isSatisfied: true),
                    ])

                    JackpotDropdown("Source Of Income", selection: $income, options: [
                        .init(id: "salary", label: "Salary or Wages"),
                        .init(id: "pension", label: "Pension or Grant"),
                    ])
                    .jackpotFieldError("Please choose one")

                    JackpotDateField("Date Of Birth", selection: $dateOfBirth)

                    Toggle("Send Jackpot City Promotions to me", isOn: $promotions)
                        .toggleStyle(.jackpotCheckbox)
                    Toggle("I am over 18 years of age & I accept the Terms & Conditions", isOn: $agreed)
                        .toggleStyle(.jackpotCheckbox)

                    ProgressView(value: 0.45).progressViewStyle(.jackpotBar)

                    Button("Next") {}.buttonStyle(.jackpot).disabled(true)
                    Button("Sign Up") {}.buttonStyle(.jackpot).jackpotLoading()
                    Button("Previous") {}.buttonStyle(.jackpot(.secondary))
                }
            }
            .jackpotTheme(.jackpotCity)
            .jackpotBackground(\.background)
        }
    }

    struct Shell: View {
        @State private var mobile = ""
        @State private var email = ""

        var body: some View {
            JackpotPanel("Sign Up", onClose: {}) {
                VStack(spacing: .sm) {
                    JackpotTextField("Mobile Number", text: $mobile, kind: .phoneNumber, prefix: "+27")
                    JackpotTextField("Email", text: $email, kind: .email)
                }
                .padding(.m)
            } footer: {
                VStack(spacing: .sm) {
                    JackpotLinkRow("Already have an account?", link: "Login") {}
                    Button("Next") {}.buttonStyle(.jackpot).disabled(true)
                }
            }
            .padding(.m)
            .frame(width: 390)
            .jackpotTheme(.jackpotCity)
            .jackpotBackground(\.background)
        }
    }

    static var previews: some View {
        Group {
            Harness().preferredColorScheme(.dark).previewDisplayName("Gallery — dark")
            Harness().preferredColorScheme(.light).previewDisplayName("Gallery — light")
            Shell().preferredColorScheme(.dark).previewDisplayName("Sheet shell — dark")
            Shell().preferredColorScheme(.light).previewDisplayName("Sheet shell — light")
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

---

### ▶ Create PR — JackpotUI

Open `JackpotPreviewPanel.swift` and resume the **Gallery** and **Sheet shell** previews in
both appearances.

---

## Step 2 — JackpotForms on the bundled schema, and the registration sheet

The engine, with no network. One module, three folders pointing one way: `Domain` (types
and rules, no I/O), `Data` (wire shapes and the bundled stub) and `UI` (the model and the
renderer). The engine only ever sees `FormRepository`; `StubFormRepository` serves the
captured `registration.json` and fakes the submit, which is what lets the whole sheet run
before any endpoint exists. `JackpotRegistration` is the feature on top: the sheet and
registration's own rules.

**20.**

```bash
mkdir -p JackpotKit/Sources/JackpotForms/{Domain,Data,UI/Fields,Resources}
mkdir -p JackpotKit/Sources/JackpotRegistration
```

**21.** `JackpotKit/Package.swift` — the whole file after this step

`JackpotForms` depends on `JackpotUI` alone at this step; the network joins it at step 4
and localisation joins `JackpotRegistration` at step 5. Wire types are `internal`.

```swift
// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module. In Xcode: File → Add Package
// Dependencies → Add Local… → JackpotKit, then add the product you need to the app target.
// The floor is iOS 15, the host app's. docs/BUILD-PLAYBOOK.md builds this manifest one step at a
// time, and scripts/build-playbook.py checks that its final step matches this file exactly.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotForms", "JackpotRegistration"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),
    ]
)
```

**22.** `JackpotKit/Sources/JackpotForms/Domain/FormName.swift`

`.registration` is the live form.

```swift
import Foundation

/// The `formCodeName` in the schema and the last path component of the fetch URL. A struct rather than an
/// enum because forms are authored server-side, so `FormName("deposit")` must be constructible; not
/// `ExpressibleByStringLiteral`, so a typo cannot compile into a 404.
public struct FormName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - Known forms

public extension FormName {
    /// The two-section sign-up form: credentials, name and email, then FICA.
    static let registration = FormName("registration")
}
```

**23.** `JackpotKit/Sources/JackpotForms/Domain/FormValue.swift`

```swift
import Foundation

/// Every case renders as a string because the schema validates with regexes, `^true$` for checkboxes included.
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
        case .date(let d):      return FormValue.iso8601.format(d)
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .empty:         return true
        case .text(let s):   return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .option(let v): return v.isEmpty
        // An unticked required checkbox counts as empty, which is what makes `terms` work.
        case .bool(let b):   return !b
        case .date:          return false
        }
    }

    public var boolValue: Bool {
        if case .bool(let b) = self { return b }
        return false
    }

    public var dateValue: Date? {
        if case .date(let d) = self { return d }
        return nil
    }

    /// The `dateOfBirth` regex expects an ISO-8601 date-time: `1990-01-01T00:00:00Z`.
    public static let iso8601 = Date.ISO8601FormatStyle()
}

/// What the host receives on submit and what the submit endpoint expects; encoding lives in `Remote`.
public struct FormSubmission: Equatable, Sendable {
    public let formId: String
    public let formCodeName: FormName
    public let submittedAt: Date
    public let values: [String: FormValue]

    public init(formCodeName: FormName,
                values: [String: FormValue],
                formId: String = "",
                submittedAt: Date = Date()) {
        self.formId = formId
        self.formCodeName = formCodeName
        self.submittedAt = submittedAt
        self.values = values
    }

    public subscript(identifier: String) -> FormValue {
        values[identifier] ?? .empty
    }
}
```

**24.** `JackpotKit/Sources/JackpotForms/Domain/FormField.swift`

`FieldType` is Input, Dropdown and Checkbox — the registration catalog — plus `unknown`,
which is what keeps the form usable when the CRM adds a type this build cannot draw.

```swift
import Foundation

/// `unknown` is load-bearing: the CRM edits the schema without an app release, so an unknown type is
/// skipped and reported through `unsupportedFields`, never fatal.
public enum FieldType: Equatable, Hashable, Sendable {
    case input
    case dropdown
    case checkbox
    case unknown(String)

    public init(raw: String) {
        switch raw.lowercased().replacingOccurrences(of: " ", with: "") {
        case "input":              self = .input
        case "dropdown", "select": self = .dropdown
        case "checkbox":           self = .checkbox
        default:                   self = .unknown(raw)
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
        // The schema spells it "Calender"; accept both.
        case "calender", "calendar", "date": self = .calendar
        case "phone", "tel":          self = .phone
        default:                      self = .unknown(raw)
        }
    }
}

public struct DropdownOption: Identifiable, Equatable, Hashable, Sendable {
    public let value: String
    public let textKey: String
    /// A pattern, or the name of one; see `FormDependencies.namedPatterns`.
    public let regex: String?

    public var id: String { value }

    public init(value: String, textKey: String, regex: String?) {
        self.value = value
        self.textKey = textKey
        self.regex = regex
    }
}

public struct FormField: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public let identifier: String
    public let labelKey: String
    public let type: FieldType
    public let inputType: InputType
    public let validationMessageKey: String
    public let isRequired: Bool
    /// Hidden fields are neither rendered, validated nor submitted.
    public let isVisible: Bool
    public let isReadOnly: Bool
    /// Server-supplied, so possibly invalid; see `FieldValidator`.
    public let regex: String?
    public let prefix: String
    public let suffix: String
    public let dropdownOptions: [DropdownOption]

    /// Defaults are the schema's own: an unspecified field is an optional, visible text input labelled by its identifier.
    public init(id: Int,
                identifier: String,
                labelKey: String? = nil,
                type: FieldType = .input,
                inputType: InputType = .text,
                validationMessageKey: String = "regex",
                isRequired: Bool = false,
                isVisible: Bool = true,
                isReadOnly: Bool = false,
                regex: String? = nil,
                prefix: String = "",
                suffix: String = "",
                dropdownOptions: [DropdownOption] = []) {
        self.id = id
        self.identifier = identifier
        self.labelKey = labelKey ?? identifier
        self.type = type
        self.inputType = inputType
        self.validationMessageKey = validationMessageKey
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isReadOnly = isReadOnly
        self.regex = regex
        self.prefix = prefix
        self.suffix = suffix
        self.dropdownOptions = dropdownOptions
    }

    public var isSecure: Bool { inputType == .password }
}
```

**25.** `JackpotKit/Sources/JackpotForms/Domain/FormSchema.swift`

```swift
import Foundation

/// A form as the CRM describes it: a section is one page, and fields sharing a row sit side by side.
public struct FormSchema: Identifiable, Equatable, Sendable {
    public let id: Int
    public let codeName: FormName
    public let sections: [FormSection]

    public init(id: Int, codeName: FormName, sections: [FormSection]) {
        self.id = id
        self.codeName = codeName
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
    public let rows: [FormRow]

    public init(id: Int, rows: [FormRow]) {
        self.id = id
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

**26.** `JackpotKit/Sources/JackpotForms/Domain/FormSubmitResult.swift`

```swift
import Foundation

/// What `POST /cron/forms/submit` returns. HTTP 200 is not success, and a created account can still need manual FICA.
public struct FormSubmitResult: Decodable, Equatable, Sendable {
    public let accountId: String?
    public let message: String?
    public let status: String?
    public let partialRegistrationStatus: Int?
    public let compliance: FormComplianceResult?

    enum CodingKeys: String, CodingKey {
        case accountId, message, status, partialRegistrationStatus
        case compliance = "complianceResponse"
    }

    public init(accountId: String? = nil,
                message: String? = nil,
                status: String? = nil,
                partialRegistrationStatus: Int? = nil,
                compliance: FormComplianceResult? = nil) {
        self.accountId = accountId
        self.message = message
        self.status = status
        self.partialRegistrationStatus = partialRegistrationStatus
        self.compliance = compliance
    }

    /// Account exists but auto-FICA didn't finish (`jpc-partially-complete-profile`).
    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }
}

/// `accessToken` is the session token when the account was created; the app logs in with it.
public struct FormComplianceResult: Decodable, Equatable, Sendable {
    public let complianceStatus: Int?
    public let requiredComplianceStatus: Int?
    public let isValidId: Bool?
    public let message: String?
    public let accessToken: String?
}
```

**27.** `JackpotKit/Sources/JackpotForms/Domain/PasswordPolicy.swift`

```swift
import Foundation

/// One rule in the "Password Validity" panel, already judged against the current password.
public struct PasswordRule: Equatable, Sendable {
    public let description: String
    public let isSatisfied: Bool
}

/// The schema gives password one regex, `^(.){8,20}$`, and the design shows two rules, so the
/// `{min,max}` quantifier is parsed. Registration only.
public enum PasswordPolicy {
    public static func rules(for field: FormField, password: String) -> [PasswordRule] {
        guard let bounds = lengthBounds(in: field.regex) else { return [] }
        return [
            PasswordRule(description: "Minimum of \(bounds.lowerBound) characters",
                         isSatisfied: password.count >= bounds.lowerBound),
            PasswordRule(description: "Maximum of \(bounds.upperBound) characters",
                         isSatisfied: !password.isEmpty && password.count <= bounds.upperBound),
        ]
    }

    static func lengthBounds(in pattern: String?) -> ClosedRange<Int>? {
        guard let pattern,
              let expression = try? NSRegularExpression(pattern: #"\{(\d+),(\d+)\}"#),
              let match = expression.firstMatch(in: pattern, range: NSRange(pattern.startIndex..., in: pattern)),
              let minRange = Range(match.range(at: 1), in: pattern),
              let maxRange = Range(match.range(at: 2), in: pattern),
              let minimum = Int(pattern[minRange]), let maximum = Int(pattern[maxRange]),
              minimum <= maximum
        else { return nil }
        return minimum...maximum
    }
}
```

**28.** `JackpotKit/Sources/JackpotForms/Domain/FieldValidator.swift`

```swift
import Foundation

/// Regexes come from a server: one that will not compile is treated as no constraint, and compiled
/// expressions are cached by pattern.
public struct FieldValidator: Sendable {
    private let cache = RegexCache()

    public init() {}

    /// - Parameter overrideRegex: replaces `field.regex` when a dropdown selection changes a dependent field's rule.
    public func validate(_ value: FormValue, against field: FormField, overrideRegex: String? = nil) -> Bool {
        guard field.isVisible, !field.isReadOnly else { return true }
        // Not every optional field's regex permits empty; this is what keeps optional optional.
        if value.isEmpty { return !field.isRequired }
        guard let pattern = overrideRegex ?? field.regex, !pattern.isEmpty,
              let expression = cache.expression(for: pattern) else { return true }

        let subject = value.stringValue
        let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
        return expression.firstMatch(in: subject, options: [], range: range) != nil
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

**29.** `JackpotKit/Sources/JackpotForms/Domain/FormError.swift`

```swift
import Foundation

/// Why a form operation failed, in words the UI can show. `server` keeps the server's wording.
public enum FormError: LocalizedError, Equatable {
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

**30.** `JackpotKit/Sources/JackpotForms/Domain/FormLocalizing.swift`

The seam the app's translation function plugs into: `LegacyTranslationLocalizer` at
step 4, `Translations.formLocalizer` from step 5.

```swift
import Foundation

/// The schema ships localisation keys, not text; something has to resolve them.
public protocol FormLocalizing: Sendable {
    func string(forKey key: String) -> String?

    /// Copy for a server error code, when the table carries one.
    func message(forErrorCode code: Int) -> String?
}

public extension FormLocalizing {
    func message(forErrorCode code: Int) -> String? { nil }

    /// Resolves, or humanises the key so nothing renders blank.
    func display(_ key: String) -> String {
        string(forKey: key) ?? key.humanisedKey
    }

    /// Every field carries `validationMessage: "regex"`, so the real key is composed: `jpc-reg-{identifier}-{key}`.
    func validationMessage(for field: FormField) -> String {
        let composed = "jpc-reg-\(field.identifier)-\(field.validationMessageKey)"
        if let resolved = string(forKey: composed) { return resolved }
        if let resolved = string(forKey: field.validationMessageKey) { return resolved }
        return "Please enter a valid \(field.identifier.humanisedKey.lowercased())"
    }
}

public extension String {
    /// "jpc-reg-idnumber" → "Idnumber"; "dateOfBirth" → "Date Of Birth".
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

/// Wraps any `(key) -> String?`. Return nil on a miss, not the key, or the engine cannot fall back.
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

**31.** `JackpotKit/Sources/JackpotForms/Domain/FormRepository.swift`

```swift
import Foundation

/// Fetch is `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`; submit posts to `{cron}/forms/submit`.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
}
```

**32.** `JackpotKit/Sources/JackpotForms/Data/FormDTO.swift`

```swift
import Foundation

// Wire shapes, exactly as the CRM sends them. Everything is optional but the identifiers: product
// edits the schema in a CMS, so a missing `prefix` must not fail the decode.
struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let sections: [FormSectionDTO]?
}

struct FormSectionDTO: Decodable {
    let formSectionId: Int
    let formSectionOrder: Int?
    let rows: [FormRowDTO]?
}

struct FormRowDTO: Decodable {
    let rowNumber: Int
    let fields: [FormFieldDTO]?
}

struct FormFieldDTO: Decodable {
    let fieldId: Int
    let fieldIdentifier: String
    let fieldLabel: String?
    let fieldType: String
    let inputType: String?
    let validationMessage: String?
    let isRequired: Bool?
    let isVisible: Bool?
    let isReadOnly: Bool?
    let fieldRegex: String?
    let prefix: String?
    let suffix: String?
    let fieldDropdowns: [FieldDropdownDTO]?
}

struct FieldDropdownDTO: Decodable {
    let value: String
    let text: String?
    let regex: String?
}
```

**33.** `JackpotKit/Sources/JackpotForms/Data/FormMapper.swift`

```swift
import Foundation

enum FormMapper {
    static func map(_ dto: FormDTO) -> FormSchema {
        FormSchema(
            id: dto.formId,
            codeName: FormName(dto.formCodeName),
            sections: (dto.sections ?? [])
                .sorted { ($0.formSectionOrder ?? $0.formSectionId) < ($1.formSectionOrder ?? $1.formSectionId) }
                .map(mapSection)
        )
    }

    private static func mapSection(_ dto: FormSectionDTO) -> FormSection {
        FormSection(
            id: dto.formSectionId,
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
            labelKey: dto.fieldLabel,
            type: FieldType(raw: dto.fieldType),
            inputType: InputType(raw: dto.inputType ?? "Text"),
            validationMessageKey: dto.validationMessage ?? "regex",
            // Fail safe: an unspecified field is optional and visible rather than blocking submission.
            isRequired: dto.isRequired ?? false,
            isVisible: dto.isVisible ?? true,
            isReadOnly: dto.isReadOnly ?? false,
            regex: dto.fieldRegex?.isEmpty == true ? nil : dto.fieldRegex,
            prefix: dto.prefix ?? "",
            suffix: dto.suffix ?? "",
            dropdownOptions: (dto.fieldDropdowns ?? []).map {
                DropdownOption(value: $0.value, textKey: $0.text ?? $0.value, regex: $0.regex)
            }
        )
    }
}
```

**34.** `JackpotKit/Sources/JackpotForms/Data/StubFormRepository.swift`

```swift
import Foundation

/// Serves bundled JSON and fakes the submit, so the feature runs before the endpoint is reachable.
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
        try await prepare()
        guard let data = forms[name] else { throw FormError.notFound(name) }
        return try Self.decode(data)
    }

    /// Succeeds with a fake account; fails for mobile `"0000000000"`, so the error path can be demoed.
    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        try await prepare()
        let mobile = submission["username"].stringValue
        if mobile == "0000000000" {
            throw FormError.server(message: "That mobile number is already registered. Try logging in instead.")
        }
        return FormSubmitResult(accountId: "27\(mobile)", message: "User Created Successfully.")
    }

    static func decode(_ data: Data) throws -> FormSchema {
        FormMapper.map(try JSONDecoder().decode(FormDTO.self, from: data))
    }

    private func prepare() async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let error { throw error }
    }
}
```

**35.** `JackpotKit/Sources/JackpotForms/Data/BundledForms.swift`

```swift
import Foundation

/// The schemas shipped as JSON; `registration.json` is the CRM's response saved verbatim.
enum BundledForms {
    static var all: [FormName: Data] {
        [.registration: json(named: "registration")]
    }

    static func json(named name: String) -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("Missing bundled schema \(name).json")
            return Data("{}".utf8)
        }
        return data
    }
}
```

**36.** `JackpotKit/Sources/JackpotForms/Data/RegistrationCopy.swift`

The placeholder copy table, until the app's strings are wired in.

```swift
import Foundation

public extension ClosureLocalizer {
    /// Placeholder copy for the registration keys, until the app's own strings are wired in.
    static let jpcRegistration: ClosureLocalizer = {
        let table = [
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
        ]
        return ClosureLocalizer { table[$0] }
    }()
}
```

**37.**

```bash
cp registration.json JackpotKit/Sources/JackpotForms/Resources/registration.json
```

`registration.json` is the CRM's response saved verbatim — 12 fields over two sections.
`JackpotForms` processes it as a resource; `BundledForms` reads it from `Bundle.module`
for the stub repository, the previews and the tests alike.

**38.** `JackpotKit/Sources/JackpotForms/UI/FormDependencies.swift`

The engine's dependencies and `.mock()`. Defaults are generic: no regex links, no date
cap; `namedPatterns` is what a name on a dropdown option's `regex` stands for, which is how
a dropdown changes another field's rule. Registration adds its own links below.

```swift
import Foundation

/// Everything the engine needs besides the form name. Defaults are generic; a feature adds its rules on top.
public struct FormDependencies {
    public var repository: any FormRepository
    public var localizer: any FormLocalizing
    /// "This dropdown drives this field's regex", by identifier. Declared, never inferred from row order.
    public var regexDependencies: [String: String]
    /// What a name on a dropdown option's `regex` stands for. A literal pattern there describes the selection itself.
    public var namedPatterns: [String: String]
    /// Latest date a calendar field may select; nil means today.
    public var maximumDate: Date?

    public init(repository: any FormRepository,
                localizer: any FormLocalizing = ClosureLocalizer { _ in nil },
                regexDependencies: [String: String] = [:],
                namedPatterns: [String: String] = FormDependencies.jpcPatterns,
                maximumDate: Date? = nil) {
        self.repository = repository
        self.localizer = localizer
        self.regexDependencies = regexDependencies
        self.namedPatterns = namedPatterns
        self.maximumDate = maximumDate
    }

    /// `passportNumberRegex` is a length rule, not a character class.
    public static let jpcPatterns = [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ]
}

public extension FormDependencies {
    /// The bundled registration schema behind fake latency, so loading states are visible.
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: BundledForms.all, delay: delay, error: error),
            localizer: localizer ?? ClosureLocalizer.jpcRegistration
        )
    }
}
```

**39.** `JackpotKit/Sources/JackpotForms/UI/DynamicFormModel.swift`

The engine. Its state is `values` and `touched`; validity, errors and progress are computed
from those on every read, so nothing has to be re-validated when a dropdown changes
another field's rule. `load()` is `async` and a no-op once loaded, so re-appearing on screen
cannot reset a half-filled form. `advance()` / `goBack()` / `submit()` are what Next,
Previous and Sign Up call; `submit()` posts through the same `FormRepository` that loaded
the form. `overrideRegex(for:)` is how selecting Passport relaxes the SA-ID rule on a
different field.

```swift
import Foundation
import Combine

@MainActor
/// Owns the fetched schema, every value, which fields have been touched, and the visible section. Validity is
/// computed from those rather than stored, so a dropdown that changes another field's rule needs no bookkeeping.
/// `ObservableObject` rather than `@Observable` because the floor is iOS 15.
public final class DynamicFormModel: ObservableObject {
    public enum ViewState: Equatable {
        case loading
        case loaded(FormSchema)
        case failed(String)
    }

    public enum PagingDirection: Equatable, Sendable {
        case forward
        case backward
    }

    // MARK: Published state
    @Published public private(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var sectionIndex: Int = 0
    /// Set before `sectionIndex` changes, so the section transition slides the right way wherever the bar is.
    @Published public private(set) var pagingDirection: PagingDirection = .forward
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

    /// `@Published` so the reveal renders in the same update, not one late.
    @Published private var touched: Set<String> = []

    private let formName: FormName
    private let dependencies: FormDependencies
    private let validator = FieldValidator()

    public init(formName: FormName, dependencies: FormDependencies) {
        self.formName = formName
        self.dependencies = dependencies
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

    /// Types the schema asked for that this build cannot render; non-fatal, surfaced for QA.
    public var unsupportedFields: [String] {
        (form?.allFields ?? []).compactMap {
            if case .unknown(let raw) = $0.type { return "\($0.identifier) (\(raw))" }
            return nil
        }
    }

    /// Fraction of required fields that validate; drives the progress bar.
    public var progress: Double {
        guard let form else { return 0 }
        let required = form.allFields.filter { $0.isVisible && $0.isRequired }
        guard !required.isEmpty else { return 1 }
        return Double(required.filter(isValid).count) / Double(required.count)
    }

    public var isCurrentSectionValid: Bool {
        guard let section = currentSection else { return false }
        return section.fields.allSatisfy(isValid)
    }

    public var isFormValid: Bool {
        guard let form else { return false }
        return form.allFields.allSatisfy(isValid)
    }

    public func value(for field: FormField) -> FormValue {
        values[field.identifier] ?? defaultValue(for: field)
    }

    /// Nil while the field is untouched.
    public func error(for field: FormField) -> String? {
        guard touched.contains(field.identifier), !isValid(field) else { return nil }
        return dependencies.localizer.validationMessage(for: field)
    }

    public func localized(_ key: String) -> String { dependencies.localizer.display(key) }

    public var maximumDate: Date { dependencies.maximumDate ?? Date() }

    // MARK: Loading

    /// A no-op once loaded, so re-appearing cannot reset a half-filled form; a failed load runs again.
    public func load() async {
        if case .loaded = viewState { return }
        viewState = .loading
        do {
            apply(try await dependencies.repository.form(named: formName))
        } catch is CancellationError {
        } catch {
            viewState = .failed(Self.message(for: error))
        }
    }

    private func apply(_ form: FormSchema) {
        viewState = .loaded(form)
        sectionIndex = 0
        touched = []
        values = Dictionary(uniqueKeysWithValues:
            form.allFields.filter(\.isVisible).map { ($0.identifier, defaultValue(for: $0)) }
        )
    }

    private func defaultValue(for field: FormField) -> FormValue {
        switch field.type {
        case .checkbox:        return .bool(false)
        case .dropdown:        return .option("")
        case .input, .unknown: return field.inputType == .calendar ? .empty : .text("")
        }
    }

    // MARK: Editing

    public func setValue(_ value: FormValue, for field: FormField) {
        values[field.identifier] = value
    }

    /// Call on blur. Re-touching is a no-op rather than another render.
    public func markTouched(_ field: FormField) {
        markTouched(identifiedBy: field.identifier)
    }

    public func markTouched(identifiedBy identifier: String) {
        guard !touched.contains(identifier) else { return }
        touched.insert(identifier)
    }

    // MARK: Validation

    private func isValid(_ field: FormField) -> Bool {
        validator.validate(value(for: field), against: field, overrideRegex: overrideRegex(for: field))
    }

    /// The rule a dropdown imposes on `field` when `regexDependencies` links them and the chosen option names a
    /// pattern. ID type → ID number: Passport relaxes the thirteen-digit rule.
    private func overrideRegex(for field: FormField) -> String? {
        guard let form,
              let driverIdentifier = dependencies.regexDependencies.first(where: { $0.value == field.identifier })?.key,
              let driver = form.field(identifiedBy: driverIdentifier),
              case .option(let selected) = value(for: driver),
              let option = driver.dropdownOptions.first(where: { $0.value == selected }),
              let name = option.regex
        else { return nil }
        return dependencies.namedPatterns[name]
    }

    // MARK: Paging

    /// Next is disabled until the section validates, so this only ever moves.
    public func advance() {
        guard isCurrentSectionValid, !isLastSection else { return }
        pagingDirection = .forward
        sectionIndex += 1
    }

    public func goBack() {
        guard sectionIndex > 0 else { return }
        pagingDirection = .backward
        sectionIndex -= 1
    }

    // MARK: Submitting

    /// The result once the repository accepts the form; nil while invalid or when it was refused, with `submitError` set.
    public func submit() async -> FormSubmitResult? {
        guard let form, isFormValid else { return nil }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            return try await dependencies.repository.submitForm(
                FormSubmission(formCodeName: form.codeName, values: values, formId: String(form.id))
            )
        } catch is CancellationError {
        } catch {
            submitError = Self.message(for: error)
        }
        return nil
    }

    private static func message(for error: any Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription { return localized }
        return "Something went wrong. Please try again."
    }
}

#if DEBUG
// Here because `private` is file-scoped, so previews can call `apply(_:)`.
public extension DynamicFormModel {
    /// A model already holding `schema`, so previews render without a fetch.
    static func preview(schema: FormSchema,
                        dependencies: FormDependencies = .mock(delay: 0),
                        values: [String: FormValue] = [:],
                        touched: [String] = []) -> DynamicFormModel {
        let model = DynamicFormModel(formName: schema.codeName, dependencies: dependencies)
        model.apply(schema)
        for (identifier, value) in values {
            guard let field = schema.field(identifiedBy: identifier) else { continue }
            model.setValue(value, for: field)
        }
        for identifier in touched {
            model.markTouched(identifiedBy: identifier)
        }
        return model
    }
}
#endif
```

**40.** `JackpotKit/Sources/JackpotForms/UI/Fields/FieldRenderer.swift`

The switch is the whole contract. Registration hits `.input` (Calender →
`DateFieldView`), `.dropdown` and `.checkbox`.

```swift
import SwiftUI
import JackpotUI

/// The contract between the form builder and the app: a new server type means a new case here and a
/// new field view binding the model to a `JackpotUI` component; until then `unknown` keeps the form usable.
struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        switch field.type {
        case .input:    InputFieldView(field: field, model: model)
        case .dropdown: DropdownFieldView(field: field, model: model)
        case .checkbox: CheckboxFieldView(field: field, model: model)
        case .unknown:  EmptyView()
        }
    }
}

// MARK: - Keyboard focus order

extension FormField {
    /// Only single-line text entry joins return-key navigation.
    var acceptsKeyboardFocus: Bool {
        type == .input && inputType != .calendar
    }
}

extension DynamicFormModel {
    var focusableIdentifiers: [String] {
        (currentSection?.rows ?? [])
            .flatMap(\.fields)
            .filter { $0.isVisible && $0.acceptsKeyboardFocus }
            .map(\.identifier)
    }

    func fieldAfter(_ identifier: String?) -> String? {
        let ids = focusableIdentifiers
        guard let identifier, let index = ids.firstIndex(of: identifier) else { return nil }
        let next = ids.index(after: index)
        return next < ids.endIndex ? ids[next] : nil
    }
}

// MARK: - Shared bindings

extension DynamicFormModel {
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    // Discrete choices mark the field touched as they write; typing reports blur through `onEditingEnded`.
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
}
```

**41.** `JackpotKit/Sources/JackpotForms/UI/Fields/InputFieldView.swift`

```swift
import SwiftUI
import JackpotUI

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    @State private var isEditing = false

    var body: some View {
        if field.inputType == .calendar {
            DateFieldView(field: field, model: model)
        } else {
            VStack(spacing: .xs) {
                JackpotTextField(model.localized(field.labelKey),
                                 text: model.text(for: field),
                                 kind: kind,
                                 prefix: field.prefix,
                                 suffix: field.suffix)
                    .onEditingEnded { model.markTouched(field) }
                    .onFocusChange { isEditing = $0 }
                    .jackpotFieldIdentity(field.identifier)
                    .submitLabel(isLastFocusable ? .done : .next)
                    .disabled(field.isReadOnly)

                // The rules are guidance while composing; once the field is left, the error line carries the verdict.
                if field.isSecure, isEditing {
                    JackpotChecklist("Password Validity", items: passwordItems)
                        .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isEditing)
            .jackpotFieldError(model.error(for: field))
        }
    }

    private var isLastFocusable: Bool {
        model.focusableIdentifiers.last == field.identifier
    }

    private var passwordItems: [JackpotChecklistItem] {
        PasswordPolicy.rules(for: field, password: model.value(for: field).stringValue).map {
            JackpotChecklistItem(id: $0.description, text: $0.description, isSatisfied: $0.isSatisfied)
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
        // The schema's `inputType` is coarser than iOS autofill: `username` is a mobile number typed as Number.
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
                InputFieldView(field: FormPreview.field("username"), model: FormPreview.model([FormPreview.field("username")]))
            }.previewDisplayName("Mobile — empty")
            JackpotPreviewPanel("Invalid · touched") {
                InputFieldView(field: FormPreview.field("username"),
                               model: FormPreview.model([FormPreview.field("username")], values: ["username": .text("123")], touched: ["username"]))
            }.previewDisplayName("Mobile — invalid")
            JackpotPreviewPanel("Password · 7 chars · unfocused") {
                InputFieldView(field: FormPreview.field("password"),
                               model: FormPreview.model([FormPreview.field("password")], values: ["password": .text("Passwo1")], touched: ["password"]))
            }.previewDisplayName("Password — rules hidden")
            JackpotPreviewPanel("Optional · empty is fine") {
                InputFieldView(field: FormPreview.field("referralCode"),
                               model: FormPreview.model([FormPreview.field("referralCode")], touched: ["referralCode"]))
            }.previewDisplayName("Referral — optional")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**42.** `JackpotKit/Sources/JackpotForms/UI/Fields/DropdownFieldView.swift`

```swift
import SwiftUI
import JackpotUI

struct DropdownFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotDropdown(model.localized(field.labelKey),
                        selection: model.selection(for: field),
                        options: model.options(for: field))
            .disabled(field.isReadOnly)
            .jackpotFieldError(model.error(for: field))
    }
}

#if DEBUG
struct DropdownFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Placeholder") {
                DropdownFieldView(field: FormPreview.field("idNumberType"), model: FormPreview.model([FormPreview.field("idNumberType")]))
            }.previewDisplayName("ID type — placeholder")
            JackpotPreviewPanel("Selected") {
                DropdownFieldView(field: FormPreview.field("idNumberType"),
                                  model: FormPreview.model([FormPreview.field("idNumberType")], values: ["idNumberType": .option("idNumber")]))
            }.previewDisplayName("ID type — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DropdownFieldView(field: FormPreview.field("sourceOfFunds"),
                                  model: FormPreview.model([FormPreview.field("sourceOfFunds")], touched: ["sourceOfFunds"]))
            }.previewDisplayName("Source of funds — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**43.** `JackpotKit/Sources/JackpotForms/UI/Fields/DateFieldView.swift`

```swift
import SwiftUI
import JackpotUI

/// `inputType: "Calender"`; the picker's date is serialised through `FormValue.iso8601`.
struct DateFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        JackpotDateField(model.localized(field.labelKey),
                         selection: model.date(for: field),
                         in: ...model.maximumDate)
            .disabled(field.isReadOnly)
            .jackpotFieldError(model.error(for: field))
    }
}

#if DEBUG
struct DateFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("No date") {
                DateFieldView(field: FormPreview.field("dateOfBirth"), model: FormPreview.model([FormPreview.field("dateOfBirth")]))
            }.previewDisplayName("Date — placeholder")
            JackpotPreviewPanel("Chosen") {
                DateFieldView(field: FormPreview.field("dateOfBirth"),
                              model: FormPreview.model([FormPreview.field("dateOfBirth")],
                                                       values: ["dateOfBirth": .date(Date(timeIntervalSince1970: 631152000))]))
            }.previewDisplayName("Date — selected")
            JackpotPreviewPanel("Required · touched · empty") {
                DateFieldView(field: FormPreview.field("dateOfBirth"),
                              model: FormPreview.model([FormPreview.field("dateOfBirth")], touched: ["dateOfBirth"]))
            }.previewDisplayName("Date — error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**44.** `JackpotKit/Sources/JackpotForms/UI/Fields/CheckboxFieldView.swift`

`receivePromotionalInformation` and `terms`.

```swift
import SwiftUI
import JackpotUI

/// Checkboxes validate as "true" / "false"; `terms` uses `^true$` to mean "must be ticked".
struct CheckboxFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        Toggle(model.localized(field.labelKey), isOn: model.bool(for: field))
            .toggleStyle(.jackpotCheckbox)
            .disabled(field.isReadOnly)
            .jackpotFieldError(model.error(for: field))
    }
}

#if DEBUG
struct CheckboxFieldView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotPreviewPanel("Unticked · required · touched") {
                CheckboxFieldView(field: FormPreview.field("terms"), model: FormPreview.model([FormPreview.field("terms")], touched: ["terms"]))
            }.previewDisplayName("Terms — must be ticked")
            JackpotPreviewPanel("Ticked") {
                CheckboxFieldView(field: FormPreview.field("terms"),
                                  model: FormPreview.model([FormPreview.field("terms")], values: ["terms": .bool(true)]))
            }.previewDisplayName("Terms — accepted")
            JackpotPreviewPanel("Optional · wraps") {
                CheckboxFieldView(field: FormPreview.field("receivePromotionalInformation"),
                                  model: FormPreview.model([FormPreview.field("receivePromotionalInformation")]))
            }.previewDisplayName("Promotions opt-in")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**45.** `JackpotKit/Sources/JackpotForms/UI/DynamicFormContent.swift`

Two views over one model. `DynamicFormContent` is the pages; `FormNavigationBar` is
Previous / Next / Sign Up — that is how step 1 becomes step 2 — and slides the pages
using the direction the model publishes. Registration composes the two inside its panel.

```swift
import SwiftUI
import JackpotUI

/// The pages: progress, the current section's rows, the submit error, and the loading and failure states.
/// The host owns the `DynamicFormModel` and places `FormNavigationBar` wherever the design wants it.
public struct DynamicFormContent: View {
    @ObservedObject private var model: DynamicFormModel

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedField: String?

    public init(model: DynamicFormModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    public var body: some View {
        switch model.viewState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
                .accessibilityLabel("Loading form")

        case .failed(let message):
            JackpotErrorView(message, title: "Couldn't load this form")
                .onRetry { Task { await model.load() } }

        case .loaded:
            VStack(spacing: 0) {
                if model.sections.count > 1 {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.jackpotBar)
                        .padding(.horizontal, .m).padding(.top, .sm)
                        .accessibilityLabel("Form progress")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.sizes.spacing) {
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
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        #endif
                    }
                    .padding(.m)
                    // A new identity per section is what lets the transition run.
                    .id(model.sectionIndex)
                    .transition(sectionTransition)
                }
            }
            .jackpotFocusedField($focusedField)
            // Validate before moving focus, so the error and the new focus land in one update.
            .onSubmit {
                guard let current = focusedField else { return }
                model.markTouched(identifiedBy: current)
                focusedField = model.fieldAfter(current)
            }
            .onChange(of: model.sectionIndex) { _ in focusedField = nil }
        }
    }

    /// Offset rather than `.move`, so the sections don't drag the scroll width around mid-flight.
    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let travel: CGFloat = model.pagingDirection == .forward ? 60 : -60
        return .asymmetric(insertion: .offset(x: travel).combined(with: .opacity),
                           removal: .offset(x: -travel).combined(with: .opacity))
    }
}

/// Fields sharing a `rowNumber` render side by side.
struct FormRowView: View {
    let row: FormRow
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        let visible = row.fields.filter(\.isVisible)
        if visible.count == 1 {
            FieldRenderer(field: visible[0], model: model)
        } else if !visible.isEmpty {
            HStack(alignment: .top, spacing: .s) {
                ForEach(visible) { FieldRenderer(field: $0, model: model) }
            }
        }
    }
}

/// Previous / Next / Sign Up. Renders nothing until the form has loaded; `onComplete` receives what the repository returned.
public struct FormNavigationBar: View {
    @ObservedObject private var model: DynamicFormModel
    private let onComplete: (FormSubmitResult) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: DynamicFormModel, onComplete: @escaping (FormSubmitResult) -> Void) {
        _model = ObservedObject(wrappedValue: model)
        self.onComplete = onComplete
    }

    public var body: some View {
        if model.form != nil {
            HStack(spacing: .sm) {
                if !model.isFirstSection {
                    Button("Previous") { withAnimation(pagingAnimation) { model.goBack() } }
                        .buttonStyle(.jackpot(.secondary))
                }
                if model.isLastSection {
                    Button("Sign Up") { Task { if let result = await model.submit() { onComplete(result) } } }
                        .buttonStyle(.jackpot)
                        .disabled(!model.isFormValid)
                        .jackpotLoading(model.isSubmitting)
                } else {
                    Button("Next") { withAnimation(pagingAnimation) { model.advance() } }
                        .buttonStyle(.jackpot)
                        .disabled(!model.isCurrentSectionValid)
                }
            }
        }
    }

    private var pagingAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2)
                     : .spring(response: 0.42, dampingFraction: 0.86)
    }
}

// MARK: - Previews

#if DEBUG
struct DynamicFormContent_Previews: PreviewProvider {
    /// Pages with the bar beneath them, loading if the model has not been seeded.
    private struct Harness: View {
        let model: DynamicFormModel
        var body: some View {
            VStack(spacing: 0) {
                DynamicFormContent(model: model)
                FormNavigationBar(model: model) { _ in }
                    .padding(.horizontal, .m).padding(.vertical, .sm)
            }
            .frame(height: 620)
            .jackpotBackground(\.background)
            .preferredColorScheme(.dark)
            .task { await model.load() }
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
            Harness(model: .preview(schema: FormPreview.registration))
                .environment(\.sizeCategory, .accessibilityLarge)
                .previewDisplayName("Accessibility — XL text")
            Harness(model: DynamicFormModel(formName: .registration, dependencies: .mock(delay: 0, error: FormError.offline)))
                .previewDisplayName("Offline")
            Harness(model: DynamicFormModel(formName: FormName("doesNotExist"), dependencies: .mock(delay: 0)))
                .previewDisplayName("Unknown form — 404")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**46.** `JackpotKit/Sources/JackpotForms/UI/FormPreview.swift`

Decodes the bundled JSON for the seeded-model previews, so the previews and the stub
cannot disagree about the schema.

```swift
#if DEBUG
import Foundation

/// The registration schema decoded from the bundled JSON, plus helpers that seed a model.
enum FormPreview {
    static let registration: FormSchema = {
        // A broken bundled schema should fail previews loudly.
        try! StubFormRepository.decode(BundledForms.json(named: "registration"))
    }()

    static func field(_ identifier: String) -> FormField {
        guard let field = registration.field(identifiedBy: identifier) else {
            preconditionFailure("registration.json has no field \(identifier)")
        }
        return field
    }

    static func schema(_ fields: [FormField]) -> FormSchema {
        FormSchema(id: 1, codeName: FormName("preview"), sections: [
            FormSection(id: 1, rows: fields.enumerated().map { FormRow(number: $0.offset + 1, fields: [$0.element]) }),
        ])
    }

    @MainActor
    static func model(_ fields: [FormField],
                      values: [String: FormValue] = [:],
                      touched: [String] = []) -> DynamicFormModel {
        .preview(schema: schema(fields), values: values, touched: touched)
    }

    static let validSectionOne: [String: FormValue] = [
        "username": .text("849134302"),
        "password": .text("Password1"),
        "firstname": .text("Malcolm"),
        "lastname": .text("Collin"),
        "email": .text("hi@example.com"),
    ]
}
#endif
```

At this point the engine renders the bundled schema end to end: open `DynamicFormContent.swift`
and resume **Section 1 — empty**. Now the feature that presents it:

**47.** `JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift`

`RegistrationDependencies` applies `applyingRegistrationRules()` — the ID-type link and
the 18-year date cap — to whatever `forms` it is given. `RegistrationView` is the Sign Up
sheet: it owns the `DynamicFormModel`, puts `DynamicFormContent` inside `JackpotPanel`, and
fills the footer with the login row and `FormNavigationBar`, with `onClose` for the
header, `onLogin` for the row and `onComplete` for the `RegistrationResult` the submit
returns.

```swift
import SwiftUI
import JackpotUI
import JackpotForms

/// What Sign Up hands back: the account id, the session token under `compliance`, and `isPartial` when FICA
/// still needs a manual upload.
public typealias RegistrationResult = FormSubmitResult

/// Everything the feature needs, supplied by the app where it's presented.
public struct RegistrationDependencies {
    /// `.mock(localizer:)` until networking lands, `.live(baseURL:localizer:)` after; registration's rules are applied on top.
    public let forms: FormDependencies
    public let theme: JackpotTheme

    public init(forms: FormDependencies, theme: JackpotTheme = .jackpotCity) {
        self.forms = forms.applyingRegistrationRules()
        self.theme = theme
    }

    /// Bundled schema and a faked submit: no backend, no app.
    public static func mock(localizer: (any FormLocalizing)? = nil) -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock(localizer: localizer))
    }
}

extension FormDependencies {
    /// The ID-type dropdown decides the ID-number regex, and the date-of-birth picker cannot select an under-18 date.
    func applyingRegistrationRules(now: Date = Date()) -> FormDependencies {
        var rules = self
        rules.regexDependencies = ["idNumberType": "idNumber"]
        rules.maximumDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: -18, to: now)
        return rules
    }
}

/// The Sign Up sheet: the two-page form inside `JackpotPanel`, the login row and navigation in the footer.
/// The shell's copy is fixed here, like the Next / Previous labels, until the app-data keys are known.
public struct RegistrationView: View {
    private let theme: JackpotTheme
    private let onClose: () -> Void
    private let onLogin: () -> Void
    private let onComplete: (RegistrationResult) -> Void
    @StateObject private var model: DynamicFormModel

    public init(dependencies: RegistrationDependencies,
                onClose: @escaping () -> Void,
                onLogin: @escaping () -> Void,
                onComplete: @escaping (RegistrationResult) -> Void) {
        self.theme = dependencies.theme
        self.onClose = onClose
        self.onLogin = onLogin
        self.onComplete = onComplete
        _model = StateObject(wrappedValue: DynamicFormModel(formName: .registration, dependencies: dependencies.forms))
    }

    public var body: some View {
        JackpotPanel("Sign Up", onClose: onClose) {
            DynamicFormContent(model: model)
        } footer: {
            VStack(spacing: .sm) {
                JackpotLinkRow("Already have an account?", link: "Login", action: onLogin)
                FormNavigationBar(model: model, onComplete: onComplete)
            }
        }
        .jackpotTheme(theme)
        .task { await model.load() }
    }
}
```

**48.** `JackpotKit/Sources/JackpotRegistration/RegistrationPanelController.swift`

A drop-in for the view controller step 4 deletes: same `addChild`/`popupContainer` call
site, SwiftUI behind it.

```swift
import UIKit
import SwiftUI

/// Drop-in for the legacy registration popup. A view controller rather than a bare view is what makes safe
/// areas, keyboard avoidance and environment propagation work; `panelView` is for containers that expect a `UIView`.
public final class RegistrationPanelController: UIHostingController<RegistrationView> {
    public init(dependencies: RegistrationDependencies,
                onClose: @escaping () -> Void,
                onLogin: @escaping () -> Void,
                onComplete: @escaping (RegistrationResult) -> Void) {
        super.init(rootView: RegistrationView(dependencies: dependencies,
                                              onClose: onClose,
                                              onLogin: onLogin,
                                              onComplete: onComplete))
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) { sizingOptions = [.intrinsicContentSize] }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(dependencies:onClose:onLogin:onComplete:)") }

    public var panelView: UIView { view }
}
```

**49.** `JackpotKit/Sources/JackpotRegistration/Previews.swift`

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotForms

/// The Sign Up sheet over the page, as the app presents it.
struct RegistrationView_Previews: PreviewProvider {
    private struct Page: View {
        var dependencies: RegistrationDependencies = .mock()
        var body: some View {
            RegistrationView(dependencies: dependencies, onClose: {}, onLogin: {}) { _ in }
                .padding(.m)
                .frame(width: 390, height: 780)
                .jackpotTheme(.jackpotCity)
                .jackpotBackground(\.background)
        }
    }

    static var previews: some View {
        Group {
            Page().preferredColorScheme(.dark)
                .previewDisplayName("Sign Up — dark")
            Page().preferredColorScheme(.light)
                .previewDisplayName("Sign Up — light")

            Page(dependencies: .mock(localizer: ClosureLocalizer { key in
                ["username": "Enter Mobile Number", "password": "Password", "email": "Email"][key]
            }))
            .preferredColorScheme(.dark)
            .previewDisplayName("Sign Up — app localizer")

            Page(dependencies: .init(forms: .mock(delay: 3600)))
                .preferredColorScheme(.dark)
                .previewDisplayName("Loading")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

---

### ▶ Create PR — JackpotForms + JackpotRegistration, on the bundled schema

Open `JackpotRegistration/Previews.swift` and resume **Sign Up — dark**: the whole flow,
both pages, success and the duplicate-mobile failure (`0000000000`), with no app and no
backend.

---

## Step 3 — JackpotNetworking

The transport: `HTTPClient` is the seam tests stub, `APIEndpoint` is one request shape,
`RemoteApiClient` is the pipeline. 200 / 400 / 401 / 500 are the contract;
`unexpectedStatus` carries anything infrastructure returns. Nothing here knows about forms,
and nothing here needs translations: the app keeps `getTranslation` for now.

**50.**

```bash
mkdir -p JackpotKit/Sources/JackpotNetworking
```

**51.** `JackpotKit/Package.swift` — the whole file after this step

A standalone module; nothing depends on it yet.

```swift
// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module. In Xcode: File → Add Package
// Dependencies → Add Local… → JackpotKit, then add the product you need to the app target.
// The floor is iOS 15, the host app's. docs/BUILD-PLAYBOOK.md builds this manifest one step at a
// time, and scripts/build-playbook.py checks that its final step matches this file exactly.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotForms", "JackpotRegistration",
                      "JackpotNetworking"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),
    ]
)
```

**52.** `JackpotKit/Sources/JackpotNetworking/HTTPMethod.swift`

```swift
import Foundation

public enum HTTPMethod: String, Sendable {
    case GET, POST, PUT, PATCH, DELETE
}
```

**53.** `JackpotKit/Sources/JackpotNetworking/HTTPClient.swift`

```swift
import Foundation

/// The transport seam tests stub.
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

**54.** `JackpotKit/Sources/JackpotNetworking/APIEnvironment.swift`

```swift
import Foundation

/// Base URL plus the headers and query items every request carries.
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

**55.** `JackpotKit/Sources/JackpotNetworking/APIEndpoint.swift`

```swift
import Foundation

public enum RequestBody: Sendable {
    case json(Data)
    case form([String: String])
}

/// One request shape: path, method, body. Knows nothing about hosts, auth or versioning.
public protocol APIEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: RequestBody? { get }
    /// False for login and refresh, so an auth interceptor skips them.
    var requiresAuth: Bool { get }
    /// Safe to retry on 5xx / timeout.
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

**56.** `JackpotKit/Sources/JackpotNetworking/APIError.swift`

```swift
import Foundation

/// The error envelope on a non-2xx: `{ "code": 0, "message": "…" }`. `code` decodes from number or string;
/// a body with neither field throws, so `try?` at the call site yields nil rather than an empty complaint.
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

/// The contract is 200, 400, 401, 500; `unexpectedStatus` carries anything a proxy or WAF returns.
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

    /// The server's own wording, when it sent any.
    public var serverMessage: String? {
        problem?.message.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var isOffline: Bool {
        guard case .transport(let code) = self else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut].contains(code)
    }
}
```

**57.** `JackpotKit/Sources/JackpotNetworking/RequestInterceptor.swift`

```swift
import Foundation

/// Auth headers, token refresh, logging: once, instead of in every endpoint.
public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest
    /// An adapted request to retry with, or nil. Called at most once.
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

/// The token arrives through a closure, so this module never imports a session type.
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

**58.** `JackpotKit/Sources/JackpotNetworking/ConditionalRequest.swift`

Registration never sends a conditional request; `RemoteApiClient` still implements the
protocol method, so the types have to exist. Step 6 uses them.

```swift
import Foundation

/// The validators a response came back with; sending them back turns a revalidation into a 304.
/// `Codable` because `AppDataCaching` stores them beside the payload.
public struct HTTPValidators: Sendable, Equatable, Codable {
    public let etag: String?
    public let lastModified: String?

    public init(etag: String?, lastModified: String?) {
        self.etag = etag
        self.lastModified = lastModified
    }

    public init?(_ response: HTTPURLResponse) {
        let etag = response.value(forHTTPHeaderField: "ETag")
        let lastModified = response.value(forHTTPHeaderField: "Last-Modified")
        guard etag != nil || lastModified != nil else { return nil }
        self.etag = etag
        self.lastModified = lastModified
    }

    var conditionalHeaders: [String: String] {
        var headers: [String: String] = [:]
        if let etag { headers["If-None-Match"] = etag }
        if let lastModified { headers["If-Modified-Since"] = lastModified }
        return headers
    }
}

public enum ConditionalResponse: Sendable, Equatable {
    case notModified
    case fresh(Data, HTTPValidators?)
}
```

**59.** `JackpotKit/Sources/JackpotNetworking/RemoteApiClient.swift`

The retry policy is the part to read: a 5xx or a dropped connection is retried, a 4xx never
is, and a non-idempotent request is retried only when the transport failed before the
server could have seen it.

```swift
import Foundation

public protocol ApiClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response
    func request(_ endpoint: some APIEndpoint) async throws
    func requestData(_ endpoint: some APIEndpoint) async throws -> Data
    /// Returns `.notModified` on a 304.
    func requestConditional(_ endpoint: some APIEndpoint,
                            validators: HTTPValidators?) async throws -> ConditionalResponse
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
        let (data, _) = try await perform(endpoint)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            // The full description names the failing key path.
            throw APIError.decoding("\(Response.self): \(error)")
        }
    }

    public func request(_ endpoint: some APIEndpoint) async throws {
        _ = try await perform(endpoint)
    }

    public func requestData(_ endpoint: some APIEndpoint) async throws -> Data {
        try await perform(endpoint).0
    }

    public func requestConditional(_ endpoint: some APIEndpoint,
                                   validators: HTTPValidators?) async throws -> ConditionalResponse {
        let (data, response) = try await perform(endpoint, extraHeaders: validators?.conditionalHeaders ?? [:])
        if response.statusCode == 304 { return .notModified }
        return .fresh(data, HTTPValidators(response))
    }

    // MARK: - Pipeline

    private func perform(_ endpoint: some APIEndpoint,
                         extraHeaders: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var request = try endpoint.urlRequest(in: environment)
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        for interceptor in interceptors {
            request = try await interceptor.adapt(request, for: endpoint)
        }
        return try await send(request, for: endpoint, didRetryAuth: false, transientRetries: 0)
    }

    private func send(_ request: URLRequest,
                      for endpoint: some APIEndpoint,
                      didRetryAuth: Bool,
                      transientRetries: Int) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await transport(request)

        switch response.statusCode {
        case 200..<300:
            return (data, response)

        case 304:
            return (data, response)

        // `didRetryAuth` is a parameter, not state, so a second 401 cannot loop.
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

        // A POST may already have taken effect, so only idempotent requests are retried.
        case 500, 502...504:
            if endpoint.isIdempotent, transientRetries < maxTransientRetries {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return try await send(request, for: endpoint, didRetryAuth: didRetryAuth,
                                      transientRetries: transientRetries + 1)
            }
            throw response.statusCode == 500
                ? APIError.server(problem(from: data))
                : APIError.unexpectedStatus(response.statusCode, problem(from: data))

        default:
            throw APIError.unexpectedStatus(response.statusCode, problem(from: data))
        }
    }

    private func transport(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await httpClient.send(request)
        } catch is CancellationError {
            throw APIError.cancelled
        // What URLSession throws when a Task is cancelled mid-flight.
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

---

### ▶ Create PR — JackpotNetworking

---

## Step 4 — Connect the forms to the network, and replace the flow in the app

The `Remote` folder joins `JackpotForms`: the cron endpoints, the submit envelope, the error
boundary and `.live()`. The engine is untouched — that is the point of the protocol — and
the sheet is untouched too; the only line that changes at the call site is `.mock()` →
`.live(baseURL:localizer:)`. The localizer is the app's existing `getTranslation`, behind one
named type, so step 5 replaces a single file.

**60.**

```bash
mkdir -p JackpotKit/Sources/JackpotForms/Remote
```

**61.** `JackpotKit/Package.swift` — the whole file after this step

`JackpotForms` gains `JackpotNetworking`. No new targets.

```swift
// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module. In Xcode: File → Add Package
// Dependencies → Add Local… → JackpotKit, then add the product you need to the app target.
// The floor is iOS 15, the host app's. docs/BUILD-PLAYBOOK.md builds this manifest one step at a
// time, and scripts/build-playbook.py checks that its final step matches this file exactly.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotForms", "JackpotRegistration",
                      "JackpotNetworking"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),
    ]
)
```

**62.** `JackpotKit/Sources/JackpotForms/Remote/FormEndpoints.swift`

The cron URLs, the submit body, and `FormSubmitParser` — HTTP 200 is not success, the
envelope's `isSuccessful` is, and a body that is not the envelope is a rejection.

```swift
import Foundation
import JackpotNetworking

// Fetch carries `api-version=2.0` and submit carries none, so the version lives on the request.
extension APIEnvironment {
    static func cron(baseURL: URL) -> APIEnvironment {
        APIEnvironment(baseURL: baseURL)
    }

    /// `…/crm` → `…/cron`: call sites historically passed a CRM base; production fetch is on cron.
    static func cronBaseURL(fromCRM url: URL) -> URL {
        switch url.lastPathComponent {
        case "crm":
            return url.deletingLastPathComponent().appendingPathComponent("cron")
        case "cron":
            return url
        default:
            return url.appendingPathComponent("cron")
        }
    }
}

/// `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`.
struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    var path: String { "forms/\(brand)/\(region)/\(formName.rawValue)" }
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "2.0")] }
}

/// `POST {cron}/forms/submit`. No auth: registration happens before login.
struct FormSubmitRequest: APIEndpoint {
    let bodyData: Data

    init(_ submission: FormSubmission) throws {
        self.bodyData = try FormSubmitBody.encoder.encode(FormSubmitBody(submission))
    }

    var path: String { "forms/submit" }
    var method: HTTPMethod { .POST }
    var body: RequestBody? { .json(bodyData) }
    var requiresAuth: Bool { false }
}

/// Wire shape of `FormSubmission`.
struct FormSubmitBody: Encodable {
    let formId: String
    let formName: String
    let submittedAt: Date
    let fields: [String: FormValue]

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case formName = "form_name"
        case submittedAt = "submitted_at"
        case fields
    }

    init(_ submission: FormSubmission) {
        formId = submission.formId
        formName = submission.formCodeName.rawValue
        submittedAt = submission.submittedAt
        fields = submission.values
    }

    /// ISO-8601 is an assumption; the production encoder wasn't visible.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

/// Untagged JSON: a string, a bare `true` / `false` for checkboxes, `null` for an empty value.
extension FormValue: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .empty:       try container.encodeNil()
        case .bool(let b): try container.encode(b)
        default:           try container.encode(stringValue)
        }
    }
}

/// HTTP 200 is not success: `isSuccessful` is.
struct FormSubmitEnvelope: Decodable {
    let data: FormSubmitResult?
    let isSuccessful: Bool?
    let error: FormSubmitErrorDTO?
}

struct FormSubmitErrorDTO: Decodable {
    let code: Int?
    let displayCode: Int?
    let message: String?
}

enum FormSubmitParser {
    enum Outcome {
        case accepted(FormSubmitResult)
        case rejected(FormSubmitErrorDTO?)
    }

    /// An empty 2xx is taken as accepted (an assumption); anything else must be the envelope.
    static func parse(_ data: Data) -> Outcome {
        if data.isEmpty { return .accepted(FormSubmitResult()) }
        guard let envelope = try? JSONDecoder().decode(FormSubmitEnvelope.self, from: data),
              envelope.isEnvelope else {
            return .rejected(nil)
        }
        if envelope.failed { return .rejected(envelope.error) }
        return .accepted(envelope.data ?? FormSubmitResult())
    }
}

private extension FormSubmitEnvelope {
    /// Every field is optional, so a body with none of them is some other document.
    var isEnvelope: Bool {
        data != nil || isSuccessful != nil || error != nil
    }

    var failed: Bool {
        isSuccessful == false || (isSuccessful == nil && error != nil)
    }
}
```

**63.** `JackpotKit/Sources/JackpotForms/Remote/FormErrorMapper.swift`

The boundary that decides what the user reads. The engine cannot see `APIError`, so
anything not translated here becomes a generic failure on screen. Error codes resolve
through whichever `FormLocalizing` the host supplied.

```swift
import Foundation
import JackpotNetworking

// Where transport errors become something a person can read; the engine never sees `APIError`.
enum FormErrorMapper {
    static func map(_ error: any Error,
                    formName: FormName,
                    localizer: (any FormLocalizing)? = nil) -> any Error {
        guard let apiError = error as? APIError else { return error }

        switch apiError {
        // A cancelled load is a navigation event, not a failure.
        case .cancelled:
            return CancellationError()

        case .transport where apiError.isOffline:
            return FormError.offline

        case .unexpectedStatus(404, _):
            return FormError.notFound(formName)

        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            return message(code: apiError.problem?.code, server: apiError.serverMessage, localizer: localizer)
                .map { FormError.server(message: $0) } ?? FormError.unexpected

        case .transport, .decoding, .invalidURL:
            return FormError.unexpected
        }
    }

    /// Localised copy for the code, then the server's wording.
    static func message(code: Int?, server: String?, localizer: (any FormLocalizing)?) -> String? {
        code.flatMap { localizer?.message(forErrorCode: $0) } ?? server
    }
}
```

**64.** `JackpotKit/Sources/JackpotForms/Remote/RemoteFormRepository.swift`

```swift
import Foundation
import JackpotNetworking

public struct RemoteFormRepository: FormRepository {
    private let apiClient: any ApiClient
    private let brand: String
    private let region: String
    /// Resolves error codes to localised copy; without it, the server's message.
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
            let dto: FormDTO = try await apiClient.request(FormRequest(brand: brand, region: region, formName: name))
            return FormMapper.map(dto)
        } catch {
            throw FormErrorMapper.map(error, formName: name, localizer: localizer)
        }
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        do {
            let data = try await apiClient.requestData(FormSubmitRequest(submission))
            switch FormSubmitParser.parse(data) {
            case .accepted(let result):
                return result
            case .rejected(let error):
                let message = FormErrorMapper.message(code: error?.code ?? error?.displayCode,
                                                      server: error?.message, localizer: localizer)
                throw FormError.server(message: message ?? "We couldn't submit the form. Please try again.")
            }
        } catch {
            throw FormErrorMapper.map(error, formName: submission.formCodeName, localizer: localizer)
        }
    }
}
```

**65.** `JackpotKit/Sources/JackpotForms/Remote/FormDependencies+Live.swift`

`.live(baseURL:localizer:)` — swap it for `.mock()` at the call site and nothing else
changes.

```swift
import Foundation
import JackpotNetworking

public extension FormDependencies {
    /// The real thing; swap `.mock()` for this at the call site. `baseURL` may be the historical CRM URL and
    /// `region` is `wmsNavigationRegionCode`. `localizer` is the app's wrapped translation function, a
    /// `Translations.formLocalizer` once the app adopts `JackpotLocalization`.
    static func live(baseURL: URL,
                     brand: String = "jackpotcity",
                     region: String = "JZA",
                     bearerToken: (@Sendable () async -> String?)? = nil,
                     localizer: any FormLocalizing = ClosureLocalizer.jpcRegistration) -> FormDependencies {
        let interceptors: [any RequestInterceptor] = bearerToken.map { [BearerTokenInterceptor(token: $0)] } ?? []
        let client = RemoteApiClient(
            environment: .cron(baseURL: APIEnvironment.cronBaseURL(fromCRM: baseURL)),
            interceptors: interceptors
        )
        return FormDependencies(
            repository: RemoteFormRepository(apiClient: client, brand: brand, region: region,
                                             localizer: localizer),
            localizer: localizer
        )
    }
}
```

Then the app, once. **In Xcode:** File → Add Package Dependencies → Add Local… →
`JackpotKit`, then add **JackpotRegistration** to the app target's frameworks.

**66.** `Sources/Features/Registration/LegacyTranslationLocalizer.swift`

```swift
import JackpotForms

/// The one place the registration feature reads the legacy translation table. Step 5 deletes this
/// file and passes `Translations.formLocalizer` instead; nothing else calls `getTranslation` for it.
struct LegacyTranslationLocalizer: FormLocalizing {
    /// `getTranslation` returns the key on a miss; the engine needs nil there to fall back to humanised copy.
    func string(forKey key: String) -> String? {
        let value = getTranslation(Key: key)
        return value == key ? nil : value
    }
}
```

**67.** `Sources/Features/Registration/RegistrationPresenter.swift`

`.live` makes the fetch and the submit real together; `.mock()` keeps the faked submit for a
build without the backend.

```swift
import UIKit
import JackpotRegistration

extension MainViewController {

    func presentRegistration() {
        let controller = RegistrationPanelController(
            dependencies: RegistrationDependencies(
                forms: .live(
                    baseURL: URL(string: "https://config.jpc.africa/crm")!,
                    localizer: LegacyTranslationLocalizer()
                )
            ),
            onClose: { [weak self] in self?.popupContainer.dismiss() },
            onLogin: { [weak self] in
                self?.popupContainer.dismiss()
                self?.presentLogin()
            }
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

**68.** Point every existing entry point at `presentRegistration()`:

- the header **SIGN UP** button
- the bottom bar **Sign Up** item
- `NavigationHandler` — the `registration` sitemap branch
- the Login panel's **Sign Up ›** link

**69.** Delete:

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

**70.**

```bash
grep -rn "registrationPopup\|flowOneViewController\|flowTwoViewController" --include=*.swift .
```

Expect no results.

---

### ▶ Create PR — live registration in the app

Build and run. Open sign-up from the header and the bottom bar; complete both pages.
Every label reads as it did — that is `LegacyTranslationLocalizer` doing its job.

---

## Step 5 — Fix translations

[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md) phase 2.
`Translations` is the session's table, normalised once at construction instead of on every
lookup; `TranslationsStore` owns it for the session; `Translations.formLocalizer` is the adapter
that feeds it to the form engine, and lives in `JackpotRegistration` so neither the engine
nor the table knows about the other. `getTranslation` becomes a shim over the store, which
fixes the per-lookup rebuild for the whole app with no call-site changes.

**71.**

```bash
mkdir -p JackpotKit/Sources/JackpotLocalization
```

**72.** `JackpotKit/Package.swift` — the whole file after this step

`JackpotLocalization` arrives with no dependencies; `JackpotRegistration` gains it.

```swift
// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module. In Xcode: File → Add Package
// Dependencies → Add Local… → JackpotKit, then add the product you need to the app target.
// The floor is iOS 15, the host app's. docs/BUILD-PLAYBOOK.md builds this manifest one step at a
// time, and scripts/build-playbook.py checks that its final step matches this file exactly.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotForms", "JackpotRegistration",
                      "JackpotNetworking", "JackpotLocalization"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms", "JackpotLocalization"], swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),

        .target(name: "JackpotLocalization", swiftSettings: strict),
    ]
)
```

**73.** `JackpotKit/Sources/JackpotLocalization/Translations.swift`

Two lookups matter: keys are tried region-suffixed first (`terms-jza` before `terms`),
and API error codes are keys too, which is what lets a server error come back in the
user's language.

```swift
import Foundation

/// The session's table, lowercased once at construction rather than on every lookup.
public struct Translations: Sendable, Equatable {
    private let table: [String: String]
    public let regionSuffix: String?

    public init(_ locales: [String: String] = [:], regionCode: String? = nil) {
        self.table = Dictionary(
            locales.lazy.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let trimmed = regionCode?.trimmingCharacters(in: .whitespaces).lowercased()
        self.regionSuffix = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    public var isEmpty: Bool { table.isEmpty }

    /// `key-<region>` first, then `key`. Region-first by default, so callers that forget still show the right copy.
    public func string(forKey key: String, regional: Bool = true) -> String? {
        let normalized = key.lowercased()
        if regional, let regionSuffix, let regional = table["\(normalized)-\(regionSuffix)"] {
            return regional
        }
        return table[normalized]
    }

    /// Falls back to the key itself, so a missing translation is visible in QA.
    public func callAsFunction(_ key: String, regional: Bool = true) -> String {
        string(forKey: key, regional: regional) ?? key
    }

    /// The table doubles as an error-code catalogue: `jpc-reg-error.{code}`, then the bare number.
    public func message(forErrorCode code: Int) -> String? {
        string(forKey: "jpc-reg-error.\(code)", regional: false)
            ?? string(forKey: String(code), regional: false)
    }
}
```

**74.** `JackpotKit/Sources/JackpotLocalization/TranslationsRepository.swift`

The protocol and the fixed-table stub. The live implementation reads the app-data payload
and arrives with it at step 6.

```swift
import Foundation

public protocol TranslationsRepository: Sendable {
    func translations(region: String, tenant: String, locale: String) async throws -> Translations
}

/// A fixed table; the live one reads app-data and lives in `JackpotAppData`.
public struct StubTranslationsRepository: TranslationsRepository {
    private let table: Translations

    public init(_ table: Translations) {
        self.table = table
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        table
    }
}
```

**75.** `JackpotKit/Sources/JackpotLocalization/TranslationsStore.swift`

```swift
import Foundation
import Combine

@MainActor
/// Owns the session's table. Created at the composition root and injected, never a singleton.
/// `ObservableObject` rather than `@Observable` because the floor is iOS 15.
public final class TranslationsStore: ObservableObject {
    @Published public private(set) var translations = Translations()
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: (any Error)?

    private let repository: any TranslationsRepository
    private var loadTask: Task<Void, Never>?

    public init(repository: any TranslationsRepository) {
        self.repository = repository
    }

    public var isLoaded: Bool { !translations.isEmpty }

    /// Once per session; a call made while one is in flight is a no-op.
    public func load(region: String, tenant: String, locale: String) {
        guard loadTask == nil else { return }
        isLoading = true
        loadTask = Task { [weak self] in
            guard let self else { return }
            defer {
                loadTask = nil
                isLoading = false
            }
            do {
                translations = try await repository.translations(region: region, tenant: tenant, locale: locale)
                lastError = nil
            } catch is CancellationError {
            } catch {
                // Degraded, not fatal: lookups fall back to their keys.
                lastError = error
            }
        }
    }

    /// For hosts that already fetched app-data and shouldn't fetch it twice.
    public func adopt(_ translations: Translations) {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        self.translations = translations
    }

    public func clear() {
        loadTask?.cancel()
        loadTask = nil
        translations = Translations()
    }

    deinit { loadTask?.cancel() }
}
```

**76.** `JackpotKit/Sources/JackpotRegistration/Translations+FormLocalizing.swift`

```swift
import Foundation
import JackpotForms
import JackpotLocalization

public extension Translations {
    /// Feeds the app's table to the form engine. Lives here so neither module knows the other.
    /// `regional: true` covers both key shapes the schema uses: plain keys pick up `-jza`, suffixed keys resolve directly.
    var formLocalizer: ClosureLocalizer {
        ClosureLocalizer({ string(forKey: $0, regional: true) },
                         errorCode: { message(forErrorCode: $0) })
    }
}
```

**77.** `the app` — three changes

```swift
// 1. The store is created once, at the composition root, and injected.
let translations = TranslationsStore(repository: StubTranslationsRepository(Translations()))
translations.adopt(Translations(GlobalData.shareData.configData?.locale ?? [:],
                                regionCode: GlobalData.shareData.AppSetupData.wmsNavigationRegionCode))

// 2. The legacy helper becomes a shim. `regional` is passed through as given, so existing
//    call sites return byte-identical strings; the deprecation is the burn-down list.
@available(*, deprecated, message: "Inject TranslationsStore; call translations(key)")
@MainActor
func getTranslation(Key: String, regional: Bool = false) -> String {
    AppContainer.shared.translations.translations(Key, regional: regional)
}

// 3. Delete LegacyTranslationLocalizer.swift; registration takes the adapter. An empty table
//    means app-data has not landed; the bundled placeholder copy keeps the form legible until it does.
let table = translations.translations
forms: .live(baseURL: configURL,
             localizer: table.isEmpty ? ClosureLocalizer.jpcRegistration : table.formLocalizer)
```

---

### ▶ Create PR — translations

Every label reads as before; API error codes now resolve to localised copy.

---

## Step 6 — Fix app data

[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md) phase 1 and
[LAUNCH-PERFORMANCE](LAUNCH-PERFORMANCE.md). `AppDataResponse` splits the bootstrap payload
by top-level key so one null section cannot lose the other five; `FileAppDataCache` keeps the
last good payload; `AppDataLoader` serves it at zero latency and revalidates behind it;
`RemoteTranslationsRepository` feeds the store from the same payload.

**78.**

```bash
mkdir -p JackpotKit/Sources/JackpotAppData
```

**79.** `JackpotKit/Package.swift` — the whole file after this step

The last module. The manifest in the repository, less its test targets.

```swift
// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module. In Xcode: File → Add Package
// Dependencies → Add Local… → JackpotKit, then add the product you need to the app target.
// The floor is iOS 15, the host app's. docs/BUILD-PLAYBOOK.md builds this manifest one step at a
// time, and scripts/build-playbook.py checks that its final step matches this file exactly.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotForms", "JackpotRegistration",
                      "JackpotNetworking", "JackpotLocalization", "JackpotAppData"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms", "JackpotLocalization"], swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),

        .target(name: "JackpotLocalization", swiftSettings: strict),

        .target(name: "JackpotAppData", dependencies: ["JackpotNetworking", "JackpotLocalization"], swiftSettings: strict),
    ]
)
```

**80.** `JackpotKit/Sources/JackpotAppData/AppData.swift`

```swift
import Foundation
import JackpotNetworking

/// `GET {cron}/app-data/{region}/{platform}/{tenant}/{locale}?api-version=1.0`, once per session.
public struct AppDataRequest: APIEndpoint {
    let region: String
    let platform: String
    let tenant: String
    let locale: String

    public init(region: String, platform: String = "IOS", tenant: String, locale: String) {
        self.region = region
        self.platform = platform
        self.tenant = tenant
        self.locale = locale
    }

    public var path: String { "cron/app-data/\(region)/\(platform)/\(tenant)/\(locale)" }
    public var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "1.0")] }
    public var requiresAuth: Bool { false }
}

/// One response, decoded a section at a time, so a CMS edit that nulls one section cannot take the others with it.
public struct AppDataResponse: Sendable, Equatable {
    private let sections: [String: Data]

    public init(data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppDataError.notAnObject
        }
        sections = object.reduce(into: [:]) { result, pair in
            guard !(pair.value is NSNull) else { return }
            guard let data = try? JSONSerialization.data(withJSONObject: pair.value,
                                                         options: [.fragmentsAllowed]) else { return }
            result[pair.key] = data
        }
    }

    /// Nil if absent, null, or shaped differently; never throws.
    public func section<T: Decodable>(_ key: String,
                                      as type: T.Type = T.self,
                                      decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = sections[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// Worth logging: how you notice the CMS has started returning null for something.
    public var presentSections: [String] { sections.keys.sorted() }

    public func contains(_ key: String) -> Bool { sections[key] != nil }

    public var locales: [String: String] {
        section("locales") ?? [:]
    }
}

public enum AppDataError: Error, Equatable {
    case notAnObject
    case noPayload
}
```

**81.** `JackpotKit/Sources/JackpotAppData/AppDataCache.swift`

```swift
import Foundation
import JackpotNetworking

public struct CachedAppData: Sendable, Equatable {
    public let data: Data
    public let validators: HTTPValidators?
    public let storedAt: Date

    public init(data: Data, validators: HTTPValidators?, storedAt: Date) {
        self.data = data
        self.validators = validators
        self.storedAt = storedAt
    }

    public func age(now: Date = .now) -> TimeInterval {
        now.timeIntervalSince(storedAt)
    }
}

public protocol AppDataCaching: Sendable {
    func load(key: String) -> CachedAppData?
    func store(_ data: Data, validators: HTTPValidators?, key: String)
    func clear(key: String)
}

/// The last good payload, kept indefinitely in Application Support. Not `URLCache`: its five-minute
/// `max-age` is a CDN knob, useless for launches hours apart; the caller decides how stale is too stale.
public struct FileAppDataCache: AppDataCaching {
    private let directory: URL

    public init(directory: URL? = nil) {
        let manager = FileManager.default
        self.directory = directory ?? ((try? manager.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("JackpotAppData", isDirectory: true)
        try? manager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private func payloadURL(_ key: String) -> URL { directory.appendingPathComponent("\(key).json") }
    private func metaURL(_ key: String) -> URL { directory.appendingPathComponent("\(key).meta.json") }

    public func load(key: String) -> CachedAppData? {
        let payload = payloadURL(key)
        guard let data = try? Data(contentsOf: payload),
              let attributes = try? FileManager.default.attributesOfItem(atPath: payload.path),
              let storedAt = attributes[.modificationDate] as? Date
        else { return nil }
        let validators = (try? Data(contentsOf: metaURL(key)))
            .flatMap { try? JSONDecoder().decode(HTTPValidators.self, from: $0) }
        return CachedAppData(data: data, validators: validators, storedAt: storedAt)
    }

    public func store(_ data: Data, validators: HTTPValidators?, key: String) {
        // Atomic: a half-written payload on next launch is worse than none.
        try? data.write(to: payloadURL(key), options: .atomic)
        if let validators, let encoded = try? JSONEncoder().encode(validators) {
            try? encoded.write(to: metaURL(key), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: metaURL(key))
        }
    }

    public func clear(key: String) {
        try? FileManager.default.removeItem(at: payloadURL(key))
        try? FileManager.default.removeItem(at: metaURL(key))
    }
}

/// For tests and previews.
public final class InMemoryAppDataCache: AppDataCaching, @unchecked Sendable {
    private var entries: [String: CachedAppData] = [:]
    private let lock = NSLock()
    private let clock: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { .now }) {
        self.clock = now
    }

    public func load(key: String) -> CachedAppData? {
        lock.lock(); defer { lock.unlock() }
        return entries[key]
    }

    public func store(_ data: Data, validators: HTTPValidators?, key: String) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = CachedAppData(data: data, validators: validators, storedAt: clock())
    }

    public func clear(key: String) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = nil
    }

    public func seed(_ data: Data, validators: HTTPValidators? = nil, key: String, storedAt: Date) {
        lock.lock(); defer { lock.unlock() }
        entries[key] = CachedAppData(data: data, validators: validators, storedAt: storedAt)
    }
}
```

**82.** `JackpotKit/Sources/JackpotAppData/AppDataLoader.swift`

```swift
import Foundation
import JackpotNetworking

/// Where a payload came from; the app shows a skeleton only for `.none`.
public enum AppDataOrigin: Sendable, Equatable {
    case none
    case cache(age: TimeInterval)
    case network
}

public struct AppDataSnapshot: Sendable {
    public let response: AppDataResponse
    public let origin: AppDataOrigin

    public init(response: AppDataResponse, origin: AppDataOrigin) {
        self.response = response
        self.origin = origin
    }
}

/// `refreshAfter`: serve the cache and revalidate behind it. `maxStale`: beyond this, wait for the network.
/// The default is conservative because stale `wmsconfig` can show a game disabled for compliance.
public struct AppDataStalenessPolicy: Sendable, Equatable {
    public let refreshAfter: TimeInterval
    public let maxStale: TimeInterval

    public init(refreshAfter: TimeInterval = 0, maxStale: TimeInterval = 60 * 60 * 12) {
        self.refreshAfter = refreshAfter
        self.maxStale = maxStale
    }

    public static let `default` = AppDataStalenessPolicy()
}

/// Stale-while-revalidate: serve disk immediately, revalidate in the background, never block a launch on config.
public actor AppDataLoader {
    private let apiClient: any ApiClient
    private let cache: any AppDataCaching
    private let policy: AppDataStalenessPolicy
    private let now: @Sendable () -> Date

    public init(apiClient: any ApiClient,
                cache: any AppDataCaching,
                policy: AppDataStalenessPolicy = .default,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.apiClient = apiClient
        self.cache = cache
        self.policy = policy
        self.now = now
    }

    /// Nil only when there is no cache or it is beyond `maxStale`.
    public func cached(region: String, tenant: String, locale: String) -> AppDataSnapshot? {
        let key = Self.key(region: region, tenant: tenant, locale: locale)
        guard let entry = cache.load(key: key) else { return nil }
        let age = entry.age(now: now())
        guard age <= policy.maxStale else { return nil }
        guard let response = try? AppDataResponse(data: entry.data) else { return nil }
        return AppDataSnapshot(response: response, origin: .cache(age: age))
    }

    @discardableResult
    public func refresh(region: String, tenant: String, locale: String) async throws -> AppDataSnapshot? {
        let key = Self.key(region: region, tenant: tenant, locale: locale)
        let entry = cache.load(key: key)

        let result = try await apiClient.requestConditional(
            AppDataRequest(region: region, tenant: tenant, locale: locale),
            validators: entry?.validators
        )

        switch result {
        case .notModified:
            // Re-stamp, so the entry ages from the last confirmation, not the last change.
            if let entry {
                cache.store(entry.data, validators: entry.validators, key: key)
            }
            return nil

        case .fresh(let data, let validators):
            let response = try AppDataResponse(data: data)
            cache.store(data, validators: validators, key: key)
            return AppDataSnapshot(response: response, origin: .network)
        }
    }

    public func load(region: String, tenant: String, locale: String) async throws -> AppDataSnapshot {
        if let snapshot = cached(region: region, tenant: tenant, locale: locale) {
            return snapshot
        }
        // Sending stale validators would invite a 304 and leave this call with no payload.
        clear(region: region, tenant: tenant, locale: locale)
        guard let fresh = try await refresh(region: region, tenant: tenant, locale: locale) else {
            throw AppDataError.noPayload
        }
        return fresh
    }

    public func clear(region: String, tenant: String, locale: String) {
        cache.clear(key: Self.key(region: region, tenant: tenant, locale: locale))
    }

    static func key(region: String, tenant: String, locale: String) -> String {
        "\(region)-\(tenant)-\(locale)".lowercased()
    }
}
```

**83.** `JackpotKit/Sources/JackpotAppData/RemoteTranslationsRepository.swift`

```swift
import Foundation
import JackpotNetworking
import JackpotLocalization

/// Fetches the whole bootstrap payload and keeps only the strings.
public struct RemoteTranslationsRepository: TranslationsRepository {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) {
        self.apiClient = apiClient
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        let data = try await apiClient.requestData(
            AppDataRequest(region: region, tenant: tenant, locale: locale)
        )
        return Translations(try AppDataResponse(data: data).locales, regionCode: region)
    }
}
```

**84.** `the app — bootstrap`

```swift
let loader = AppDataLoader(apiClient: client, cache: FileAppDataCache(), policy: .default)

// On launch, before any UI:
if let snapshot = await loader.cached(region: region, tenant: "jackpotcity", locale: "en-US") {
    apply(snapshot.response)          // zero latency
} else {
    showLaunchSkeleton()              // first launch, or beyond maxStale
    apply(try await loader.load(region: region, tenant: "jackpotcity", locale: "en-US").response)
}

// Always, in the background:
Task { if let fresh = try? await loader.refresh(region: region, tenant: "jackpotcity", locale: "en-US") { apply(fresh.response) } }

func apply(_ response: AppDataResponse) {
    translations.adopt(Translations(response.locales, regionCode: region))
    // every other section is decoded by the feature that owns it
}
```

---

### ▶ Create PR — app data

Log `AppDataSnapshot.origin` at launch; a low `.cache` rate means `maxStale` is too tight.

---
