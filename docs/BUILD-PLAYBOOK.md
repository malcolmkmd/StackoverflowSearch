# Build Playbook

Create the files in the order given. Run the commands where they appear. Open a PR where
marked. Every code block is the file exactly as it is in the repository, and every
`Package.swift` block is the manifest as it stands after that step.

Six steps. The transport lands before the engine, so the registration sheet is wired to the
real client from its first line — one repository, one composition, no second code path to
keep in step. Where there is no backend yet the *bytes* are bundled, not the repository
faked: `BundledHTTPClient` answers from JSON in the package, and everything above it is the
shipping path. The sheet runs from step 3 that way and goes live in the app at step 4, on the
app's existing translation function. Steps 5 and 6 are the localisation and app-data
migrations from
[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md); registration
does not wait for them.

| Step | Adds | Demoable as |
| --- | --- | --- |
| 1 | `JackpotUI` | the gallery: every component, every state |
| 2 | `JackpotNetworking` | `RemoteApiClient` against a stubbed transport |
| 3 | `JackpotForms`, `JackpotRegistration` | the Sign Up sheet, both pages, submitted over bundled JSON |
| 4 | the app swap | registration live in the app, copy from `getTranslation` |
| 5 | `JackpotLocalization` | the same copy from a table built once; `getTranslation` becomes a shim |
| 6 | `JackpotAppData` | config served from disk on launch, revalidated behind it |

`JackpotKit` is one package; each folder under `Sources/` is a module. The floor is iOS 15,
the host app's. The test suite stays in this repository; the playbook lists source files only.

### Registration catalog

Twelve fields over two sections, checked against the live CRM response. The `fieldType`
values on registration are **Input**, **Dropdown** and
**Checkbox**; `FieldType` has those three plus `recaptchaV3` and `unknown`. Date of birth is
`Input` + `inputType: Calender` (the schema spelling). Recaptcha is not a field: a visible
`recapcha v3` row sets `FormSchema.hasRecaptcha` and is dropped, so it is never rendered or
validated. Submit asks the app for a v3 token and encodes it beside `fields`.

| Step | Identifier | `fieldType` | `inputType` | Renders as |
| --- | --- | --- | --- | --- |
| 1.1 | `username` | Input | Number | `JackpotTextField` · `.phoneNumber` · `+27` prefix |
| 1.2 | `password` | Input | Password | `JackpotTextField` · `.newPassword` · `JackpotChecklist` while focused, rules from `devConfig.regionPasswordSuggestions` |
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
`FormNavigationBar` around it. The bundled schema and the live CRM schema are the same twelve
fields above — paging is not a field.

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

### Registration rules and the offline path

1. **Schema.** `Resources/registration.json` is the CRM's response saved verbatim, decoded by
   `FormSchema(json:)` — the same mapper the app runs on the blob it injects. There is no
   hand-written schema anywhere: the fixture *is* a captured payload, so a preview and
   production cannot disagree about the twelve fields.
2. **One transport seam.** `FormDependencies.bundled()` is `.live(...)` with
   `BundledHTTPClient` in place of `URLSessionHTTPClient`. Endpoint building, status handling,
   envelope decoding and the error boundary are all the shipping code; only the bytes are
   local. `RemoteFormRepository` is the only `FormRepository` in the package.
3. **Both outcomes, offline.** Submitting `idNumber` `0000000000000` returns
   `submit-rejected.json`, the captured `isSuccessful: false` envelope, so the failure path is
   reachable without a backend — and reachable at all: thirteen digits clear the field's own
   rule, which is what lets **Sign Up** enable. Anything else returns `submit-accepted.json`.
4. **Copy.** `Resources/locales.json` is the `locales` slice of the same payload, read through
   the engine's one translation seam: `translate`, a `(String) -> String` closure shaped like
   the app's `getTranslation`, the key back on a miss. No copy table lives in Swift.
5. **Registration's rules.** The engine ships with no cross-field regex links and no date
   cap. `RegistrationDependencies` adds `regexDependencies: ["idNumber": "idNumberType"]`,
   an 18-years-ago `maximumDate`, and `passwordConfig` from injected `AppSettings` — the
   `appsettings` slice of app-data, mapped from `devConfig.regionPasswordSuggestions` with
   `passwordLength` as the fallback. JackpotKit never reads `GlobalData`.
6. **Sandbox.** In this repository the app's `SearchView` presents `RegistrationSandbox` with
   `.jackpotPopup`, the way the app presents its panels; the sandbox hosts
   `RegistrationView(dependencies: .bundled())` and shows the `RegistrationResult` it gets
   back, so the whole panel runs on a device with no backend.
7. **The sheet.** `RegistrationView` is the form inside `JackpotPanel`: title and close
   button on `surface`, the pages on `background`, and in the footer band `JackpotLinkRow`
   with `FormNavigationBar` beneath it.
8. **Previews.** One file, `JackpotRegistration/Previews.swift`: the sheet on `.bundled()`,
   dark and light. `JackpotPreviewPanel.swift` is the component gallery. There is no loading
   preview: the schema is injected rather than fetched, so `.loading` lasts one frame in
   production and previewing it would mean previewing a fake.

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
    public var background = Palette.background
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
set by the `jackpotFieldError(_:)` modifier and read by the chrome. `jackpotTranslate` is
the app's translation function, identity by default, so a component still renders the key.

```swift
import SwiftUI

extension EnvironmentValues {
    @Entry public var jackpotTheme: JackpotTheme = .jackpotCity
    @Entry public var jackpotIsLoading: Bool = false
    @Entry public var jackpotFocusedField: Binding<String?>? = nil
    @Entry public var jackpotFieldIdentity: String? = nil
    /// Identity by default, so a component still renders the key when no table is wired.
    public var jackpotTranslate: @Sendable (String) -> String {
        get { self[JackpotTranslateKey.self] }
        set { self[JackpotTranslateKey.self] = newValue }
    }

    @Entry var jackpotFieldError: String? = nil
}

private struct JackpotTranslateKey: EnvironmentKey {
    static let defaultValue: @Sendable (String) -> String = { $0 }
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

/// VoiceOver is handed a switch, not a button.
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
from `kind.isSecure`. Show / hide labels go through `jackpotTranslate`.

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
    @Environment(\.jackpotTranslate) private var translate
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
                .accessibilityLabel(isRevealed ? translate("hide-password") : translate("show-password"))
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

The live password-rules panel on `password`. Title and section stay plain strings — the
caller resolves keys before passing them in — so the component stays key-agnostic.

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
    @Environment(\.jackpotTranslate) private var translate
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
                        .accessibilityLabel(translate("requirements-met"))

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

## Step 2 — JackpotNetworking

The transport, before anything that needs it. `HTTPClient` is the seam — one method, and the
only place bytes come from — `APIEndpoint` is one request shape, and `RemoteApiClient` is the
pipeline. 200 / 400 / 401 / 500 are the contract; `unexpectedStatus` carries anything
infrastructure returns. `BundledHTTPClient` implements that same seam from JSON in a bundle,
which is what lets step 3 wire registration to the real client with nothing behind it: the
bytes are local, the pipeline above them is not. Nothing here knows about forms, and nothing
here needs translations: the app keeps `getTranslation`.

**20.**

```bash
mkdir -p JackpotKit/Sources/JackpotNetworking
```

**21.** `JackpotKit/Package.swift` — the whole file after this step

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
            targets: ["JackpotUI", "JackpotNetworking"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),
    ]
)
```

**22.** `JackpotKit/Sources/JackpotNetworking/HTTPMethod.swift`

```swift
import Foundation

public enum HTTPMethod: String, Sendable {
    case GET, POST, PUT, PATCH, DELETE
}
```

**23.** `JackpotKit/Sources/JackpotNetworking/HTTPClient.swift`

The seam. Each client owns a `URLSession`; nothing here reaches for `.shared`.

```swift
import Foundation

public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    public init(timeout: TimeInterval = 60, waitsForConnectivity: Bool = false) {
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

**24.** `JackpotKit/Sources/JackpotNetworking/APIEnvironment.swift`

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

**25.** `JackpotKit/Sources/JackpotNetworking/APIEndpoint.swift`

```swift
import Foundation

public enum RequestBody: Sendable {
    case json(Data)
    case form([String: String])
}

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

**26.** `JackpotKit/Sources/JackpotNetworking/APIError.swift`

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

    public var serverMessage: String? {
        problem?.message.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var isOffline: Bool {
        guard case .transport(let code) = self else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut].contains(code)
    }
}
```

**27.** `JackpotKit/Sources/JackpotNetworking/RequestInterceptor.swift`

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

**28.** `JackpotKit/Sources/JackpotNetworking/ConditionalRequest.swift`

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

**29.** `JackpotKit/Sources/JackpotNetworking/RemoteApiClient.swift`

The retry policy is the part to read: a 5xx or a dropped connection is retried, a 4xx never
is, and a non-idempotent request is retried only when the transport failed before the
server could have seen it.

```swift
import Foundation

public protocol ApiClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response
    func request(_ endpoint: some APIEndpoint) async throws
    /// The response body, undecoded.
    func data(for endpoint: some APIEndpoint) async throws -> Data
    /// Returns `.notModified` on a 304.
    func revalidate(_ endpoint: some APIEndpoint,
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

    public func data(for endpoint: some APIEndpoint) async throws -> Data {
        try await perform(endpoint).0
    }

    public func revalidate(_ endpoint: some APIEndpoint,
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

**30.** `JackpotKit/Sources/JackpotNetworking/BundledHTTPClient.swift`

The other implementation of the seam: bundled JSON in, an `HTTPURLResponse` out. It is not
a mock of the client — the client, the endpoints, the status handling and the decoding are
all still the shipping ones. `latency` makes in-flight states visible, and routing is a
closure so a fixture can depend on what was posted.

```swift
import Foundation

/// Answers requests from JSON that ships in a bundle, at the one seam the real client already has.
/// Everything above it — endpoint building, status handling, retries, decoding, error mapping — is
/// the shipping path, so a preview or a demo exercises that code rather than a parallel fake.
public struct BundledHTTPClient: HTTPClient {
    /// The bytes a request is answered with. Loaded up front so routing stays free of file I/O.
    public struct Fixture: Sendable {
        public let data: Data
        public let statusCode: Int

        public init(_ data: Data, statusCode: Int = 200) {
            self.data = data
            self.statusCode = statusCode
        }

        /// A `.json` file in `bundle`. Nil when the resource is missing, which is a wiring mistake
        /// rather than a server condition — let the caller decide how loud that should be.
        public init?(resource: String, in bundle: Bundle, statusCode: Int = 200) {
            guard let url = bundle.url(forResource: resource, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            self.init(data, statusCode: statusCode)
        }
    }

    private let latency: TimeInterval
    private let route: @Sendable (URLRequest) -> Fixture?

    /// - Parameters:
    ///   - latency: Artificial delay, so in-flight states are visible in a preview.
    ///   - route: The fixture that answers a request; nil is served as a 404.
    public init(latency: TimeInterval = 0,
                route: @escaping @Sendable (URLRequest) -> Fixture?) {
        self.latency = latency
        self.route = route
    }

    /// Every request is answered by the same fixture.
    public init(_ fixture: Fixture, latency: TimeInterval = 0) {
        self.init(latency: latency) { _ in fixture }
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if latency > 0 {
            try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        }
        let fixture = route(request)
        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: fixture?.statusCode ?? 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (fixture?.data ?? Data(), response)
    }
}
```

---

### ▶ Create PR — JackpotNetworking

---

## Step 3 — JackpotForms and the registration sheet

The engine, wired to the client from its first line. One module, folders pointing one way:
`Domain` (types and rules, no I/O), `Data` (wire shapes), `Password`, `Remote` (endpoints,
the repository, and the bundled composition) and `UI` (the model and the renderer). The engine
only ever sees `FormRepository`, and there is exactly one implementation of it —
`RemoteFormRepository`. Running without a backend is a transport choice, not a second
repository: `.bundled()` is `.live()` with `BundledHTTPClient` under it, so the whole sheet
runs on captured payloads while every line above the transport is the one that ships.
`JackpotRegistration` is the feature on top: the sheet, registration's own rules, and the
`DevConfig` mapping.

**31.**

```bash
mkdir -p JackpotKit/Sources/JackpotForms/{Domain,Data,Password,Remote,Resources,UI/Fields}
mkdir -p JackpotKit/Sources/JackpotRegistration
```

**32.** `JackpotKit/Package.swift` — the whole file after this step

`JackpotForms` takes `JackpotUI` and `JackpotNetworking`, and processes `Resources` —
the captured payloads the bundled transport serves. Wire types are `internal`.

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
            targets: ["JackpotUI", "JackpotNetworking", "JackpotForms",
                      "JackpotRegistration"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),
    ]
)
```

**33.** `JackpotKit/Sources/JackpotForms/Domain/FormName.swift`

`.registration` is the live form.

```swift
import Foundation

/// The `formCodeName` in the schema and the last path component of the fetch URL. A struct rather than an
/// enum because forms are authored server-side, so `FormName("deposit")` must be constructible; not
/// `ExpressibleByStringLiteral`, so a typo cannot compile into a 404.
public struct FormName: RawRepresentable, Hashable, Sendable, Encodable {
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
    static let registration = FormName("registration")

    /// Web `captchaV3Actions`: registration submits as `"register"`.
    var recaptchaAction: String {
        rawValue == "registration" ? "register" : rawValue
    }
}
```

**34.** `JackpotKit/Sources/JackpotForms/Domain/FormValue.swift`

```swift
import Foundation

/// Every case renders as a string because the schema validates with regexes, `^true$` for checkboxes included.
public enum FormValue: Equatable, Hashable, Sendable {
    case empty
    case text(String)
    case bool(Bool)
    case date(Date)

    public var stringValue: String {
        switch self {
        case .empty:       return ""
        case .text(let s): return s
        case .bool(let b): return b ? "true" : "false"
        case .date(let d): return FormValue.iso8601.format(d)
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .empty:       return true
        case .text(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // An unticked required checkbox counts as empty, which is what makes `terms` work.
        case .bool(let b): return !b
        case .date:        return false
        }
    }

    public var boolValue: Bool { stringValue == "true" }

    public var dateValue: Date? {
        if case .date(let d) = self { return d }
        return nil
    }

    /// The `dateOfBirth` regex expects an ISO-8601 date-time: `1990-01-01T00:00:00Z`.
    public static let iso8601 = Date.ISO8601FormatStyle()
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

/// Recaptcha is encoded as a sibling of `fields`, matching the web request body.
public struct FormSubmission: Equatable, Sendable, Encodable {
    public let formId: String
    public let formCodeName: FormName
    public let submittedAt: Date
    public let values: [String: FormValue]
    public let recaptcha: String?

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case formCodeName = "form_name"
        case submittedAt = "submitted_at"
        case values = "fields"
        case recaptcha
    }

    public init(formCodeName: FormName,
                values: [String: FormValue],
                recaptcha: String? = nil,
                formId: String = "",
                submittedAt: Date = Date()) {
        self.formId = formId
        self.formCodeName = formCodeName
        self.submittedAt = submittedAt
        self.values = values
        self.recaptcha = recaptcha
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formId, forKey: .formId)
        try container.encode(formCodeName, forKey: .formCodeName)
        try container.encode(submittedAt, forKey: .submittedAt)
        try container.encode(values, forKey: .values)
        try container.encodeIfPresent(recaptcha, forKey: .recaptcha)
    }

    public subscript(identifier: String) -> FormValue {
        values[identifier] ?? .empty
    }
}
```

**35.** `JackpotKit/Sources/JackpotForms/Domain/FormField.swift`

`FieldType` is Input, Dropdown, Checkbox and recaptchaV3 — plus `unknown`, which is what
keeps the form usable when the CRM adds a type this build cannot draw. WMS spells recaptcha
`recapcha v3`.

```swift
import Foundation

/// `unknown` is load-bearing: the CRM edits the schema without an app release, so an unknown type is skipped, never fatal.
public enum FieldType: Equatable, Hashable, Sendable {
    case input
    case dropdown
    case checkbox
    case recaptchaV3
    case unknown(String)

    public init(raw: String) {
        switch raw.lowercased().replacingOccurrences(of: " ", with: "") {
        case "input":              self = .input
        case "dropdown", "select": self = .dropdown
        case "checkbox":           self = .checkbox
        // WMS spells it "recapcha v3".
        case "recapchav3", "recaptchav3": self = .recaptchaV3
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
    /// Server-supplied, so possibly invalid; see `accepts(_:overrideRegex:)`.
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

    /// Regexes come from a server: one that will not compile is treated as no constraint.
    /// - Parameter overrideRegex: replaces `regex` when a dropdown selection changes this field's rule.
    public func accepts(_ value: FormValue, overrideRegex: String? = nil) -> Bool {
        guard isVisible, !isReadOnly else { return true }
        // Not every optional field's regex permits empty; this is what keeps optional optional.
        if value.isEmpty { return !isRequired }
        guard let pattern = overrideRegex ?? regex, !pattern.isEmpty,
              let expression = try? NSRegularExpression(pattern: pattern) else { return true }
        let subject = value.stringValue
        return expression.firstMatch(in: subject, range: NSRange(subject.startIndex..., in: subject)) != nil
    }
}
```

**36.** `JackpotKit/Sources/JackpotForms/Domain/FormSchema.swift`

```swift
import Foundation

public struct FormSchema: Identifiable, Equatable, Sendable {
    public let id: Int
    public let codeName: FormName
    public let sections: [FormSection]
    /// Visible recaptcha v3 was in the CRM schema; the row is stripped so it is never rendered or validated.
    public let hasRecaptcha: Bool

    public init(id: Int, codeName: FormName, sections: [FormSection], hasRecaptcha: Bool = false) {
        self.id = id
        self.codeName = codeName
        self.sections = sections
        self.hasRecaptcha = hasRecaptcha
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

**37.** `JackpotKit/Sources/JackpotForms/Domain/FormSubmitResult.swift`

```swift
import Foundation

public struct FormSubmitResult: Decodable, Equatable, Sendable {
    public let accountId: String?
    public let message: String?
    private let partialRegistrationStatus: Int?
    private let complianceResponse: Compliance?

    private struct Compliance: Decodable, Equatable, Sendable {
        let accessToken: String?
    }

    public init(accountId: String? = nil, message: String? = nil) {
        self.accountId = accountId
        self.message = message
        partialRegistrationStatus = nil
        complianceResponse = nil
    }

    /// Account exists but auto-FICA didn't finish (`jpc-partially-complete-profile`).
    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }

    /// The session token when the account was created; the app logs in with it.
    public var accessToken: String? { complianceResponse?.accessToken }
}
```

**38.** `JackpotKit/Sources/JackpotForms/Domain/FormError.swift`

```swift
import Foundation

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

**39.** `JackpotKit/Sources/JackpotForms/Domain/FormRepository.swift`

```swift
import Foundation

public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
}
```

**40.** `JackpotKit/Sources/JackpotForms/Data/FormDTO.swift`

The wire shapes. A recaptcha row is dropped here and `hasRecaptcha` is set, so `allFields`
never sees it — the same as the web's `processSection`. `FormSchema(json:)` is how the host
injects the `registration` blob it already has.

```swift
import Foundation

struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let sections: [FormSectionDTO]?

    var schema: FormSchema {
        // Recaptcha is not a field: any row that contains it is dropped, and a visible one sets `hasRecaptcha`.
        var hasRecaptcha = false
        let mapped = (sections ?? [])
            .sorted { ($0.formSectionOrder ?? $0.formSectionId) < ($1.formSectionOrder ?? $1.formSectionId) }
            .map { dto -> FormSection in
                let rows = dto.section.rows.compactMap { row -> FormRow? in
                    guard row.fields.contains(where: { $0.type == .recaptchaV3 }) else { return row }
                    if row.fields.contains(where: { $0.type == .recaptchaV3 && $0.isVisible }) {
                        hasRecaptcha = true
                    }
                    return nil
                }
                return FormSection(id: dto.formSectionId, rows: rows)
            }
        return FormSchema(id: formId, codeName: FormName(formCodeName), sections: mapped, hasRecaptcha: hasRecaptcha)
    }
}

extension FormSchema {
    public init(json: Data) throws {
        self = try JSONDecoder().decode(FormDTO.self, from: json).schema
    }
}

struct FormSectionDTO: Decodable {
    let formSectionId: Int
    let formSectionOrder: Int?
    let rows: [FormRowDTO]?

    var section: FormSection {
        FormSection(id: formSectionId, rows: (rows ?? []).map(\.row).sorted { $0.number < $1.number })
    }
}

struct FormRowDTO: Decodable {
    let rowNumber: Int
    let fields: [FormFieldDTO]?

    var row: FormRow {
        FormRow(number: rowNumber, fields: (fields ?? []).map(\.field))
    }
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

    var field: FormField {
        FormField(
            id: fieldId,
            identifier: fieldIdentifier,
            labelKey: fieldLabel,
            type: FieldType(raw: fieldType),
            inputType: InputType(raw: inputType ?? "Text"),
            validationMessageKey: validationMessage ?? "regex",
            // Unspecified is optional and visible, so a CMS omission cannot block submit.
            isRequired: isRequired ?? false,
            isVisible: isVisible ?? true,
            isReadOnly: isReadOnly ?? false,
            regex: fieldRegex?.isEmpty == true ? nil : fieldRegex,
            prefix: prefix ?? "",
            suffix: suffix ?? "",
            dropdownOptions: (fieldDropdowns ?? []).map {
                DropdownOption(value: $0.value, textKey: $0.text ?? $0.value, regex: $0.regex)
            }
        )
    }
}

struct FieldDropdownDTO: Decodable {
    let value: String
    let text: String?
    let regex: String?
}
```

**41.** `JackpotKit/Sources/JackpotForms/Password/PasswordSuggestions.swift`

The checklist rows, keyed the same way as the web (`min-N-char`, `password-is-vulnerable`).

```swift
import Foundation
import JackpotUI

public enum PasswordSuggestions {
    public struct Config: Sendable, Equatable {
        public var min: Int?
        public var max: Int?
        public var vulnerable: Bool
        public var spaces: Bool
        public var required: Set<PasswordCharacterClass>

        public init(min: Int? = nil,
                    max: Int? = nil,
                    vulnerable: Bool = false,
                    spaces: Bool = false,
                    required: Set<PasswordCharacterClass> = []) {
            self.min = min
            self.max = max
            self.vulnerable = vulnerable
            self.spaces = spaces
            self.required = required
        }
    }

    public static func items(for value: String,
                              config: Config,
                              translate: (String) -> String) -> [JackpotChecklistItem] {
        var items: [JackpotChecklistItem] = []
        if let n = config.min {
            items.append(.init(id: "min",
                                text: translate("min-\(n)-char"),
                                isSatisfied: value.count >= n))
        }
        if let n = config.max {
            items.append(.init(id: "max",
                                text: translate("max-\(n)-char"),
                                isSatisfied: !value.isEmpty && value.count <= n))
        }
        if config.vulnerable {
            items.append(.init(id: "vulnerable",
                                text: translate("password-is-vulnerable"),
                                isSatisfied: value.range(of: "password", options: .caseInsensitive) == nil))
        }
        if config.spaces {
            items.append(.init(id: "spaces",
                                text: translate("please-remove-spaces"),
                                isSatisfied: value.rangeOfCharacter(from: .whitespaces) == nil))
        }
        for cls in [PasswordCharacterClass.upper, .lower, .number, .special] where config.required.contains(cls) {
            items.append(cls.checklistItem(for: value, translate: translate))
        }
        return items
    }
}

public enum PasswordCharacterClass: String, Codable, Sendable {
    case upper, lower, number, special
}

extension PasswordCharacterClass {
    var translationKey: String {
        switch self {
        case .upper:   return "at-least-one-upper-char"
        case .lower:   return "at-least-one-lower-char"
        case .number:  return "at-least-one-num-char"
        case .special: return "at-least-one-special-char"
        }
    }

    func isSatisfied(by value: String) -> Bool {
        switch self {
        case .upper:   return value.rangeOfCharacter(from: .uppercaseLetters) != nil
        case .lower:   return value.rangeOfCharacter(from: .lowercaseLetters) != nil
        case .number:  return value.rangeOfCharacter(from: .decimalDigits) != nil
        case .special: return value.rangeOfCharacter(from: CharacterSet.alphanumerics.union(.whitespaces).inverted) != nil
        }
    }

    func checklistItem(for value: String, translate: (String) -> String) -> JackpotChecklistItem {
        JackpotChecklistItem(id: rawValue, text: translate(translationKey), isSatisfied: isSatisfied(by: value))
    }
}
```

Then `Remote`, in the same step — there is no stage at which the engine is wired to something
else. Two of the four resources are captured payloads rather than authored files, so they are
copied in rather than printed:

**42.**

```bash
cp registration.json JackpotKit/Sources/JackpotForms/Resources/registration.json
cp locales.json     JackpotKit/Sources/JackpotForms/Resources/locales.json
```

`registration.json` is the CRM's response saved verbatim — the twelve fields over two
sections in the catalog above. `locales.json` is the `locales` slice of the app-data payload,
trimmed to the keys registration asks for. Both are data the CMS owns: nothing in the package
restates them in Swift, so a preview and production cannot drift apart.

**43.** `JackpotKit/Sources/JackpotForms/Remote/FormEndpoints.swift`

The submit path and the envelope it comes back in. The form GET is not used: the schema is
injected, here from `registration.json` and in the app from the bootstrap payload.

```swift
import Foundation
import JackpotNetworking

struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    var path: String { "cron/forms/\(brand)/\(region)/\(formName.rawValue)" }
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "2.0")] }
}

/// No `api-version`. No auth: registration happens before login.
struct FormSubmitRequest: APIEndpoint {
    let bodyData: Data

    /// ISO-8601 is an assumption; the production encoder wasn't visible.
    init(_ submission: FormSubmission) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        bodyData = try encoder.encode(submission)
    }

    var path: String { "cron/forms/submit" }
    var method: HTTPMethod { .POST }
    var body: RequestBody? { .json(bodyData) }
    var requiresAuth: Bool { false }
}

/// HTTP 200 is not success: `isSuccessful` is.
struct FormSubmitEnvelope: Decodable {
    let data: FormSubmitResult?
    let isSuccessful: Bool?
    let error: Failure?

    struct Failure: Decodable {
        let code: Int?
        let displayCode: Int?
        let message: String?
    }
}
```

**44.** `JackpotKit/Sources/JackpotForms/Remote/RemoteFormRepository.swift`

The only `FormRepository`. Submit only — HTTP 200 is not success, the envelope's
`isSuccessful` is, and a body that is not the envelope is a rejection. The engine cannot see
`APIError`, so anything not translated in `userFacing` becomes a generic failure on screen.
`.live(...)` is at the bottom, and its `httpClient` parameter is the whole offline story.

```swift
import Foundation
import JackpotNetworking

public struct RemoteFormRepository: FormRepository {
    private let form: FormSchema
    private let apiClient: any ApiClient
    private let translate: @Sendable (String) -> String

    public init(form: FormSchema = FormSchema(id: 0, codeName: .registration, sections: []),
                apiClient: any ApiClient,
                translate: @escaping @Sendable (String) -> String = { $0 }) {
        self.form = form
        self.apiClient = apiClient
        self.translate = translate
    }

    public func form(named name: FormName) async throws -> FormSchema {
        guard name == form.codeName else { throw FormError.notFound(name) }
        return form
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        do {
            let data = try await apiClient.data(for: FormSubmitRequest(submission))
            // An empty 2xx is taken as accepted (an assumption); anything else must say `isSuccessful: true`.
            if data.isEmpty { return FormSubmitResult() }
            let envelope = try? JSONDecoder().decode(FormSubmitEnvelope.self, from: data)
            guard let envelope, envelope.isSuccessful == true else {
                let failure = envelope?.error
                throw FormError.server(message: message(code: failure?.code ?? failure?.displayCode, server: failure?.message)
                                       ?? "We couldn't submit the form. Please try again.")
            }
            return envelope.data ?? FormSubmitResult()
        } catch {
            throw userFacing(error, formName: submission.formCodeName)
        }
    }

    // MARK: Errors

    /// Where transport errors become something a person can read; the engine never sees `APIError`.
    func userFacing(_ error: any Error, formName: FormName) -> any Error {
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
            return message(code: apiError.problem?.code, server: apiError.serverMessage)
                .map { FormError.server(message: $0) } ?? FormError.unexpected
        case .transport, .decoding, .invalidURL:
            return FormError.unexpected
        }
    }

    /// Error codes are translation keys, `jpc-reg-error.{code}` for registration and the bare number elsewhere;
    /// an untranslated key falls back to the server's wording.
    func message(code: Int?, server: String?) -> String? {
        for key in code.map({ ["jpc-reg-error.\($0)", String($0)] }) ?? [] {
            let copy = translate(key)
            if copy != key { return copy }
        }
        return server
    }
}

public extension FormDependencies {
    /// - Parameter httpClient: The transport. Swap it for a `BundledHTTPClient` to run this exact
    ///   composition — same endpoints, same decoding, same error mapping — without a backend.
    static func live(form: FormSchema,
                     baseURL: URL,
                     httpClient: any HTTPClient = URLSessionHTTPClient(),
                     translate: @escaping @Sendable (String) -> String,
                     recaptcha: @escaping @Sendable (String) async throws -> String?) -> FormDependencies {
        let client = RemoteApiClient(environment: APIEnvironment(baseURL: baseURL), httpClient: httpClient)
        return FormDependencies(
            repository: RemoteFormRepository(form: form, apiClient: client, translate: translate),
            translate: translate,
            recaptcha: recaptcha
        )
    }

    static func live(formJSON: Data,
                     baseURL: URL,
                     httpClient: any HTTPClient = URLSessionHTTPClient(),
                     translate: @escaping @Sendable (String) -> String,
                     recaptcha: @escaping @Sendable (String) async throws -> String?) throws -> FormDependencies {
        try live(form: FormSchema(json: formJSON), baseURL: baseURL, httpClient: httpClient,
                 translate: translate, recaptcha: recaptcha)
    }
}
```

**45.** `JackpotKit/Sources/JackpotForms/Resources/submit-accepted.json`

The captured success envelope: an account id, the FICA block, and the JWT the app logs in with.

```json
{
  "data": {
    "accountId": "32212b00-54d0-449e-877a-f712f0976823",
    "message": "User Created Successfully.",
    "status": "Success.",
    "partialRegistrationStatus": 0,
    "complianceResponse": {
      "complianceStatus": 1,
      "requiredComplianceStatus": 1,
      "isValidId": true,
      "message": null,
      "accessToken": "_act-jwt-bundled-fixture"
    }
  },
  "isSuccessful": true,
  "error": null,
  "metadata": null,
  "httpStatusCode": 200
}
```

**46.** `JackpotKit/Sources/JackpotForms/Resources/submit-rejected.json`

The captured rejection — HTTP 200 with `isSuccessful: false`. `error.code` is a translation key,
`jpc-reg-error.153008`, which `locales.json` carries; an untranslated code falls back to
`error.message`.

```json
{
  "data": null,
  "isSuccessful": false,
  "error": {
    "code": 153008,
    "displayCode": 153008,
    "message": "An Error Occurred.",
    "remediation": null
  },
  "metadata": null,
  "httpStatusCode": 200
}
```

**47.** `JackpotKit/Sources/JackpotForms/Remote/BundledForms.swift`

Where the four resources become a `FormDependencies`. `.bundled()` calls `.live()` — same
repository, same endpoints, same decoding — and passes `BundledHTTPClient` as the transport.
The rejection is keyed on an `idNumber` of thirteen zeros because it has to clear the field's
own `^[0-9]{13}$` rule before **Sign Up** will enable; a value the form rejects could never
reach the wire, so it could never demo the wire's failure.

```swift
import Foundation
import JackpotNetworking

/// The captured CRM payloads that ship with the package: the `registration` schema, the `locales`
/// slice that labels it, and the two submit envelopes. Previews, the sandbox and any build without
/// a backend run on these — through the shipping repository, never a second implementation.
public enum FormFixtures {
    /// The schema blob exactly as the CRM returned it. In the app this same shape arrives on
    /// app-data; here it is a file, which is the only difference.
    public static let registrationJSON: Data = json("registration")

    /// Empty only if the resource is missing or malformed, which `BundledFormsTests` rules out.
    public static let registrationSchema: FormSchema =
        (try? FormSchema(json: registrationJSON)) ?? FormSchema(id: 0, codeName: .registration, sections: [])

    /// Stands in for the app's `getTranslation`: same contract, the key back on a miss.
    public static let translate: @Sendable (String) -> String = { locales[$0.lowercased()] ?? $0 }

    /// The `idNumber` the bundled CRM rejects. Thirteen digits, so it clears the field's own rule
    /// and the form can actually be submitted — which is what makes the failure path reachable.
    public static let rejectedIdNumber = "0000000000000"

    static let locales: [String: String] =
        (try? JSONDecoder().decode([String: String].self, from: json("locales"))) ?? [:]

    static func json(_ resource: String) -> Data {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return Data() }
        return data
    }
}

public extension FormDependencies {
    /// The live composition over bundled bytes: real endpoints, real envelope decoding, real error
    /// mapping, with `BundledHTTPClient` in place of the network. Submitting
    /// `FormFixtures.rejectedIdNumber` returns the CRM's rejection envelope, so both outcomes are
    /// demoable offline.
    ///
    /// - Parameter delay: Latency on submit, so the button's in-flight state is visible.
    static func bundled(delay: TimeInterval = 0.35) -> FormDependencies {
        let accepted = BundledHTTPClient.Fixture(resource: "submit-accepted", in: .module)
        let rejected = BundledHTTPClient.Fixture(resource: "submit-rejected", in: .module)
        let transport = BundledHTTPClient(latency: delay) { request in
            let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
            return body.contains("\"idNumber\":\"\(FormFixtures.rejectedIdNumber)\"") ? rejected : accepted
        }
        return live(
            form: FormFixtures.registrationSchema,
            baseURL: URL(string: "https://config.jpc.africa")!,
            httpClient: transport,
            translate: FormFixtures.translate,
            // The captured schema carries no recaptcha row, so nothing asks for a token.
            recaptcha: { _ in nil }
        )
    }
}
```

**48.** `JackpotKit/Sources/JackpotForms/UI/FormDependencies.swift`

The engine's dependencies. `translate` is the one translation seam: a key
in, its text out, the key itself on a miss, so the app's `getTranslation` plugs in as it is.
`passwordConfig` is a plain struct the engine draws. `recaptcha` is a closure. The host
injects both at the composition root — JackpotKit never reads `GlobalData`. Throw from
`recaptcha` to fail the submit (web logs and re-throws); return nil to post without a token
and let the server 401.

```swift
import Foundation

public struct FormDependencies {
    public var repository: any FormRepository
    /// A key in, its text out, and the key itself on a miss.
    public var translate: @Sendable (String) -> String
    /// "This field's regex is chosen by that dropdown", by identifier. Declared, never inferred from row order.
    public var regexDependencies: [String: String]
    /// What a name on a dropdown option's `regex` stands for. A literal pattern there describes the selection itself.
    public var namedPatterns: [String: String]
    public var maximumDate: Date?
    public var passwordConfig: PasswordSuggestions.Config
    /// Returns a v3 assessment token for the given action, or nil to skip. The app wires this to Google's SDK; the package never imports it.
    public var recaptcha: @Sendable (String) async throws -> String?

    public init(repository: any FormRepository,
                translate: @escaping @Sendable (String) -> String = { $0 },
                regexDependencies: [String: String] = [:],
                namedPatterns: [String: String] = FormDependencies.jpcPatterns,
                maximumDate: Date? = nil,
                passwordConfig: PasswordSuggestions.Config = .init(),
                recaptcha: @escaping @Sendable (String) async throws -> String? = { _ in nil }) {
        self.repository = repository
        self.translate = translate
        self.regexDependencies = regexDependencies
        self.namedPatterns = namedPatterns
        self.maximumDate = maximumDate
        self.passwordConfig = passwordConfig
        self.recaptcha = recaptcha
    }

    /// `passportNumberRegex` is a length rule, not a character class.
    public static let jpcPatterns = [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ]
}
```

**49.** `JackpotKit/Sources/JackpotForms/UI/DynamicFormModel.swift`

The engine. Its state is `values` and `touched`; validity, errors and progress are computed
from those on every read, so nothing has to be re-validated when a dropdown changes
another field's rule. `load()` is `async` and a no-op once loaded, so re-appearing on screen
cannot reset a half-filled form. `advance()` / `goBack()` / `submit()` are what Next,
Previous and Sign Up call; `submit()` posts through the same `FormRepository` that loaded
the form. `overrideRegex(for:)` is how selecting Passport relaxes the SA-ID rule on a
different field. A field's rule is `FormField.accepts(_:overrideRegex:)`: a server regex
that will not compile is no constraint. `submit()` asks `recaptcha` for a token only when
`hasRecaptcha` is set.

```swift
import Foundation
import Combine

@MainActor
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

    @Published public private(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var sectionIndex: Int = 0
    @Published public private(set) var pagingDirection: PagingDirection = .forward
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

    @Published private var touched: Set<String> = []

    private let formName: FormName
    private let dependencies: FormDependencies

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

    /// Nil while the field is untouched. Every field carries `validationMessage: "regex"`, so the key is composed:
    /// `jpc-reg-{identifier}-{key}`.
    public func error(for field: FormField) -> String? {
        guard touched.contains(field.identifier), !isValid(field) else { return nil }
        return translate("jpc-reg-\(field.identifier)-\(field.validationMessageKey)")
    }

    public var translate: @Sendable (String) -> String { dependencies.translate }

    public var maximumDate: Date { dependencies.maximumDate ?? Date() }

    public var passwordConfig: PasswordSuggestions.Config { dependencies.passwordConfig }

    /// A no-op once loaded, so re-appearing cannot reset a half-filled form.
    public func load() async {
        if case .loaded = viewState { return }
        viewState = .loading
        do {
            let form = try await dependencies.repository.form(named: formName)
            values = Dictionary(uniqueKeysWithValues:
                form.allFields.filter(\.isVisible).map { ($0.identifier, defaultValue(for: $0)) }
            )
            viewState = .loaded(form)
        } catch is CancellationError {
        } catch {
            viewState = .failed(Self.message(for: error))
        }
    }

    private func defaultValue(for field: FormField) -> FormValue {
        switch field.type {
        case .checkbox:                              return .bool(false)
        case .input, .dropdown, .recaptchaV3, .unknown:
            return field.inputType == .calendar ? .empty : .text("")
        }
    }

    public func setValue(_ value: FormValue, for field: FormField) {
        values[field.identifier] = value
    }

    public func markTouched(_ identifier: String) {
        guard !touched.contains(identifier) else { return }
        touched.insert(identifier)
    }

    private func isValid(_ field: FormField) -> Bool {
        field.accepts(value(for: field), overrideRegex: overrideRegex(for: field))
    }

    /// ID type → ID number: Passport relaxes the thirteen-digit rule.
    private func overrideRegex(for field: FormField) -> String? {
        guard let driver = dependencies.regexDependencies[field.identifier].flatMap({ form?.field(identifiedBy: $0) }),
              let option = driver.dropdownOptions.first(where: { $0.value == value(for: driver).stringValue }),
              let name = option.regex
        else { return nil }
        return dependencies.namedPatterns[name]
    }

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

    public func submit() async -> FormSubmitResult? {
        guard let form, isFormValid else { return nil }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            var token: String?
            if form.hasRecaptcha {
                token = try await dependencies.recaptcha(form.codeName.recaptchaAction)
            }
            return try await dependencies.repository.submitForm(
                FormSubmission(formCodeName: form.codeName,
                               values: values,
                               recaptcha: token,
                               formId: String(form.id))
            )
        } catch is CancellationError {
        } catch {
            submitError = Self.message(for: error)
        }
        return nil
    }

    private static func message(for error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
    }
}
```

**50.** `JackpotKit/Sources/JackpotForms/UI/Fields/FieldRenderer.swift`

The switch is the whole contract. Recaptcha never lands here — it is stripped in the mapper.

```swift
import SwiftUI
import JackpotUI

/// Recaptcha is stripped in the mapper, so `.recaptchaV3` here is defensive.
struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        Group {
            switch field.type {
            case .input where field.inputType == .calendar:
                JackpotDateField(model.translate(field.labelKey), selection: model.date(for: field), in: ...model.maximumDate)
            case .input:
                InputFieldView(field: field, model: model)
            case .dropdown:
                JackpotDropdown(model.translate(field.labelKey), selection: model.selection(for: field), options: model.options(for: field))
            // Checkboxes validate as "true" / "false"; `terms` uses `^true$` to mean "must be ticked".
            case .checkbox:
                Toggle(model.translate(field.labelKey), isOn: model.bool(for: field))
                    .toggleStyle(.jackpotCheckbox)
            case .recaptchaV3, .unknown:
                EmptyView()
            }
        }
        .disabled(field.isReadOnly)
        .jackpotFieldError(model.error(for: field))
    }
}

extension FormField {
    var acceptsKeyboardFocus: Bool {
        type == .input && inputType != .calendar
    }
}

extension DynamicFormModel {
    var focusableIdentifiers: [String] {
        (currentSection?.fields ?? []).filter { $0.isVisible && $0.acceptsKeyboardFocus }.map(\.identifier)
    }

    func fieldAfter(_ identifier: String?) -> String? {
        let ids = focusableIdentifiers
        guard let identifier, let index = ids.firstIndex(of: identifier) else { return nil }
        let next = ids.index(after: index)
        return next < ids.endIndex ? ids[next] : nil
    }
}

extension DynamicFormModel {
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    // Discrete choices mark the field touched as they write; typing reports blur through `onEditingEnded`.
    func selection(for field: FormField) -> Binding<String?> {
        Binding(get: { let v = self.value(for: field).stringValue; return v.isEmpty ? nil : v },
                set: { self.setValue(.text($0 ?? ""), for: field); self.markTouched(field.identifier) })
    }

    func bool(for field: FormField) -> Binding<Bool> {
        Binding(get: { self.value(for: field).boolValue },
                set: { self.setValue(.bool($0), for: field); self.markTouched(field.identifier) })
    }

    func date(for field: FormField) -> Binding<Date?> {
        Binding(get: { self.value(for: field).dateValue },
                set: { self.setValue($0.map(FormValue.date) ?? .empty, for: field); self.markTouched(field.identifier) })
    }

    func options(for field: FormField) -> [JackpotOption] {
        field.dropdownOptions.map { JackpotOption(id: $0.value, label: translate($0.textKey)) }
    }
}
```

**51.** `JackpotKit/Sources/JackpotForms/UI/Fields/InputFieldView.swift`

The text field, with the password checklist from `PasswordSuggestions` while focused.

```swift
import SwiftUI
import JackpotUI

struct InputFieldView: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    @State private var isEditing = false

    var body: some View {
        VStack(spacing: .xs) {
            JackpotTextField(model.translate(field.labelKey),
                             text: model.text(for: field),
                             kind: kind,
                             prefix: field.prefix,
                             suffix: field.suffix)
                .onEditingEnded { model.markTouched(field.identifier) }
                .onFocusChange { isEditing = $0 }
                .jackpotFieldIdentity(field.identifier)
                .submitLabel(model.focusableIdentifiers.last == field.identifier ? .done : .next)

            // The rules are guidance while composing; once the field is left, the error line carries the verdict.
            if field.inputType == .password, isEditing {
                JackpotChecklist(model.translate("password-validity"),
                                 section: model.translate("required"),
                                 items: PasswordSuggestions.items(for: model.value(for: field).stringValue,
                                                                 config: model.passwordConfig,
                                                                 translate: model.translate))
                    .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isEditing)
    }

    private var kind: JackpotFieldKind {
        switch field.inputType {
        case .password: return .newPassword
        case .email:    return .email
        case .phone:    return .phoneNumber
        case .number:   return .number
        default:        break
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
```

**52.** `JackpotKit/Sources/JackpotForms/UI/DynamicFormContent.swift`

Two views over one model. `DynamicFormContent` is the pages; `FormNavigationBar` is
Previous / Next / Sign Up — that is how step 1 becomes step 2 — and slides the pages
using the direction the model publishes. Both look up copy through `jackpotTranslate`,
seeded by `RegistrationView`. Registration composes the two inside its panel.

```swift
import SwiftUI
import JackpotUI

public struct DynamicFormContent: View {
    @ObservedObject private var model: DynamicFormModel

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.jackpotTranslate) private var translate
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
                .accessibilityLabel(translate("loading-form"))

        case .failed(let message):
            JackpotErrorView(message, title: translate("couldnt-load-form"))
                .onRetry { Task { await model.load() } }

        case .loaded:
            VStack(spacing: 0) {
                if model.sections.count > 1 {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.jackpotBar)
                        .padding(.horizontal, .m).padding(.top, .sm)
                        .accessibilityLabel(translate("form-progress"))
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
                    }
                    .padding(.m)
                    .id(model.sectionIndex)
                    .transition(sectionTransition)
                }
            }
            .jackpotFocusedField($focusedField)
            .onSubmit {
                guard let current = focusedField else { return }
                model.markTouched(current)
                focusedField = model.fieldAfter(current)
            }
            .onChange(of: model.sectionIndex) { _ in focusedField = nil }
        }
    }

    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let travel: CGFloat = model.pagingDirection == .forward ? 60 : -60
        return .asymmetric(insertion: .offset(x: travel).combined(with: .opacity),
                           removal: .offset(x: -travel).combined(with: .opacity))
    }
}

struct FormRowView: View {
    let row: FormRow
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        // Unknown types (and recaptcha if it leaked past the mapper) stay off the stack: even empty, the error row would take a spacing slot.
        let visible = row.fields.filter { field in
            switch field.type {
            case .unknown, .recaptchaV3: return false
            default: return field.isVisible
            }
        }
        if !visible.isEmpty {
            HStack(alignment: .top, spacing: .s) {
                ForEach(visible) { FieldRenderer(field: $0, model: model) }
            }
        }
    }
}

public struct FormNavigationBar: View {
    @ObservedObject private var model: DynamicFormModel
    private let onComplete: (FormSubmitResult) -> Void

    @Environment(\.jackpotTranslate) private var translate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: DynamicFormModel, onComplete: @escaping (FormSubmitResult) -> Void) {
        _model = ObservedObject(wrappedValue: model)
        self.onComplete = onComplete
    }

    public var body: some View {
        if model.form != nil {
            HStack(spacing: .sm) {
                if !model.isFirstSection {
                    Button(translate("previous")) { withAnimation(pagingAnimation) { model.goBack() } }
                        .buttonStyle(.jackpot(.secondary))
                }
                if model.isLastSection {
                    Button(translate("sign-up")) { Task { if let result = await model.submit() { onComplete(result) } } }
                        .buttonStyle(.jackpot)
                        .disabled(!model.isFormValid)
                        .jackpotLoading(model.isSubmitting)
                } else {
                    Button(translate("next")) { withAnimation(pagingAnimation) { model.advance() } }
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
```

At this point the engine renders the captured schema end to end and submits over the bundled
transport. Now the feature that presents it:

**53.** `JackpotKit/Sources/JackpotRegistration/DevConfig.swift`

The `appsettings` app-data section. The host injects the decoded slice; this package maps
`devConfig` into `PasswordSuggestions.Config` (`regionPasswordSuggestions` first, then `passwordLength`).

```swift
import Foundation
import JackpotForms

public struct AppSettings: Codable, Equatable, Sendable {
    public var devConfig: DevConfig?

    public init(devConfig: DevConfig? = nil) {
        self.devConfig = devConfig
    }
}

public struct DevConfig: Codable, Equatable, Sendable {
    public var passwordReg: PasswordStrength?
    public var regionPasswordSuggestions: [PasswordSuggestion]?
    public var passwordLength: PasswordLength?
    public var passwordRegex: String?

    public init(passwordReg: PasswordStrength? = nil,
                regionPasswordSuggestions: [PasswordSuggestion]? = nil,
                passwordLength: PasswordLength? = nil,
                passwordRegex: String? = nil) {
        self.passwordReg = passwordReg
        self.regionPasswordSuggestions = regionPasswordSuggestions
        self.passwordLength = passwordLength
        self.passwordRegex = passwordRegex
    }
}

public struct PasswordStrength: Codable, Equatable, Sendable {
    public var medium: String?
    public var strong: String?

    public init(medium: String? = nil, strong: String? = nil) {
        self.medium = medium
        self.strong = strong
    }
}

public struct PasswordLength: Codable, Equatable, Sendable {
    public var minimum: Int?
    public var maximum: Int?

    public init(minimum: Int? = nil, maximum: Int? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct PasswordSuggestion: Codable, Equatable, Sendable {
    public var min: Int?
    public var max: Int?
    public var vulnerable: Bool?
    public var spaces: Bool?
    public var required: [PasswordCharacterClass]?

    public init(min: Int? = nil,
                max: Int? = nil,
                vulnerable: Bool? = nil,
                spaces: Bool? = nil,
                required: [PasswordCharacterClass]? = nil) {
        self.min = min
        self.max = max
        self.vulnerable = vulnerable
        self.spaces = spaces
        self.required = required
    }
}

public extension PasswordSuggestions.Config {
    init(_ dev: DevConfig?) {
        if let suggestions = dev?.regionPasswordSuggestions, !suggestions.isEmpty {
            self.init(
                min: suggestions.compactMap(\.min).first,
                max: suggestions.compactMap(\.max).first,
                vulnerable: suggestions.contains { $0.vulnerable == true },
                spaces: suggestions.contains { $0.spaces == true },
                required: Set(suggestions.flatMap { $0.required ?? [] })
            )
        } else {
            self.init(
                min: dev?.passwordLength?.minimum,
                max: dev?.passwordLength?.maximum,
                vulnerable: false,
                spaces: false,
                required: []
            )
        }
    }
}
```

**54.** `JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift`

`.bundled()` is the whole demo path: the bundled forms composition plus the captured
`devConfig`, so the password checklist is driven by the same mapping production uses.
`RegistrationDependencies` applies `applyingRegistrationRules()` — the ID-type link, the
18-year date cap, and `passwordConfig` from injected `AppSettings` — to whatever `forms` it is given.
`RegistrationView` is the Sign Up sheet: it owns the `DynamicFormModel`, puts
`DynamicFormContent` inside `JackpotPanel`, and fills the footer with the login row and
`FormNavigationBar`, with `onClose` for the header, `onLogin` for the row and `onComplete`
for the `RegistrationResult` the submit returns. Shell copy (`sign-up`, `login`,
`already-have-account`) goes through `translate`; `jackpotTranslate` is seeded from the
same closure so the bar and pages look keys up without threading it through every initialiser.

```swift
import SwiftUI
import JackpotUI
import JackpotForms

public typealias RegistrationResult = FormSubmitResult

public struct RegistrationDependencies {
    public let forms: FormDependencies
    public let theme: JackpotTheme

    public init(forms: FormDependencies, theme: JackpotTheme = .jackpotCity, appSettings: AppSettings? = nil) {
        self.forms = forms.applyingRegistrationRules(devConfig: appSettings?.devConfig)
        self.theme = theme
    }

    /// The sheet on the bundled payloads — the composition the app uses, with the transport served
    /// from disk. `devConfig` mirrors the captured `appsettings` slice the host injects in production.
    public static func bundled() -> RegistrationDependencies {
        RegistrationDependencies(
            forms: .bundled(),
            appSettings: AppSettings(devConfig: DevConfig(regionPasswordSuggestions: [
                PasswordSuggestion(min: 8),
                PasswordSuggestion(max: 20),
                PasswordSuggestion(vulnerable: true),
            ]))
        )
    }
}

extension FormDependencies {
    func applyingRegistrationRules(now: Date = Date(), devConfig: DevConfig? = nil) -> FormDependencies {
        var rules = self
        rules.regexDependencies = ["idNumber": "idNumberType"]
        rules.maximumDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: -18, to: now)
        if let devConfig {
            rules.passwordConfig = .init(devConfig)
        }
        return rules
    }
}

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
        JackpotPanel(model.translate("sign-up"), onClose: onClose) {
            DynamicFormContent(model: model)
        } footer: {
            VStack(spacing: .sm) {
                JackpotLinkRow(model.translate("already-have-account"),
                               link: model.translate("login"),
                               action: onLogin)
                FormNavigationBar(model: model, onComplete: onComplete)
            }
        }
        .jackpotTheme(theme)
        .environment(\.jackpotTranslate, model.translate)
        .task { await model.load() }
    }
}
```

**55.** `JackpotKit/Sources/JackpotRegistration/RegistrationPanelController.swift`

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

**56.** `JackpotKit/Sources/JackpotRegistration/Previews.swift`

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotForms

struct RegistrationView_Previews: PreviewProvider {
    private struct Page: View {
        var dependencies: RegistrationDependencies = .bundled()
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
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

---

### ▶ Create PR — JackpotForms + JackpotRegistration, on the bundled payloads

Open `JackpotRegistration/Previews.swift` and resume **Sign Up — dark**: the whole flow,
both pages, and — by entering `0000000000000` as the ID number — the CRM's rejection, with
no app and no backend. The submit that succeeds and the submit that fails both go through
`RemoteFormRepository`, so what you are reviewing is the shipping path.

---

## Step 4 — Replace the flow in the app

No package change: registration is already composed against the real client, so going live is
one swap of the transport at the composition root — `.bundled()` becomes `.live(...)`, and
`URLSessionHTTPClient` is the default. The host injects the registration JSON, `appSettings`
and `translate` from the bootstrap payload it already fetched into `GlobalData` — JackpotKit
does not fetch app-data, devConfig or the form schema. The only new request is submit (plus
recaptcha). After step 6 the same blobs come from `AppDataResponse` that *replaced* the
GlobalData load, not a second GET. `recaptcha` is a closure over a `RecaptchaClient` the
composition root created with `Recaptcha.fetchClient(withSiteKey:)` — RecaptchaEnterprise is an
app-target dependency, not JackpotKit's. Throw to fail the submit; return nil to post without a
token.

**In Xcode:** File → Add Package Dependencies → Add Local… → `JackpotKit`, then add
**JackpotRegistration** to the app target's frameworks.

**57.** `Sources/Features/Registration/RegistrationPresenter.swift`

`.live` posts submit; the schema, copy and password rules are injected from the bootstrap
the app already loaded. The only difference from `.bundled()` is which `HTTPClient` is under it,
so `.bundled()` remains the build without a backend.

```swift
import UIKit
import JackpotRegistration
import JackpotForms

extension MainViewController {

    func presentRegistration(recaptchaClient: RecaptchaClient) throws {
        let controller = RegistrationPanelController(
            dependencies: RegistrationDependencies(
                forms: try .live(
                    formJSON: registrationJSON,   // already on config — do not GET /cron/forms
                    baseURL: URL(string: "https://config.jpc.africa")!,
                    translate: { getTranslation(Key: $0) },
                    recaptcha: { action in
                        try await recaptchaClient.execute(withAction: RecaptchaAction(customAction: action))
                    }
                ),
                appSettings: appSettings          // already on config — do not GET /cron/app-data
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

**58.** Point every existing entry point at `presentRegistration()`:

- the header **SIGN UP** button
- the bottom bar **Sign Up** item
- `NavigationHandler` — the `registration` sitemap branch
- the Login panel's **Sign Up ›** link

**59.** Delete:

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

**60.**

```bash
grep -rn "registrationPopup\|flowOneViewController\|flowTwoViewController" --include=*.swift .
```

Expect no results.

---

### ▶ Create PR — live registration in the app

Build and run. Open sign-up from the header and the bottom bar; complete both pages.
Every label reads as it did — that is `getTranslation` plugged straight in.

---

## Step 5 — Fix translations

[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md) phase 2.
`Translations` is the session's table, normalised once at construction instead of on every
lookup; `TranslationsStore` owns it for the session. `getTranslation` becomes a shim over the
store, which fixes the per-lookup rebuild for the whole app with no call-site changes —
registration included, since it only ever held the function.

**61.**

```bash
mkdir -p JackpotKit/Sources/JackpotLocalization
```

**62.** `JackpotKit/Package.swift` — the whole file after this step

`JackpotLocalization` arrives with no dependencies; nothing depends on it until step 6.

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
            targets: ["JackpotUI", "JackpotNetworking", "JackpotForms",
                      "JackpotRegistration", "JackpotLocalization"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),

        .target(name: "JackpotLocalization", swiftSettings: strict),
    ]
)
```

**63.** `JackpotKit/Sources/JackpotLocalization/Translations.swift`

Keys are tried region-suffixed first (`terms-jza` before `terms`), and a miss returns the
key, the same contract as `getTranslation` — which is what lets `translations(_:)` stand
in for it.

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
}
```

**64.** `JackpotKit/Sources/JackpotLocalization/TranslationsRepository.swift`

The protocol and the fixed-table stub. Do not fetch app-data to fill it — `adopt` the
`locales` the host already has. `RemoteTranslationsRepository` is only the replacement for
the existing bootstrap GET, never a second one.

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

**65.** `JackpotKit/Sources/JackpotLocalization/TranslationsStore.swift`

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

**66.** `the app` — two changes and a non-change

```swift
// 1. The store is created once, at the composition root, and injected.
let translations = TranslationsStore(repository: StubTranslationsRepository(Translations()))
translations.adopt(Translations(locales, regionCode: region))  // already on the bootstrap payload

// 2. The legacy helper becomes a shim. `regional` is passed through as given, so existing
//    call sites return byte-identical strings; the deprecation is the burn-down list.
@available(*, deprecated, message: "Inject TranslationsStore; call translations(key)")
@MainActor
func getTranslation(Key: String, regional: Bool = false) -> String {
    AppContainer.shared.translations.translations(Key, regional: regional)
}

// 3. Registration needs no change: the closure it was given at step 4 now reads the store.
forms: try .live(formJSON: registrationJSON, baseURL: configURL,
                 translate: { translations.translations($0) },
                 recaptcha: { action in
                     try await recaptchaClient.execute(withAction: RecaptchaAction(customAction: action))
                 })
```

---

### ▶ Create PR — translations

Every label and error reads as before; the table is built once instead of per lookup.

---

## Step 6 — Fix app data

[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md) phase 1 and
[LAUNCH-PERFORMANCE](LAUNCH-PERFORMANCE.md). `AppDataResponse` splits the bootstrap payload
by top-level key so one null section cannot lose the other five; `FileAppDataCache` keeps the
last good payload; `AppDataLoader` serves it at zero latency and revalidates behind it;
`RemoteTranslationsRepository` exists only as the replacement for that GET, never beside it.
`DevConfig` lives on `JackpotRegistration`; the host injects `appsettings` from the snapshot.
Registration does not fetch app-data.

**67.**

```bash
mkdir -p JackpotKit/Sources/JackpotAppData
```

**68.** `JackpotKit/Package.swift` — the whole file after this step

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
            targets: ["JackpotUI", "JackpotNetworking", "JackpotForms",
                      "JackpotRegistration", "JackpotLocalization", "JackpotAppData"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),

        .target(name: "JackpotNetworking", swiftSettings: strict),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),

        .target(name: "JackpotLocalization", swiftSettings: strict),

        .target(name: "JackpotAppData", dependencies: ["JackpotNetworking", "JackpotLocalization"], swiftSettings: strict),
    ]
)
```

**69.** `JackpotKit/Sources/JackpotAppData/AppData.swift`

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

    public func data(for key: String) -> Data? { sections[key] }

    public var locales: [String: String] {
        section("locales") ?? [:]
    }
}

public enum AppDataError: Error, Equatable {
    case notAnObject
    case noPayload
}
```

**70.** `JackpotKit/Sources/JackpotAppData/AppDataCache.swift`

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

**71.** `JackpotKit/Sources/JackpotAppData/AppDataLoader.swift`

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

        let result = try await apiClient.revalidate(
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

**72.** `JackpotKit/Sources/JackpotAppData/RemoteTranslationsRepository.swift`

```swift
import Foundation
import JackpotNetworking
import JackpotLocalization

/// Adopt locales from a bootstrap payload the app already has. Do not fetch app-data a second time.
public struct RemoteTranslationsRepository: TranslationsRepository {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) {
        self.apiClient = apiClient
    }

    public func translations(region: String, tenant: String, locale: String) async throws -> Translations {
        let data = try await apiClient.data(for: AppDataRequest(region: region, tenant: tenant, locale: locale))
        return Translations(try AppDataResponse(data: data).locales, regionCode: region)
    }
}
```

**73.** `the app — bootstrap`

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
    appSettings = response.section("appsettings", as: AppSettings.self)
    registrationJSON = response.data(for: "registration")
}
```

---

### ▶ Create PR — app data

Log `AppDataSnapshot.origin` at launch; a low `.cache` rate means `maxStale` is too tight.

---
