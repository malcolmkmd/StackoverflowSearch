# Build Playbook

Create the files in the order given. Run the commands where they appear. Open a PR where
marked. Every code block is the file exactly as it is in the repository.

This playbook covers the **registration** path: `RegistrationView` hosts
`DynamicFormView(formName: .registration)`, which renders either the bundled
`JackpotKit/Sources/JackpotForms/Resources/registration.json` or the live CRM schema at
`config.jpc.africa/cron/forms/jackpotcity/JZA/registration` — the same twelve fields.

`JackpotKit` is one package; each folder under `Sources/` is a module. Registration is
carried by four of them — `JackpotUI` (design system), `JackpotNetworking` (transport),
`JackpotForms` (the schema-driven engine) and `JackpotRegistration` (the feature) — plus
the `Translations` value type from `JackpotLocalization`. `JackpotAppData` and the store half
of `JackpotLocalization` are the app-data follow-up
([ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md)); the manifest
lists them, so copy their files from the repository or drop those two targets until you
need them. They are not covered here.

The floor is iOS 15, the host app's. The whole suite runs in a simulator via
`xcodebuild -scheme JackpotKit-Package` — there is no macOS destination, because `JackpotUI`
imports `UIKit`.

**164 tests** through PR 5.

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

The buttons at the bottom of registration are `FormNavigationBar` in `DynamicFormView.swift`,
which registration places in the panel's footer under the login row. `RegistrationView`
owns a `DynamicFormModel` and composes `DynamicFormContent` (the pages) and
`FormNavigationBar` around it; `DynamicFormView` is the same two stacked, for hosts that
want the bar under the pages. The bundled `registration.json` and the live CRM schema are
the twelve fields above — paging is not a field.

| Visible control | Style | When | Action |
| --- | --- | --- | --- |
| **Next** | `.jackpot` (primary) | Section 1 — not last | `DynamicFormModel.advance()` |
| **Previous** | `.jackpot(.secondary)` | Section 2+ | `goBack()` — values kept |
| **Sign Up** | `.jackpot` (primary) | Last section | `model.submit(onSubmit)` |

`Next` stays **disabled** — the accent fill dimmed to `accentFillDisabled` under
`textPrimary` — until every visible field on the current section validates
(`isCurrentSectionValid`). Tapping it marks the section touched, revalidates, and if valid
increments `sectionIndex`. `Sign Up` stays disabled until `isFormValid`, then
`RegistrationView`'s callback calls `RegistrationService.register`. A progress bar
(`.jackpotBar`) sits above the scroll view when `sections.count > 1`.

### Registration rules and the preview path

1. **Schema.** `JackpotForms/Resources/registration.json`, the CRM's response saved
   verbatim. `BundledForms.all` reads it; `StubFormRepository` serves it.
2. **Mock wiring.** `FormDependencies.mock()` is the stub repository plus the placeholder
   copy table `ComposedKeyLocalizer.jpcRegistration`. `.live(baseURL:)` swaps in
   `RemoteFormRepository`; nothing else changes.
3. **Registration's rules.** The engine ships with no cross-field regex links and no date
   cap. `RegistrationDependencies` adds `regexDependencies: ["idNumberType": "idNumber"]`
   and an 18-years-ago `maximumDate` on top of whatever `forms` the host passes in.
4. **Sandbox.** The app's `SearchView` presents `RegistrationSandbox` with `.jackpotPopup`,
   the way the app presents its panels; the sandbox hosts `RegistrationView(dependencies:
   .mock())` and shows the `RegistrationResult` it gets back, so the whole panel runs on a
   device with no backend.
5. **Previews.** `FormPreview.registration` decodes the bundled JSON through the real mapper
   for the seeded-model previews in `DynamicFormView.swift` and each field view.
   `JackpotPreviewPanel.swift` is the component gallery.
6. **The sheet.** `RegistrationView` is the form inside `JackpotPanel`: title and close
   button on `surface`, the pages on `background`, and in the footer band `JackpotLinkRow`
   with `FormNavigationBar` beneath it.
   **Sign Up — dark / light** in `JackpotRegistration/Previews.swift` and **Sheet shell** in
   the gallery render it in both appearances.

---

## PR 1 — JackpotUI

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
mkdir -p JackpotKit/Tests/JackpotUITests
cd JackpotKit
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

**2.** `JackpotKit/Package.swift`

The whole manifest, once. Later PRs add files to targets it already declares, so it
never changes again in this playbook. Every target opts into strict concurrency
checking to match the app's `SWIFT_STRICT_CONCURRENCY = complete`.

```swift
// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module.
//
// In Xcode: File → Add Package Dependencies → Add Local… → JackpotKit, then add the product you
// need to the app target. `JackpotRegistration` is the registration feature, `JackpotForms` the
// schema-driven engine it runs on, `JackpotUI` the design system.
//
// `JackpotAppData` and the store half of `JackpotLocalization` are the app-data follow-up
// (docs/adr/0001); registration does not depend on either.
//
// The floor is iOS 15, the host app's. That is why the models are `ObservableObject` and why
// a few views carry an `#available(iOS 16.0, *)` branch.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotNetworking", "JackpotLocalization", "JackpotAppData",
                      "JackpotForms", "JackpotRegistration"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),
        .testTarget(name: "JackpotUITests", dependencies: ["JackpotUI"]),

        .target(name: "JackpotNetworking", swiftSettings: strict),
        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),

        .target(name: "JackpotLocalization", swiftSettings: strict),
        .testTarget(name: "JackpotLocalizationTests", dependencies: ["JackpotLocalization"]),

        .target(
            name: "JackpotAppData",
            dependencies: ["JackpotNetworking", "JackpotLocalization"],
            swiftSettings: strict
        ),
        .testTarget(name: "JackpotAppDataTests", dependencies: ["JackpotAppData", "JackpotNetworking"]),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking", "JackpotLocalization"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .testTarget(
            name: "JackpotFormsTests",
            dependencies: ["JackpotForms", "JackpotNetworking", "JackpotLocalization"]
        ),

        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),
        .testTarget(name: "JackpotRegistrationTests", dependencies: ["JackpotRegistration", "JackpotForms"]),
    ]
)
```

**3.** `JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift`

Adaptive light/dark palette. Hexes are the locked token table above; `Palette.emphasis`
is the shared #E1E1E5 so focused border and dark text are one value, not aliases.

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
    /// The base layer: what screens and components draw on, and what a control resting on a
    /// `surface` band is filled with — a panel's close button, the "Already have an account?" row.
    public var background = Palette.background
    /// The raised layer: a sheet's header and footer bands, a presented picker.
    public var surface = Palette.surface

    /// Field fill. Shares `surface`'s pair today; its own role so a theme can separate them.
    public var fieldBackground = Palette.surface
    public var fieldBorder = Palette.fieldBorder
    /// The brand blue in both appearances, so the ring is visible on the light field fill too.
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

/// Held as shared constants rather than inline literals so two separately built `JackpotColors`
/// still compare equal — a dynamic `Color` compares by identity.
///
/// Same hex is one entry. A role gets its own name when it can diverge from the others on its
/// pair: `surface` and `fieldBackground` are both `Palette.surface` today, but a theme may want a
/// field to stand out on the shell. Roles that never diverge (`link` / selected shell =
/// `accent`, track / divider = `fieldBorder`) are not given a second name.
enum Palette {
    /// #FFFFFF / #131316. The base layer: screens and components draw on it, and controls on a
    /// `surface` band fill with it. (Android names it `formBackground`, after its first
    /// consumer; the role is wider than that.)
    static let background = Color.adaptive(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x131316))

    /// #F0F0F2 / #202126. The raised layer: the sheet shell — the Sign Up header band with its
    /// close button, the footer band, a presented picker — and, on the same pair, the field
    /// fill and the checklist. (Android `surface`.)
    static let surface = Color.adaptive(light: Color(hex: 0xF0F0F2), dark: Color(hex: 0x202126))

    /// #E1E2E6 / #3E3E48. Hairline, progress track, divider, secondary button.
    static let fieldBorder = Color.adaptive(light: Color(hex: 0xE1E2E6), dark: Color(hex: 0x3E3E48))

    /// #E1E1E5. Android's dark-mode text / icon value; it once served as the focused border too,
    /// but at 1.1:1 on the light field fill that ring was invisible, so focus now uses
    /// `accentFill`. Light-mode paste also dumped body copy, `primary`, `onPrimary` and `link`
    /// here — unreadable on #F0F0F2, so light text uses its own values.
    static let emphasis = Color(hex: 0xE1E1E5)

    /// #2F2F37 / #E1E1E5. Android `titleText` (Text Priority); dark body shares `emphasis`.
    static let textPrimary = Color.adaptive(light: Color(hex: 0x2F2F37), dark: emphasis)

    /// #565A63 / #E1E1E5. Labels and placeholders. Light keeps the existing readable gray —
    /// Android's #E1E1E5 body/label/placeholder is 1.15:1 on the field fill.
    static let textSecondary = Color.adaptive(light: Color(hex: 0x565A63), dark: emphasis)

    /// Sits on `accentFill`, never on the surface, so it does not invert. Android `onPrimary`
    /// was #E1E1E5 on a #E1E1E5 fill — an unfinished placeholder.
    static let textOnAccent = Color.white

    /// Accent as *text* and tint: the raised label of a focused field, ticked boxes, checklist
    /// ticks and the system tint. This is the Android `link` role; the token is not named
    /// `link`. Light #E1E1E5 is unreadable, so the isolated brand blue stays. Dark stays the
    /// lighter blue so a ticked state does not collapse into `textSecondary` (both would
    /// otherwise be #E1E1E5).
    static let accent = Color.adaptive(light: Color(hex: 0x0060EC), dark: Color(hex: 0x4D8FFF))

    /// #0060EC. Carries `textOnAccent` at 5.4:1 in both appearances. Android `primary` was
    /// the same unfinished #E1E1E5 as `onPrimary`.
    static let accentFill = Color(hex: 0x0060EC)

    /// #D4E4F8 / #262B3B. How the app draws Next until the section validates: pale blue in
    /// light, a muted slate in dark. Not the accent at an opacity — over the dark page that
    /// lands on a saturated navy the app never shows. Both values are read from screenshots;
    /// replace them with the Android pair.
    static let accentFillDisabled = Color.adaptive(light: Color(hex: 0xD4E4F8), dark: Color(hex: 0x262B3B))

    /// Brand error #DF0000. Dark lightens to #FF6B6B so captions still clear 4.5:1 on
    /// #131316 / #202126 — #DF0000 itself reads at ~3.2:1 there.
    static let error = Color.adaptive(light: Color(hex: 0xDF0000), dark: Color(hex: 0xFF6B6B))

    /// Not in the Android dialog paste; the checklist still needs both states.
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

    /// Resolves against the trait collection, so one palette serves both appearances and
    /// honours a `preferredColorScheme` override anywhere in the hierarchy.
    static func adaptive(light: Color, dark: Color) -> Color {
        let light = UIColor(light)
        let dark = UIColor(dark)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Spacing

/// Layout scale for gaps, insets, and corner radii. Component sizes that are not
/// spacing (control height, hit targets) live on `JackpotSizes`.
///
/// Cases are `CGFloat`-backed so SwiftUI overloads can take `.sm` like a native inset.
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
    /// The shell a feature is presented in (`JackpotPanel`).
    public var panelCornerRadius: CGFloat = JackpotSpacing.lm.rawValue

    public static let standard = JackpotSizes()

    public var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Typography

public struct JackpotTypography: Equatable, Sendable {
    /// A panel's title: Sign Up.
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

// What travels through the environment is what genuinely cascades: the theme, a button's
// loading state, and the shared focus value a group of fields coordinates on. Per-field data
// (label, kind, prefix) is an initialiser argument on the field itself.

extension EnvironmentValues {
    @Entry public var jackpotTheme: JackpotTheme = .jackpotCity
    @Entry public var jackpotIsLoading: Bool = false
    @Entry public var jackpotFocusedField: Binding<String?>? = nil
    @Entry public var jackpotFieldIdentity: String? = nil

    /// Set by `jackpotFieldError(_:)` and read by the field chrome, so the invalid ring and the
    /// message under the control always agree.
    @Entry var jackpotFieldError: String? = nil
}

// MARK: - Theme

public extension View {
    /// Sets `tint` alongside the theme, so system controls (pickers, toggles) inherit the brand
    /// accent without every call site remembering to.
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
    /// Shares one "which field is focused" value across a group of fields so the return key
    /// can walk them. Tag each field with `jackpotFieldIdentity(_:)`.
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
        /// Filled with the accent: Next, Sign Up, Retry, Done. Disabled, the fill dims to
        /// `accentFillDisabled` under `textPrimary`, so the button still reads as the way forward.
        case primary
        /// Background fill with a hairline: Previous.
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

/// A tappable box with a wrapping label, the way the registration consents are drawn.
/// VoiceOver is handed a switch, so it reads as a toggle rather than a button.
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
            .accessibilityRepresentation {
                // The explicit style stops the stand-in resolving back to this one.
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

/// `TextInputAutocapitalization` is neither `Equatable` nor inspectable, so the kind stores its
/// own case and converts when applying.
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

/// Keyboard, autofill, autocorrection and secure-entry settings as one value, so a field's
/// semantics are declared once — `JackpotTextField("Email", text: $email, kind: .email)` —
/// instead of as four loose modifiers per call site.
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

    /// `.newPassword`, not `.password`: it opts the field into iOS's strong-password suggestion,
    /// which is what a registration form wants.
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
    /// Applies the kind's keyboard and autofill settings. Secure entry is the field's own
    /// business, because it decides between `SecureField` and `TextField`.
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

    /// - Parameters:
    ///   - title: the in-field label. It floats to the top edge on focus or once there is text.
    ///   - kind: keyboard, autofill and secure-entry semantics.
    ///   - prefix: a fixed cell before the input, like `+27` on a mobile number.
    ///   - suffix: trailing text inside the field.
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
                    // The prefix cell is hidden above, so fold it in rather than leaving
                    // VoiceOver to stumble over a stray "+27".
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
        // The other half of the sync: the form moves the shared value, the field follows.
        // Guarded both ways so the two `onChange`s cannot ping-pong.
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

    /// - Parameter title: the in-field label. It floats to the top edge once an option is chosen.
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

    /// - Parameter title: the in-field label. It floats once a date is chosen and names the
    ///   picker sheet.
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

    /// Wheel plus title and button. Before iOS 16 there are no detents, so the sheet is full
    /// height and the spacer pins the button to the bottom instead.
    private var sheetHeight: CGFloat { wheelHeight + 160 }

    private var wheelHeight: CGFloat { 216 }

    private var sheet: some View {
        ZStack {
            // A presented sheet is a shell, so it draws on `surface` like a header band would.
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
                    // Confirming without dragging still counts as a choice, otherwise the
                    // field silently stays empty.
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
            // The chevron follows the tint, which the theme points at the accent colour.
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

    /// Adds the retry button. Without it the view is message-only.
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

/// A prompt with a link at its trailing edge, filled with `background` so it rests on a
/// `surface` band: "Already have an account? Login ›" under the Sign Up sheet, and its mirror
/// under Login.
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

**17.** `JackpotKit/Sources/JackpotUI/Components/JackpotPopup.swift`

`.jackpotPopup(isPresented:)` presents a panel the way the app does: over the page, which
dims behind a `background` scrim, inset and pinned to the top. Not a system sheet.

```swift
import SwiftUI

public extension View {
    /// Presents `panel` the way the app presents Sign Up and Login: over this view, which dims
    /// behind a scrim, inset from the edges and pinned below the host's header. Not a system
    /// sheet — there is no grabber and no drag to dismiss; the panel's own close button ends it.
    ///
    ///     page.jackpotPopup(isPresented: $showsSignUp, topInset: headerHeight) {
    ///         RegistrationView(dependencies: deps, onClose: { showsSignUp = false }, …)
    ///     }
    ///
    /// - Parameter topInset: how far below the top of this view the panel starts, so a page
    ///   header stays visible, dimmed, above it. Defaults to the standard inset.
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
                        // `background` at 60%: a white wash over the light page, a darkening of
                        // the dark one — the same dimming the app applies behind its panels.
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

**18.** `JackpotKit/Sources/JackpotUI/Components/JackpotPanel.swift`

The shell registration is presented in: the header and footer bands on `surface`, the
close button and the content on `background`. Resume **Sheet shell** in the gallery to see
the layers.

```swift
import SwiftUI

/// The shell a feature is presented in: a header band with a title and a close button, the
/// content on `background`, and an optional footer band. Header and footer draw on `surface`,
/// which is what separates them from the content between them; the close button rests on the
/// band in `background`.
///
///     JackpotPanel("Sign Up", onClose: dismiss) {
///         RegistrationView(dependencies: deps) { result in … }
///     } footer: {
///         Button("Already have an account? Login") { showLogin() }
///     }
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

**19.** `JackpotKit/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift`

The panel wraps a preview in the themed surface. Resume **Gallery** for every registration
component in one place.

```swift
import SwiftUI

/// A themed surface at phone width for previewing one component or a small group.
public struct JackpotPreviewPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            if let title {
                Text(title).font(.caption).jackpotForegroundStyle(\.textSecondary)
            }
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

    /// The shell registration is presented in, as the app shows it: title and close button on
    /// `surface`, fields on `background`, the login footer on `surface` again.
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

**20.** `JackpotKit/Tests/JackpotUITests/JackpotThemeTests.swift`

```swift
import SwiftUI
import XCTest
@testable import JackpotUI

final class JackpotThemeTests: XCTestCase {
    func testBrandThemeComposesTheStandardPresets() {
        XCTAssertEqual(JackpotTheme.jackpotCity.colors, .jackpotCity)
        XCTAssertEqual(JackpotTheme.jackpotCity.sizes, .standard)
        XCTAssertEqual(JackpotTheme.jackpotCity.typography, .standard)
    }

    func testWithReturnsACopyAndLeavesTheOriginalAlone() {
        let brand = JackpotTheme.jackpotCity
        let roomy = brand.with { $0.sizes.cornerRadius = JackpotSpacing.l.rawValue }

        XCTAssertEqual(roomy.sizes.cornerRadius, JackpotSpacing.l.rawValue)
        XCTAssertEqual(brand.sizes.cornerRadius, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(roomy.colors, brand.colors, "An unrelated slice should carry over untouched")
    }

    func testFieldShapeFollowsCornerRadius() {
        let theme = JackpotTheme.jackpotCity.with { $0.sizes.cornerRadius = JackpotSpacing.xxs.rawValue }
        XCTAssertEqual(theme.sizes.fieldShape.cornerSize, CGSize(width: JackpotSpacing.xxs.rawValue, height: JackpotSpacing.xxs.rawValue))
        XCTAssertEqual(theme.sizes.fieldShape.style, .continuous)
    }
}

final class JackpotSpacingTests: XCTestCase {
    func testScaleMatchesTheLockedLadder() {
        XCTAssertEqual(JackpotSpacing.xxs.rawValue, 4)
        XCTAssertEqual(JackpotSpacing.xs.rawValue, 6)
        XCTAssertEqual(JackpotSpacing.s.rawValue, 8)
        XCTAssertEqual(JackpotSpacing.sm.rawValue, 12)
        XCTAssertEqual(JackpotSpacing.m.rawValue, 16)
        XCTAssertEqual(JackpotSpacing.lm.rawValue, 20)
        XCTAssertEqual(JackpotSpacing.l.rawValue, 24)
        XCTAssertEqual(JackpotSpacing.xl.rawValue, 32)
        XCTAssertEqual(JackpotSpacing.xxl.rawValue, 40)
        XCTAssertEqual(JackpotSpacing.xxxl.rawValue, 48)
    }

    func testStandardSizesReadSpacingForGapsAndRadii() {
        let sizes = JackpotSizes.standard
        XCTAssertEqual(sizes.cornerRadius, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(sizes.spacing, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(sizes.contentPadding, JackpotSpacing.m.rawValue)
        XCTAssertEqual(sizes.progressBarHeight, JackpotSpacing.xxs.rawValue)
        XCTAssertEqual(sizes.panelCornerRadius, JackpotSpacing.lm.rawValue)
        XCTAssertEqual(sizes.fieldShape.cornerSize, CGSize(width: JackpotSpacing.sm.rawValue, height: JackpotSpacing.sm.rawValue))
    }

    func testSwiftUIOverlaysAcceptSpacingCases() {
        _ = EmptyView().padding(.sm)
        _ = EmptyView().padding(.horizontal, .m)
        _ = EmptyView().padding([.horizontal, .bottom], .l)
        _ = EmptyView().frame(width: .l, height: .l)
        _ = VStack(spacing: .sm) { EmptyView() }
        _ = HStack(alignment: .top, spacing: .xs) { EmptyView() }
        XCTAssertEqual(EdgeInsets(.sm).top, JackpotSpacing.sm.rawValue)
        XCTAssertEqual(EdgeInsets(.sm).leading, JackpotSpacing.sm.rawValue)
    }
}

final class JackpotColorSchemeTests: XCTestCase {
    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    func testSurfaceAndTextInvertBetweenAppearances() {
        let colors = JackpotColors.jackpotCity
        for keyPath in [\JackpotColors.background, \.surface, \.fieldBackground, \.textPrimary, \.textSecondary] {
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

    /// The focus ring is the brand blue in both appearances: #E1E1E5 was 1.1:1 on the light
    /// field fill, so focus was carried by border width alone.
    func testFocusedBorderIsTheBrandBlueInBothAppearances() {
        let color = JackpotColors.jackpotCity.fieldBorderFocused
        XCTAssertEqual(hex(color, light), 0x0060EC)
        XCTAssertEqual(hex(color, dark), 0x0060EC)
    }

    func testLockedTokenHexes() {
        let colors = JackpotColors.jackpotCity
        let expected: [(KeyPath<JackpotColors, Color>, UInt32, UInt32)] = [
            (\.background, 0xFFFFFF, 0x131316),
            (\.surface, 0xF0F0F2, 0x202126),
            (\.fieldBackground, 0xF0F0F2, 0x202126),
            (\.fieldBorder, 0xE1E2E6, 0x3E3E48),
            (\.fieldBorderFocused, 0x0060EC, 0x0060EC),
            (\.textPrimary, 0x2F2F37, 0xE1E1E5),
            (\.textSecondary, 0x565A63, 0xE1E1E5),
            (\.textOnAccent, 0xFFFFFF, 0xFFFFFF),
            (\.accent, 0x0060EC, 0x4D8FFF),
            (\.accentFill, 0x0060EC, 0x0060EC),
            (\.accentFillDisabled, 0xD4E4F8, 0x262B3B),
            (\.error, 0xDF0000, 0xFF6B6B),
            (\.warning, 0x945C05, 0xF59E21),
            (\.success, 0x0F7542, 0x33B870),
        ]
        for (keyPath, lightHex, darkHex) in expected {
            XCTAssertEqual(hex(colors[keyPath: keyPath], light), lightHex, "\(keyPath) light")
            XCTAssertEqual(hex(colors[keyPath: keyPath], dark), darkHex, "\(keyPath) dark")
        }
        XCTAssertEqual(hex(colors.fieldBorderInvalid, light), hex(colors.error, light))
        XCTAssertEqual(hex(colors.fieldBorderInvalid, dark), hex(colors.error, dark))
    }

    /// Text has to clear 4.5:1 on *every* background it can land on, not just `surface`.
    func testTextClearsWCAGContrastOnEveryBackgroundItLandsOn() {
        let colors = JackpotColors.jackpotCity
        let backgrounds: [(String, KeyPath<JackpotColors, Color>)] = [
            ("background", \.background),
            ("surface", \.surface),
            ("fieldBackground", \.fieldBackground),
        ]
        let foregrounds: [(String, KeyPath<JackpotColors, Color>)] = [
            ("textPrimary", \.textPrimary),
            ("textSecondary", \.textSecondary),
            ("accent", \.accent),
            ("error", \.error),
            ("warning", \.warning),
            ("success", \.success),
        ]

        for traits in [light, dark] {
            for (bgName, bg) in backgrounds {
                let background = resolve(colors[keyPath: bg], traits)
                for (fgName, fg) in foregrounds {
                    let text = flatten(resolve(colors[keyPath: fg], traits), over: background)
                    // #DF0000 on #F0F0F2 is 4.46:1 — the locked brand red, just under 4.5.
                    let floor: CGFloat = (fgName == "error" && bgName != "background"
                                          && traits.userInterfaceStyle == .light) ? 4.4 : 4.5
                    XCTAssertGreaterThanOrEqual(
                        contrastRatio(text, background), floor,
                        "\(fgName) on \(bgName) in \(name(traits)) is unreadable")
                }
            }
        }
    }

    /// The disabled fill sits on `background`; its `textPrimary` label must still be readable.
    func testDisabledPrimaryLabelClearsContrastOnTheDisabledFill() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let page = resolve(colors.background, traits)
            let fill = flatten(resolve(colors.accentFillDisabled, traits), over: page)
            let label = resolve(colors.textPrimary, traits)
            XCTAssertGreaterThanOrEqual(contrastRatio(label, fill), 4.5,
                                        "textPrimary on the dimmed accent in \(name(traits))")
        }
    }

    func testButtonLabelClearsContrastOnItsFill() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let fill = resolve(colors.accentFill, traits)
            let label = flatten(resolve(colors.textOnAccent, traits), over: fill)
            XCTAssertGreaterThanOrEqual(contrastRatio(label, fill), 4.5,
                                        "textOnAccent on accentFill in \(name(traits))")
        }
    }

    /// Fields sit on `background`, so that is the pair the fill has to separate from.
    func testFieldFillIsDistinguishableFromTheBackgroundBehindIt() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            let fill = resolve(colors.fieldBackground, traits)
            let behind = resolve(colors.background, traits)
            XCTAssertNotEqual(fill, behind, "field fill matches the background in \(name(traits))")
            // 1.05, not 3:1 — the locked fills separate by ~1.14, so this pins the
            // regression (fill identical to its background) without overruling the design.
            XCTAssertGreaterThan(contrastRatio(fill, behind), 1.05,
                                 "field fill is too close to the background in \(name(traits))")
        }
    }

    /// The raised layer and the base layer must differ, or a sheet header stops reading as a band.
    func testSurfaceIsDistinguishableFromTheBackground() {
        let colors = JackpotColors.jackpotCity
        for traits in [light, dark] {
            XCTAssertNotEqual(resolve(colors.surface, traits), resolve(colors.background, traits),
                              "surface matches background in \(name(traits))")
        }
    }

    // MARK: Helpers

    private func name(_ traits: UITraitCollection) -> String {
        traits.userInterfaceStyle == .dark ? "dark" : "light"
    }

    private func resolve(_ color: Color, _ traits: UITraitCollection) -> UIColor {
        UIColor(color).resolvedColor(with: traits)
    }

    private func hex(_ color: Color, _ traits: UITraitCollection) -> UInt32 {
        let c = components(resolve(color, traits))
        return UInt32(lround(Double(c.r * 255))) << 16
            | UInt32(lround(Double(c.g * 255))) << 8
            | UInt32(lround(Double(c.b * 255)))
    }

    /// Several palette entries are translucent white. Reading their components straight back
    /// reports the contrast of opaque white, so they have to be composited first.
    private func flatten(_ color: UIColor, over background: UIColor) -> UIColor {
        let fg = components(color), bg = components(background)
        return UIColor(red: fg.r * fg.a + bg.r * (1 - fg.a),
                       green: fg.g * fg.a + bg.g * (1 - fg.a),
                       blue: fg.b * fg.a + bg.b * (1 - fg.a),
                       alpha: 1)
    }

    /// WCAG 2.1 relative luminance.
    private func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let lighter = max(luminance(a), luminance(b))
        let darker = min(luminance(a), luminance(b))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        let c = components(color)
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }
}

final class JackpotFieldKindTests: XCTestCase {
    func testEmailOptsOutOfCapitalisationAndAutocorrection() {
        XCTAssertEqual(JackpotFieldKind.email.keyboard, .emailAddress)
        XCTAssertEqual(JackpotFieldKind.email.contentType, .emailAddress)
        XCTAssertTrue(JackpotFieldKind.email.disablesAutocorrection)
        XCTAssertFalse(JackpotFieldKind.email.isSecure)
    }

    func testNewPasswordIsSecureAndOptsIntoStrongPasswordSuggestions() {
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

**21.**

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotUI

`JackpotUITests: Executed 20 tests, with 0 failures`

Open `JackpotPreviewPanel.swift` and resume the **Gallery** preview in both appearances.

---

## PR 2 — JackpotNetworking + Translations

The transport, and the localisation table the form engine adapts. Both are standalone
modules with nothing above them, so they land before the engine that uses them. 200 / 400 /
401 / 500 are the contract; `unexpectedStatus` carries anything infrastructure returns.

**22.**

```bash
mkdir -p JackpotKit/Sources/{JackpotNetworking,JackpotLocalization}
mkdir -p JackpotKit/Tests/{JackpotNetworkingTests,JackpotLocalizationTests}
```

**23.** `JackpotKit/Sources/JackpotNetworking/HTTPMethod.swift`

```swift
import Foundation

public enum HTTPMethod: String, Sendable {
    case GET, POST, PUT, PATCH, DELETE
}
```

**24.** `JackpotKit/Sources/JackpotNetworking/HTTPClient.swift`

```swift
import Foundation

/// The transport seam. Tests stub this — never the ApiClient itself.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// A wrapper rather than a `URLSession` conformance, so the conformance stays private to
/// this module and configuration has somewhere to live.
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

**25.** `JackpotKit/Sources/JackpotNetworking/APIEnvironment.swift`

```swift
import Foundation

/// Base URL + headers every request in an environment carries. Injected once, so the
/// layer can serve a second host or a staging environment without touching `APIEndpoint`.
public struct APIEnvironment: Sendable {
    public let baseURL: URL
    public let defaultHeaders: [String: String]
    /// Query items appended to every request (api-version, site, locale…).
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

**26.** `JackpotKit/Sources/JackpotNetworking/APIEndpoint.swift`

```swift
import Foundation

public enum RequestBody: Sendable {
    case json(Data)
    case form([String: String])
}

/// One endpoint = one request shape. Knows its own path, method and body;
/// knows nothing about hosts, auth or versioning.
public protocol APIEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: RequestBody? { get }
    /// False for login and token-refresh endpoints, so auth interceptors skip them —
    /// a refresh request must never carry the token it is replacing.
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

**27.** `JackpotKit/Sources/JackpotNetworking/APIError.swift`

```swift
import Foundation

/// The error envelope the API returns with a non-2xx response: `{ "code": 0, "message": "…" }`
///
/// `code` decodes from both number and string forms. Decoding is `try?` at the call site by
/// design — a gateway may return HTML, and that must not throw — so a shape mismatch here
/// would be invisible: no crash, no log, just permanently empty error messages.
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

        // A body carrying neither field is not a problem envelope. Throwing here means the
        // client's `try?` yields nil, so `.badRequest(nil)` reads "the server said nothing"
        // rather than "the server sent an empty complaint".
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

/// What the client concluded happened.
///
/// The API contract is 200, 400, 401, 500. Anything else can still arrive from a proxy,
/// gateway or WAF, so `unexpectedStatus` carries it rather than flattening it into `.server`.
public enum APIError: Error, Sendable, Equatable {
    case invalidURL(String)
    case transport(URLError.Code)
    /// 400 — the request was rejected. `problem.message` is the text to show.
    case badRequest(APIProblem?)
    /// 401 — after any interceptor has had its one chance to refresh and retry.
    case unauthorized(APIProblem?)
    /// 500 — after one retry, if the endpoint was idempotent.
    case server(APIProblem?)
    /// Outside the documented contract. Almost always infrastructure rather than the API.
    case unexpectedStatus(Int, APIProblem?)
    case decoding(String)
    case cancelled

    /// The server's envelope, whichever case carries it.
    public var problem: APIProblem? {
        switch self {
        case .badRequest(let p), .unauthorized(let p), .server(let p), .unexpectedStatus(_, let p):
            return p
        case .invalidURL, .transport, .decoding, .cancelled:
            return nil
        }
    }

    /// The server's own wording, when it sent any. Prefer this over a generic string.
    public var serverMessage: String? {
        problem?.message.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var isOffline: Bool {
        guard case .transport(let code) = self else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut].contains(code)
    }
}
```

**28.** `JackpotKit/Sources/JackpotNetworking/RequestInterceptor.swift`

```swift
import Foundation

/// Where auth headers, token refresh, logging and correlation IDs belong — once,
/// instead of in every API type.
public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest, for endpoint: any APIEndpoint) async throws -> URLRequest
    /// Return an adapted request to retry with, or nil to give up. Called at most once.
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

/// Adds a bearer token. The token arrives through a closure so this module never
/// imports a session type.
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

**29.** `JackpotKit/Sources/JackpotNetworking/ConditionalRequest.swift`

Registration never sends a conditional request; `RemoteApiClient` still implements the
protocol method, so the types have to exist.

```swift
import Foundation

/// The cache validators a response came back with. Sending them back turns a revalidation
/// into a 304 with an empty body — the round trip still happens, but nothing is transferred
/// or decoded.
///
/// `Codable` both ways, and the only type in this layer that is: these are read off the response
/// headers rather than a JSON body, so the conformance exists for `AppDataCaching`, which writes
/// them beside the payload it validates and reads them back on the next launch.
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
    /// 304 — what we already hold is current.
    case notModified
    case fresh(Data, HTTPValidators?)
}
```

**30.** `JackpotKit/Sources/JackpotNetworking/RemoteApiClient.swift`

```swift
import Foundation

public protocol ApiClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response
    /// For 204 / empty-body responses.
    func request(_ endpoint: some APIEndpoint) async throws
    /// The raw bytes, for responses decoded section-by-section rather than into one type.
    func requestData(_ endpoint: some APIEndpoint) async throws -> Data
    /// Revalidates against what the caller already holds. Returns `.notModified` on a 304.
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
            // The full error description names the key path that failed;
            // `localizedDescription` would only say "The data couldn't be read".
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
            // Only reachable when the caller sent conditional headers; `requestConditional`
            // turns this into `.notModified`.
            return (data, response)

        case 401:
            // `didRetryAuth` is a parameter rather than stored state, so a second 401
            // can never loop.
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

        case 500, 502...504:
            // A POST may already have taken effect server-side, so only idempotent requests
            // are retried.
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
        } catch let error as URLError where error.code == .cancelled {
            // What URLSession actually throws when a Task is cancelled mid-flight.
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

**31.** `JackpotKit/Tests/JackpotNetworkingTests/MockHTTPClient.swift`

```swift
import Foundation
import XCTest
@testable import JackpotNetworking

/// Stubs the *transport*, not the client, so these tests exercise real URL building, real status
/// handling and real decoding with only the socket replaced. An actor because the client calls
/// it from concurrent tasks.
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

    init(_ stub: Stub) { self.init([stub], fallback: stub) }

    var requestCount: Int { requests.count }

    /// Asserted inside the actor, so callers don't have to reach across isolation.
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

// MARK: - Fixtures

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

**32.** `JackpotKit/Tests/JackpotNetworkingTests/APIEndpointTests.swift`

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

    /// Environment query items come first, then the endpoint's own — so an endpoint can
    /// never accidentally drop the API version.
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
        XCTAssertTrue(endpoint.isIdempotent)          // derived from .GET
    }

    func testPostIsNotIdempotentByDefault() {
        XCTAssertFalse(CreateWidgetRequest(name: "x").isIdempotent)
    }
}
```

**33.** `JackpotKit/Tests/JackpotNetworkingTests/APIProblemTests.swift`

```swift
import XCTest
@testable import JackpotNetworking

/// The API's envelope is `{ "code": 0, "message": "Error message" }`.
///
/// These matter more than they look: the client decodes problems with `try?` so a gateway's
/// HTML body can't throw. That means a *shape* mismatch is completely silent — no crash, no
/// log, just permanently empty error messages in the UI. These tests are the only thing
/// standing between a backend field rename and that failure.
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

    /// Tolerated so a backend switching to string codes can't silently break every message.
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

    // MARK: Things that are *not* a problem envelope

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

**34.** `JackpotKit/Tests/JackpotNetworkingTests/RemoteApiClientTests.swift`

The retry policy is the part worth asserting: a 5xx or a dropped connection is retried, a
4xx never is, and a non-idempotent request is retried only when the transport failed before
the server could have seen it.

```swift
import XCTest
@testable import JackpotNetworking

final class RemoteApiClientTests: XCTestCase {

    private func client(_ http: MockHTTPClient,
                        interceptors: [any RequestInterceptor] = []) -> RemoteApiClient {
        RemoteApiClient(environment: .test, httpClient: http, interceptors: interceptors)
    }

    // MARK: Success

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

    // MARK: The documented contract — 200, 400, 401, 500

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

    /// `{"code": 0, ...}` is the shape the API actually sends. An earlier `code: String?`
    /// meant this decoded to nil and every error message came back empty — silently,
    /// because problem decoding is `try?` by design.
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

    /// A gateway returning HTML must not throw a decoding error on the way to reporting
    /// the status.
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

    // MARK: Outside the contract — infrastructure, not the API

    func test404IsReportedAsUnexpectedRatherThanFlattenedIntoServer() async {
        let http = MockHTTPClient(.status(404))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(404, nil))
        }
        await http.assertRequests(1)   // a 404 is not retried
    }

    func testGatewayErrorsRetryOnceThenReportTheirRealStatus() async {
        let http = MockHTTPClient([.status(503), .status(503)])
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .unexpectedStatus(503, nil))
        }
        await http.assertRequests(2)
    }

    // MARK: Transport and decoding

    func testMalformedJSONSurfacesAsDecodingWithTheTypeName() async {
        let http = MockHTTPClient(.ok(#"{"id":"not-an-int"}"#))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            guard case .decoding(let message) = error as? APIError else {
                return XCTFail("expected .decoding, got \(error)")
            }
            // DecodingError.localizedDescription is "The data couldn't be read" — useless.
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

    /// URLSession throws `URLError.cancelled`, not `CancellationError`, when a task is
    /// cancelled mid-flight. Miss this and cancelled loads surface to users as failures.
    func testURLErrorCancelledMapsToCancelled() async {
        let http = MockHTTPClient(.failure(URLError(.cancelled)))
        await AssertThrows(try await client(http).request(WidgetRequest()) as Widget) { error in
            XCTAssertEqual(error as? APIError, .cancelled)
        }
    }

    // MARK: Auth retry

    func test401RetriesOnceWithTheRefreshedToken() async throws {
        let http = MockHTTPClient([.status(401), .ok(#"{"id":1,"name":"ok"}"#)])
        let interceptor = StubAuthInterceptor(refreshedToken: "new-token")
        let widget: Widget = try await client(http, interceptors: [interceptor]).request(WidgetRequest())

        XCTAssertEqual(widget.name, "ok")
        await http.assertRequests(2)
        let retried = await http.requests[1]
        XCTAssertEqual(retried.value(forHTTPHeaderField: "Authorization"), "Bearer new-token")
    }

    /// The retry budget is a call-shape parameter, not stored state — so a second 401
    /// can never loop.
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

// MARK: - Helpers

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

**35.** `JackpotKit/Sources/JackpotLocalization/Translations.swift`

The session's localisation table. Two lookups matter: keys are tried region-suffixed first
(`terms-jza` before `terms`), and API error codes are keys too, which is what lets a server
error come back in the user's language. `TranslationsRepository.swift` and
`TranslationsStore.swift` in the same folder are the app-data follow-up.

```swift
import Foundation

/// The app's localisation table, fetched once per session from the app-data endpoint.
///
/// Normalised to lowercase **once**, at construction: one registration form asks for ~36 strings
/// per render pass, and normalising per lookup would mean 36 full dictionary rebuilds to draw
/// one screen.
public struct Translations: Sendable, Equatable {

    private let table: [String: String]
    /// Lowercased region code, e.g. `"jza"`. Nil when the app has no region yet.
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

    /// Looks up `key`, cascading `key-<region>` → `key` → nil.
    ///
    /// Region-first by default: a `-jza` variant only exists because someone wanted it used,
    /// and making it opt-in per call site means the callers that forget show the wrong copy.
    /// Pass `regional: false` to force the plain key.
    public func string(forKey key: String, regional: Bool = true) -> String? {
        let normalized = key.lowercased()
        if regional, let regionSuffix, let regional = table["\(normalized)-\(regionSuffix)"] {
            return regional
        }
        return table[normalized]
    }

    /// Resolved string, falling back to the key itself so a missing translation is visible in
    /// QA rather than rendering as an empty label.
    public func callAsFunction(_ key: String, regional: Bool = true) -> String {
        string(forKey: key, regional: regional) ?? key
    }

    /// The table doubles as an error-code catalogue: the app-data response carries entries
    /// like `"6000328": "Maximum OTP tries reached…"`, so a `code` in an API error envelope
    /// is a localisation key.
    public func message(forErrorCode code: Int) -> String? {
        string(forKey: "jpc-reg-error.\(code)", regional: false)
            ?? string(forKey: String(code), regional: false)
    }
}
```

**36.** `JackpotKit/Tests/JackpotLocalizationTests/TranslationsTests.swift`

```swift
import XCTest
@testable import JackpotLocalization

/// Keys and values below are taken from the real app-data response.
final class TranslationsTests: XCTestCase {

    private let sample = Translations([
        "6000328": "Maximum OTP tries reached, Please contact support on +233 30 825 5838",
        "markets.windrawwin": "1X2",
        "new-site": "New Site",
        "select-password-reset-method": "Select Password Reset Method",
        "jpc-fixed-jackpots-starts-in": "Starts in",
        "city-jackpots": "City Jackpots",
        "receivePromotionalInformation": "Send me promotions",
        "receivePromotionalInformation-jza": "Send Jackpot City Promotions to me",
    ], regionCode: "JZA")

    // MARK: Lookup

    func testResolvesAKey() {
        XCTAssertEqual(sample("new-site"), "New Site")
        XCTAssertEqual(sample("markets.windrawwin"), "1X2")
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(sample("NEW-SITE"), "New Site")
        XCTAssertEqual(sample("New-Site"), "New Site")
    }

    /// A missing key renders as itself — visible in QA, rather than an empty label.
    func testMissingKeyFallsBackToTheKey() {
        XCTAssertEqual(sample("no-such-key"), "no-such-key")
        XCTAssertNil(sample.string(forKey: "no-such-key"))
    }

    // MARK: Region cascade

    func testRegionalVariantWinsWhenItExists() {
        XCTAssertEqual(sample("receivePromotionalInformation"),
                       "Send Jackpot City Promotions to me")
    }

    func testPlainKeyUsedWhenNoRegionalVariantExists() {
        XCTAssertEqual(sample("new-site"), "New Site")
    }

    func testRegionalLookupCanBeForcedOff() {
        XCTAssertEqual(sample("receivePromotionalInformation", regional: false),
                       "Send me promotions")
    }

    /// The CRM sometimes hands us a key that already carries the region suffix — the
    /// registration schema's `fieldLabel` is literally `receivePromotionalInformation-jza`.
    /// Looking that up must not double-suffix into a miss.
    func testAPreSuffixedKeyStillResolves() {
        XCTAssertEqual(sample("receivePromotionalInformation-jza"),
                       "Send Jackpot City Promotions to me")
    }

    func testNoRegionMeansNoRegionalLookup() {
        let noRegion = Translations(["a-jza": "regional", "a": "plain"], regionCode: nil)
        XCTAssertEqual(noRegion("a"), "plain")
        XCTAssertNil(noRegion.regionSuffix)
    }

    func testBlankRegionIsTreatedAsAbsent() {
        XCTAssertNil(Translations(["a": "b"], regionCode: "   ").regionSuffix)
    }

    // MARK: Error codes

    /// The table doubles as an error-code catalogue, which is what ties an API error envelope
    /// (`{"code": 6000328, …}`) to a sentence in the player's language.
    func testErrorCodeResolvesToItsMessage() {
        XCTAssertEqual(sample.message(forErrorCode: 6000328),
                       "Maximum OTP tries reached, Please contact support on +233 30 825 5838")
    }

    func testPrefixedRegistrationErrorCodeResolves() {
        let table = Translations(["jpc-reg-error.153008": "An error occurred"], regionCode: "JZA")
        XCTAssertEqual(table.message(forErrorCode: 153008), "An error occurred")
    }

    func testUnknownErrorCodeIsNil() {
        XCTAssertNil(sample.message(forErrorCode: 999))
    }

    /// A numeric code must never pick up the region suffix — "6000328-jza" isn't a thing.
    func testErrorCodeLookupIgnoresRegion() {
        let table = Translations(["123": "plain", "123-jza": "regional"], regionCode: "JZA")
        XCTAssertEqual(table.message(forErrorCode: 123), "plain")
    }

    /// The app's existing key enums are `String`-backed, so `rawValue` is all the bridge needs.
    func testStringBackedEnumsResolveThroughTheirRawValue() {
        enum FixedJackpotTranslationsKeys: String {
            case startsIn = "jpc-fixed-jackpots-starts-in"
            case cityJackpots = "city-jackpots"
        }
        XCTAssertEqual(sample(FixedJackpotTranslationsKeys.startsIn.rawValue), "Starts in")
        XCTAssertEqual(sample(FixedJackpotTranslationsKeys.cityJackpots.rawValue), "City Jackpots")
    }

    // MARK: Housekeeping

    func testEmptyTable() {
        let empty = Translations()
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty("anything"), "anything")
    }

    /// Lookup must not rebuild the lowercased table each time: 50k lookups against a 2k-row
    /// table finish in well under a second only if normalisation happens once, at init.
    func testLookupIsConstantTimeNotAFullTableRebuild() {
        let big = Translations(
            Dictionary(uniqueKeysWithValues: (0..<2_000).map { ("key-\($0)", "value-\($0)") }),
            regionCode: "jza"
        )
        let started = Date()
        for index in 0..<50_000 {
            _ = big("KEY-\(index % 2_000)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.0)
    }
}
```

**37.**

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotNetworking + Translations

`JackpotNetworkingTests: Executed 34 tests, with 0 failures`
`JackpotLocalizationTests: Executed 16 tests, with 0 failures`

---

## PR 3 — JackpotForms

One module, four folders pointing one way: `Domain` (types and rules, no I/O), `Data`
(wire shapes, the bundled stub), `UI` (the engine and the renderer) and `Remote` (the live
repository and `.live()`). The engine only ever sees `FormRepository`, which is what lets the
stub and the network be swapped at one line in composition. Wire types are `internal`;
nothing outside `Data/` and `Remote/` knows a JSON key name.

**38.**

```bash
mkdir -p JackpotKit/Sources/JackpotForms/{Domain,Data,Remote,UI/Fields,Resources}
mkdir -p JackpotKit/Tests/JackpotFormsTests
```

**39.** `JackpotKit/Sources/JackpotForms/Domain/FormName.swift`

`.registration` is the live form.

```swift
import Foundation

/// Identifies a form in the CRM — the `formCodeName` in the schema, and the last path
/// component of the fetch URL.
///
/// Deliberately not an enum. Forms are authored server-side and new ones appear without an app
/// release, so a closed set would fight the architecture. This is the `Notification.Name`
/// pattern instead: a `RawRepresentable` wrapper with static members for the forms this build
/// knows about, and `FormName("deposit")` for anything else.
///
/// Not `ExpressibleByStringLiteral`, on purpose: `formName: "registraton"` would compile and
/// give a runtime 404. Constructing one from an arbitrary string has to be written out, so
/// `FormName(` stays greppable at review time.
/// Not `Codable`: a form name never crosses a serialisation boundary as itself. Decoding goes
/// `FormDTO.formCodeName` (a `String`) → `FormName(_:)` in the mapper, and encoding goes
/// `FormSubmitBody.formName = submission.formCodeName.rawValue`. Both directions are explicit at
/// the wire type, which is where the JSON key names already live.
public struct FormName: RawRepresentable, Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

// MARK: - Known forms
//
// Add a member here when the CRM starts serving a form you reference by name in code. Forms
// you only ever reach dynamically — from a sitemap, deep link or the forms list endpoint —
// never need one.

public extension FormName {
    /// The two-section sign-up form: credentials + name + email, then FICA.
    static let registration = FormName("registration")
}
```

**40.** `JackpotKit/Sources/JackpotForms/Domain/FormValue.swift`

```swift
import Foundation

/// A field's current value.
///
/// Every case renders as a string because the schema validates with regexes — including the
/// checkboxes, whose patterns are literally `^true$`. `stringValue` is therefore both what
/// gets validated and what gets submitted.
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
        return stringValue.lowercased() == "true"
    }

    public var dateValue: Date? {
        switch self {
        case .date(let d): return d
        case .text(let s): return try? FormValue.iso8601.parse(s)
        default:           return nil
        }
    }

    /// The `dateOfBirth` regex in the schema expects an ISO-8601 date-time with
    /// optional fractional seconds and offset, so that is what we emit: `1990-01-01T00:00:00Z`.
    /// A format style rather than `ISO8601DateFormatter`, which is a class and not `Sendable`.
    public static let iso8601 = Date.ISO8601FormatStyle()
}

/// What the host receives in the submit callback, and what the cron submit endpoint expects.
/// Encoding lives in `Remote/FormEndpoints.swift` so this type stays free of JSON key names.
public struct FormSubmission: Equatable, Sendable {
    public let formId: String
    public let formCodeName: FormName
    public let submittedAt: Date
    public let values: [String: FormValue]
    public let metadata: [String: String]?

    public init(formCodeName: FormName,
                values: [String: FormValue],
                formId: String = "",
                submittedAt: Date = Date(),
                metadata: [String: String]? = nil) {
        self.formId = formId
        self.formCodeName = formCodeName
        self.submittedAt = submittedAt
        self.values = values
        self.metadata = metadata
    }

    public subscript(identifier: String) -> FormValue {
        values[identifier] ?? .empty
    }

    /// Flat string payload, for hosts that want one. The real submit body uses `values`,
    /// because fields are typed on the wire (bool stays bool, empty becomes null).
    public var stringValues: [String: String] {
        values.mapValues(\.stringValue)
    }
}
```

**41.** `JackpotKit/Sources/JackpotForms/Domain/FormField.swift`

`FieldType` is Input, Dropdown and Checkbox — the registration catalog — plus `unknown`,
which is what keeps the form usable when the CRM adds a type this build cannot draw.

```swift
import Foundation

/// What component renders this field.
///
/// `unknown` is load-bearing: the schema is served from a CRM that product edits without
/// shipping an app build, so an unrecognised `fieldType` that threw would brick registration
/// for every installed version. Unknown fields are skipped and reported through
/// `DynamicFormModel.unsupportedFields` instead.
///
/// When the CRM starts serving a type this build should draw, add a case here and a view for it
/// in `FieldRenderer`; that switch is the whole contract.
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
    /// Localisation key for the visible text, e.g. "jpc-reg-SalaryOrWages".
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

public struct FormField: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    /// Key used for state, validation and the submitted payload, e.g. "idNumber".
    public let identifier: String
    /// Localisation key for the in-field label.
    public let labelKey: String
    public let type: FieldType
    public let inputType: InputType
    /// Localisation key for the validation failure message.
    public let validationMessageKey: String
    public let isRequired: Bool
    /// Hidden fields are neither rendered, validated nor submitted.
    public let isVisible: Bool
    public let isReadOnly: Bool
    /// Regex the value must match. Server-supplied, so it may be invalid — see `FieldValidator`.
    public let regex: String?
    public let prefix: String
    public let suffix: String
    public let dropdownOptions: [DropdownOption]

    /// Defaults are the schema's own: an unspecified field is an optional, visible, editable
    /// text input labelled by its identifier.
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

**42.** `JackpotKit/Sources/JackpotForms/Domain/FormSchema.swift`

```swift
import Foundation

/// A whole form as the CRM form-builder describes it. A section is one page of the wizard;
/// fields sharing a row sit side by side.
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

**43.** `JackpotKit/Sources/JackpotForms/Domain/FormSubmitResult.swift`

```swift
import Foundation

/// What `POST /cron/forms/submit` returns on a 2xx body.
///
/// HTTP 200 is not success — the envelope carries `isSuccessful` and an `error` object.
/// A created account can still need manual FICA (`partialRegistrationStatus`, compliance).
public struct FormSubmitResult: Equatable, Sendable {
    public let accountId: String?
    public let message: String?
    public let status: String?
    public let partialRegistrationStatus: Int?
    public let compliance: FormComplianceResult?

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

    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }
}

public struct FormComplianceResult: Equatable, Sendable {
    public let complianceStatus: Int?
    public let requiredComplianceStatus: Int?
    public let isValidId: Bool?
    public let message: String?
    public let accessToken: String?

    public init(complianceStatus: Int? = nil,
                requiredComplianceStatus: Int? = nil,
                isValidId: Bool? = nil,
                message: String? = nil,
                accessToken: String? = nil) {
        self.complianceStatus = complianceStatus
        self.requiredComplianceStatus = requiredComplianceStatus
        self.isValidId = isValidId
        self.message = message
        self.accessToken = accessToken
    }
}
```

**44.** `JackpotKit/Sources/JackpotForms/Domain/PasswordPolicy.swift`

```swift
import Foundation

/// One rule shown in the "Password Validity" panel.
public struct PasswordRule: Identifiable, Equatable, Sendable {
    public let id: String
    public let description: String
    private let test: @Sendable (String) -> Bool

    public init(id: String, description: String, test: @escaping @Sendable (String) -> Bool) {
        self.id = id
        self.description = description
        self.test = test
    }

    public func isSatisfied(by password: String) -> Bool { test(password) }

    public static func == (lhs: PasswordRule, rhs: PasswordRule) -> Bool { lhs.id == rhs.id }
}

/// Supplies the checklist behind the password field.
///
/// The schema gives password a single regex, `^(.){8,20}$`, but the design shows two
/// independently ticking rules, which one regex match cannot produce. Parsing the `{min,max}`
/// quantifier reproduces the design for this form; see OPEN-QUESTIONS.
public protocol PasswordPolicyProviding: Sendable {
    func rules(for field: FormField) -> [PasswordRule]
}

public struct PasswordPolicy: PasswordPolicyProviding {
    public init() {}

    public func rules(for field: FormField) -> [PasswordRule] {
        let bounds = Self.lengthBounds(in: field.regex)
        var rules: [PasswordRule] = []

        if let minimum = bounds.min {
            rules.append(PasswordRule(id: "min",
                                      description: "Minimum of \(minimum) characters",
                                      test: { $0.count >= minimum }))
        }
        if let maximum = bounds.max {
            rules.append(PasswordRule(id: "max",
                                      description: "Maximum of \(maximum) characters",
                                      test: { !$0.isEmpty && $0.count <= maximum }))
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

**45.** `JackpotKit/Sources/JackpotForms/Domain/RegexResolving.swift`

How a dropdown changes another field's rule: the schema names a pattern, this resolves it.

```swift
import Foundation

/// Dropdown options in the schema carry a `regex` that is sometimes a pattern (`"[a-zA-Z]"` on
/// sourceOfFunds) and sometimes the *name* of one (`"idNumberRegex"` on idNumberType). A name
/// has to resolve to a pattern somewhere; this protocol is that somewhere.
///
/// Named regexes *replace* the dependent field's rule: choosing "South African ID" vs
/// "Passport" changes what a valid ID Number is. `DynamicFormModel` applies that, gated on
/// `FormDependencies.appliesOptionRegexToDependentField`.
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

    /// Named option regexes that redirect onto a dependent field. `passportNumberRegex` is a
    /// **length** rule, not a character class: any 5–20 characters.
    public static let jpcDefaults = RegexCatalog(patterns: [
        "idNumberRegex": "^[0-9]{13}$",
        "passportNumberRegex": "^.{5,20}$",
    ])
}

public extension String {
    /// Tells a regex *pattern* from a regex *name*. A bare identifier has no metacharacters;
    /// a real pattern almost always does.
    var looksLikeRegexPattern: Bool {
        let metacharacters = CharacterSet(charactersIn: "^$[]{}()|*+?\\.")
        return rangeOfCharacter(from: metacharacters) != nil
    }
}
```

**46.** `JackpotKit/Sources/JackpotForms/Domain/FieldValidator.swift`

```swift
import Foundation

public enum ValidationResult: Equatable, Sendable {
    case valid
    /// Localisation key for the message to show.
    case invalid(messageKey: String)

    public var isValid: Bool { self == .valid }
}

/// Validates a value against a field's schema rules.
///
/// The regexes come from a server, so they can be malformed. A pattern that will not compile
/// is treated as "no constraint" rather than propagating the throw — one CRM typo must not
/// break signup. Compiled expressions are cached by pattern string, because compiling on every
/// keystroke for every field is wasteful.
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
        guard field.isVisible, !field.isReadOnly else { return .valid }

        if field.isRequired, value.isEmpty {
            return .invalid(messageKey: field.validationMessageKey)
        }

        // Some schema regexes permit empty explicitly (referralCode: `...|^$`) but not all do,
        // so this guard is what keeps optional fields genuinely optional.
        if !field.isRequired, value.isEmpty { return .valid }

        guard let pattern = resolvedPattern(overrideRegex ?? field.regex), !pattern.isEmpty else {
            return .valid
        }
        guard let expression = cache.expression(for: pattern) else { return .valid }

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

**47.** `JackpotKit/Sources/JackpotForms/Domain/FormLoadError.swift`

```swift
import Foundation

/// Why a form operation failed, in terms the UI can render.
///
/// The engine never sees `APIError`; the repository translates at the boundary, so the
/// server's own wording survives the trip. Without this type the server's own wording
/// ("Mobile number already registered") gets decoded, carried up, and then thrown away in
/// favour of a generic string.
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

**48.** `JackpotKit/Sources/JackpotForms/Domain/FormLocalizing.swift`

```swift
import Foundation

/// The schema ships localization *keys*, not display text: `fieldLabel` is "username", dropdown
/// text is "jpc-reg-idnumber", `validationMessage` is "regex". Something has to resolve them
/// against a string catalogue.
public protocol FormLocalizing: Sendable {
    func string(forKey key: String) -> String?

    /// Copy for a server error code, when the localisation table carries one.
    ///
    /// The app-data response contains entries keyed by error code, so a numeric `code` in an
    /// API error envelope is a localisation key. Defaulted to nil so an implementation with no
    /// such table doesn't have to care.
    func message(forErrorCode code: Int) -> String?
}

public extension FormLocalizing {
    func message(forErrorCode code: Int) -> String? { nil }

    /// Resolve, or fall back to a humanised version of the key so nothing renders blank.
    func display(_ key: String) -> String {
        string(forKey: key) ?? key.humanisedKey
    }

    /// Every field carries the same `validationMessage` ("regex") while the UI shows per-field
    /// copy, so the real key is composed: `jpc-reg-{fieldIdentifier}-{validationMessage}`. See
    /// OPEN-QUESTIONS; confirming the format is a one-line change here.
    func validationMessage(for field: FormField) -> String {
        let composed = "jpc-reg-\(field.identifier)-\(field.validationMessageKey)"
        if let resolved = string(forKey: composed) { return resolved }
        if let resolved = string(forKey: field.validationMessageKey) { return resolved }
        return "Please enter a valid \(field.identifier.humanisedKey.lowercased())"
    }
}

/// Looks up an in-memory table, then a bundle's `.strings`.
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
    /// "jpc-reg-idnumber" → "Idnumber";  "dateOfBirth" → "Date Of Birth"
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

/// Wraps any `(key) -> String?` as a localizer, so a host can hand the form engine its
/// existing translation function without either package knowing the other exists.
///
/// `FormLocalizing` uses nil to mean "unresolved" so the engine can fall back to humanised
/// copy. A host function that returns the key on a miss must map that back to nil, or a
/// missing string renders as the raw key.
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

**49.** `JackpotKit/Sources/JackpotForms/Domain/FormRepository.swift`

```swift
import Foundation

/// Contract for form data operations: fetch a definition by name and submit it.
///
/// Fetch is `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`; submit posts a
/// `FormSubmission` to `{cron}/forms/submit`.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult
}
```

**50.** `JackpotKit/Sources/JackpotForms/Data/FormDTO.swift`

```swift
import Foundation

// Wire shapes, exactly as the CRM form-builder sends them. Nothing outside this folder knows
// about "formSectionCodeName" or the "Calender" spelling. Keys the app has no use for
// (`fieldName`, `textStyle`, `fieldPlaceholder`, `fieldRadioGroup`) are simply not decoded.
//
// Everything is optional except the identifiers we cannot render without: the schema is edited
// by product in a CMS, so a missing `prefix` must not fail the whole decode.

struct FormDTO: Decodable {
    let formId: Int
    let formCodeName: String
    let formTitle: String?
    let formSubTitle: String?
    let regionCode: String?
    let sections: [FormSectionDTO]?
}

struct FormSectionDTO: Decodable {
    let formSectionId: Int
    let formSectionCodeName: String?
    let formSectionTitle: String?
    let formSectionSubTitle: String?
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

**51.** `JackpotKit/Sources/JackpotForms/Data/FormMapper.swift`

```swift
import Foundation

enum FormMapper {
    static func map(_ dto: FormDTO) -> FormSchema {
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
            labelKey: dto.fieldLabel,
            type: FieldType(raw: dto.fieldType),
            inputType: InputType(raw: dto.inputType ?? "Text"),
            validationMessageKey: dto.validationMessage ?? "regex",
            // Defaults chosen to fail safe: an unspecified field is optional and
            // visible rather than silently blocking submission.
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

**52.** `JackpotKit/Sources/JackpotForms/Data/StubFormRepository.swift`

```swift
import Foundation

/// Serves forms from bundled JSON. Backs the sandbox and previews, and lets the whole feature
/// be built and reviewed before the endpoint is reachable from the app.
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
        try await prepare()
        guard let data = forms[name] else { throw FormLoadError.notFound(name) }
        return try Self.decode(data)
    }

    public func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        try await prepare()
        return FormSubmitResult()
    }

    /// Decodes raw JSON straight to a form, for previews and tests.
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

**53.** `JackpotKit/Sources/JackpotForms/Data/BundledForms.swift`

```swift
import Foundation

/// The schemas shipped with the package as JSON, keyed by `formCodeName`. The stub repository,
/// previews and tests all read them from here. `registration.json` is the CRM's response for
/// `forms/jackpotcity/JZA/registration?api-version=2.0`, saved verbatim.
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

**54.** `JackpotKit/Sources/JackpotForms/Data/RegistrationCopy.swift`

The placeholder copy table, until the app-data `locales` section is wired in.

```swift
import Foundation

public extension ComposedKeyLocalizer {
    /// Placeholder copy for the registration schema's keys, matching the designs. In
    /// production the same table arrives in the app-data response's `locales` section; this
    /// one keeps the form legible until it does, and stands in for it in previews and the
    /// sandbox.
    static let jpcRegistration = ComposedKeyLocalizer(table: [
        // Field labels
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
```

**55.**

```bash
cp registration.json JackpotKit/Sources/JackpotForms/Resources/registration.json
```

`registration.json` is the CRM's response saved verbatim — 12 fields over two sections.
`JackpotForms` processes it as a resource; `BundledForms` reads it from `Bundle.module`
for the stub repository, the previews and the tests alike.

**56.** `JackpotKit/Sources/JackpotForms/UI/FormDependencies.swift`

The engine's dependencies and `.mock()`. Defaults are generic: no regex links, no date
cap. Registration adds its own in PR 4.

```swift
import Foundation

/// Everything `DynamicFormView` needs besides the form name and the submit callback.
///
/// Defaults are the generic engine's: no cross-field regex links and no date cap. A feature
/// adds its own rules on top — see `RegistrationDependencies`.
public struct FormDependencies {
    public var repository: any FormRepository
    public var validator: FieldValidator
    public var localizer: any FormLocalizing
    public var passwordPolicy: any PasswordPolicyProviding
    /// "This dropdown drives this field's regex", keyed by the dropdown's identifier. When the
    /// selected option carries a *named* regex it replaces the dependent field's rule. Declared
    /// outright rather than inferred from row order, so a CRM reorder cannot silently relax
    /// validation on a regulated field.
    public var regexDependencies: [String: String]
    /// Latest date a calendar field may select. Nil means today.
    public var maximumDate: Date?

    public init(repository: any FormRepository,
                validator: FieldValidator = FieldValidator(),
                localizer: any FormLocalizing = ComposedKeyLocalizer(),
                passwordPolicy: any PasswordPolicyProviding = PasswordPolicy(),
                regexDependencies: [String: String] = [:],
                maximumDate: Date? = nil) {
        self.repository = repository
        self.validator = validator
        self.localizer = localizer
        self.passwordPolicy = passwordPolicy
        self.regexDependencies = regexDependencies
        self.maximumDate = maximumDate
    }
}

public extension FormDependencies {

    /// Serves the bundled `registration` schema, captured from
    /// `config.jpc.africa/cron/forms/jackpotcity/JZA/registration?api-version=2.0`, so the
    /// feature is buildable and reviewable before the API is reachable from the app.
    ///
    ///     DynamicFormView(formName: .registration, dependencies: .mock()) { … }
    ///
    /// - Parameters:
    ///   - delay: fake latency, so loading states are visible in the sandbox.
    ///   - error: set to exercise the failure state.
    ///   - localizer: where copy comes from; the bundled placeholder table by default.
    static func mock(delay: TimeInterval = 0.35,
                     error: (any Error)? = nil,
                     localizer: (any FormLocalizing)? = nil) -> FormDependencies {
        FormDependencies(
            repository: StubFormRepository(forms: BundledForms.all, delay: delay, error: error),
            localizer: localizer ?? ComposedKeyLocalizer.jpcRegistration
        )
    }
}
```

**57.** `JackpotKit/Sources/JackpotForms/UI/DynamicFormModel.swift`

The engine. `load()` is `async` and a no-op once loaded, so re-appearing on screen cannot
reset a half-filled form. `advance()` / `goBack()` / `submit()` are what Next, Previous
and Sign Up call. `touched` is why an untouched field stays silent until Next, and
`overrideRegex(for:)` is how selecting Passport relaxes the SA-ID rule on a different
field.

```swift
import Foundation
import Combine

/// The engine. Owns the fetched schema, every field's value, touched state and errors, and
/// which section (page) is showing.
///
/// `ObservableObject` rather than `@Observable` because this package targets iOS 15.
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

    // MARK: Published state
    @Published public private(set) var viewState: ViewState = .loading
    @Published public private(set) var values: [String: FormValue] = [:]
    @Published public private(set) var errors: [String: String] = [:]
    @Published public private(set) var sectionIndex: Int = 0
    /// Which way the last page move went. Set before `sectionIndex` changes, in the same
    /// update, so the section transition slides the right way wherever the navigation bar is.
    @Published public private(set) var pagingDirection: PagingDirection = .forward
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var submitError: String?

    /// Field types the schema asked for that this build cannot render. Non-fatal by design
    /// (see `FieldType.unknown`); surfaced so QA and logs can see them.
    @Published public private(set) var unsupportedFields: [String] = []

    /// `@Published` because `objectWillChange` has to fire *before* the set changes, or the
    /// error it reveals lands a render late.
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

    /// Fraction of the form's required fields that currently validate. Drives the progress bar.
    public var progress: Double {
        guard let form else { return 0 }
        let required = form.allFields.filter { $0.isVisible && $0.isRequired }
        guard !required.isEmpty else { return 1 }
        return Double(required.filter(isValid).count) / Double(required.count)
    }

    /// Whether the visible section can be advanced past / submitted.
    public var isCurrentSectionValid: Bool {
        guard let section = currentSection else { return false }
        return section.fields.filter(\.isVisible).allSatisfy(isValid)
    }

    public var isFormValid: Bool {
        guard let form else { return false }
        return form.allFields.filter(\.isVisible).allSatisfy(isValid)
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

    /// Latest date a calendar field may select.
    public var maximumDate: Date { dependencies.maximumDate ?? Date() }

    // MARK: Loading

    /// Fetches the schema. A no-op once loaded, so re-appearing on screen cannot reset a
    /// half-filled form; after a failure it runs again, which is what Retry calls.
    public func load() async {
        if case .loaded = viewState { return }
        viewState = .loading
        do {
            let form = try await dependencies.repository.form(named: formName)
            guard !Task.isCancelled else { return }
            apply(form)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            viewState = .failed(Self.message(for: error))
        }
    }

    private func apply(_ form: FormSchema) {
        viewState = .loaded(form)
        sectionIndex = 0
        touched = []
        errors = [:]
        values = Dictionary(uniqueKeysWithValues:
            form.allFields.filter(\.isVisible).map { ($0.identifier, defaultValue(for: $0)) }
        )
        unsupportedFields = form.allFields.compactMap {
            if case .unknown(let raw) = $0.type { return "\($0.identifier) (\(raw))" }
            return nil
        }
        revalidateAll()
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
        validate(field)
        // A dropdown can change a dependent field's rule (ID type → ID number), so anything
        // downstream of it has to be re-checked, not just this field.
        if field.type == .dropdown { revalidateDependents(of: field) }
    }

    /// Call on blur so errors don't appear before the user has typed. Re-touching is a no-op
    /// rather than another render: the return key marks a field, then the blur that follows
    /// marks it again.
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
        form?.allFields.filter(\.isVisible).forEach { validate($0) }
    }

    private func revalidateDependents(of field: FormField) {
        guard let form else { return }
        let dependents = form.allFields.filter { candidate in
            candidate.isVisible && regexDriver(for: candidate)?.id == field.id
        }
        dependents.forEach { validate($0) }
    }

    /// The dropdown that drives `field`'s regex, if any. Links come from
    /// `FormDependencies.regexDependencies` and are never inferred from field order.
    private func regexDriver(for field: FormField) -> FormField? {
        guard let form,
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
        touched.formUnion(section.fields.filter(\.isVisible).map(\.identifier))
        revalidateAll()
        guard isCurrentSectionValid else { return false }
        if !isLastSection {
            pagingDirection = .forward
            sectionIndex += 1
        }
        return true
    }

    public func goBack() {
        guard sectionIndex > 0 else { return }
        pagingDirection = .backward
        sectionIndex -= 1
    }

    // MARK: Submitting

    public func submit(_ handler: @escaping @MainActor (FormSubmission) async throws -> Void) async {
        guard let form else { return }
        touched.formUnion(form.allFields.filter(\.isVisible).map(\.identifier))
        revalidateAll()
        guard isFormValid else { return }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            try await handler(FormSubmission(
                formCodeName: form.codeName,
                values: values,
                formId: String(form.id)
            ))
        } catch is CancellationError {
        } catch {
            submitError = Self.message(for: error)
        }
    }

    private static func message(for error: any Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription { return localized }
        return "Something went wrong. Please try again."
    }
}

#if DEBUG
// Preview support lives in this file because `private` is file-scoped in Swift, so an
// extension here can call `apply(_:)` without widening the type's real API.
public extension DynamicFormModel {

    /// A model already holding `schema`, with no async load, so previews render instantly and
    /// deterministically instead of flashing a skeleton.
    static func preview(schema: FormSchema,
                        dependencies: FormDependencies = .mock(delay: 0),
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
    static func previewLoading() -> DynamicFormModel {
        DynamicFormModel(formName: FormName("preview"), dependencies: .mock(delay: 3600))
    }

    /// Parked on the failure state.
    static func previewFailed(_ message: String = "The network connection was lost.") -> DynamicFormModel {
        let model = DynamicFormModel(formName: FormName("preview"), dependencies: .mock(delay: 0))
        model.viewState = .failed(message)
        return model
    }
}
#endif
```

**58.** `JackpotKit/Sources/JackpotForms/UI/Fields/FieldRenderer.swift`

The switch is the whole contract. Registration hits `.input` (Calender →
`DateFieldView`), `.dropdown` and `.checkbox`.

```swift
import SwiftUI
import JackpotUI

/// Maps a schema `fieldType` to a component. This switch is the entire contract between the
/// form builder and the app: a new type on the server means a new `FieldType` case, a new
/// `XxxFieldView` here binding the model to a `JackpotUI` component, and until then the
/// unknown case keeps the form usable.
///
/// The `JackpotUI` components know nothing about forms; the views in this folder are the only
/// place the two meet.
struct FieldRenderer: View {
    let field: FormField
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        switch field.type {
        case .input:    InputFieldView(field: field, model: model)
        case .dropdown: DropdownFieldView(field: field, model: model)
        case .checkbox: CheckboxFieldView(field: field, model: model)
        case .unknown:  EmptyView()          // reported via model.unsupportedFields
        }
    }
}

// MARK: - Keyboard focus order

extension FormField {
    /// Only single-line text entry joins return-key navigation. A date opens a picker.
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

    /// Selection binding for dropdowns. An empty selection is `.option("")`.
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

**59.** `JackpotKit/Sources/JackpotForms/UI/Fields/InputFieldView.swift`

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

                // The rules are guidance while composing a password, not a permanent
                // fixture — once the field is left the error line carries the verdict.
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
        model.passwordRules(for: field).map { rule in
            JackpotChecklistItem(id: rule.id,
                                 text: rule.description,
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
        // autofill hints iOS can use: `username` is a mobile number typed as `Number`.
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
            // The checklist is focus-gated, so it stays hidden here; focus the field in the
            // live preview to see it.
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

**60.** `JackpotKit/Sources/JackpotForms/UI/Fields/DropdownFieldView.swift`

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

**61.** `JackpotKit/Sources/JackpotForms/UI/Fields/DateFieldView.swift`

```swift
import SwiftUI
import JackpotUI

/// `inputType: "Calender"`. The schema validates against an ISO-8601 date-time, so the
/// picker's `Date` is serialised through `FormValue.iso8601` rather than a display format.
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

**62.** `JackpotKit/Sources/JackpotForms/UI/Fields/CheckboxFieldView.swift`

`receivePromotionalInformation` and `terms`.

```swift
import SwiftUI
import JackpotUI

/// Checkbox values validate as the strings "true"/"false" — the schema's `terms` field
/// literally uses the pattern `^true$` to mean "must be ticked".
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

**63.** `JackpotKit/Sources/JackpotForms/UI/DynamicFormView.swift`

Three views over one model. `DynamicFormContent` is the pages; `FormNavigationBar` is
Previous / Next / Sign Up — that is how step 1 becomes step 2 — and slides the pages
using the direction the model publishes; `DynamicFormView` stacks the two for hosts that
want the bar under the pages. Registration composes the first two itself.

```swift
import SwiftUI
import JackpotUI

/// A whole form, from one name, one set of dependencies and one callback: the pages with the
/// navigation bar beneath them.
///
///     DynamicFormView(formName: .registration, dependencies: .mock()) { submission in
///         try await api.register(submission.stringValues)
///     }
///
/// A host that wants the navigation somewhere else — registration puts Next in its panel's
/// footer beside the login row — owns a `DynamicFormModel` itself and places
/// `DynamicFormContent` and `FormNavigationBar` where the design says.
public struct DynamicFormView: View {

    public typealias SubmitHandler = @MainActor (FormSubmission) async throws -> Void

    private let onSubmit: SubmitHandler
    @StateObject private var model: DynamicFormModel

    public init(formName: FormName, dependencies: FormDependencies, onSubmit: @escaping SubmitHandler) {
        self.onSubmit = onSubmit
        _model = StateObject(wrappedValue: DynamicFormModel(formName: formName, dependencies: dependencies))
    }

    public var body: some View {
        DynamicFormBody(model: model, onSubmit: onSubmit)
            .task { await model.load() }
    }
}

/// Pages and navigation stacked, for a given model: what `DynamicFormView` renders, and what
/// the previews drive from a seeded model without a fetch.
struct DynamicFormBody: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler

    var body: some View {
        VStack(spacing: 0) {
            DynamicFormContent(model: model)
            FormNavigationBar(model: model, onSubmit: onSubmit)
                .padding(.horizontal, .m).padding(.vertical, .sm)
        }
        .jackpotBackground(\.background)
    }
}

/// The form's pages: the progress bar, the current section's rows and any submit error, with
/// the loading and failure states in their place. Moving between pages is `FormNavigationBar`.
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
                    // New identity per section is what lets the transition run at all; the
                    // progress bar sits outside it so it doesn't slide too.
                    .id(model.sectionIndex)
                    .transition(sectionTransition)
                }
            }
            .jackpotFocusedField($focusedField)
            // Validate before moving focus, so the error and the new focus land in one update
            // rather than the error arriving a render after the keyboard has moved on.
            .onSubmit {
                guard let current = focusedField else { return }
                model.markTouched(identifiedBy: current)
                focusedField = model.fieldAfter(current)
            }
            // A page move dismisses the keyboard, wherever the move came from.
            .onChange(of: model.sectionIndex) { _ in focusedField = nil }
        }
    }

    /// Offset rather than a full `.move`, so the outgoing and incoming sections don't drag
    /// the scroll view's content width around mid-flight. The direction comes from the model,
    /// which sets it in the same update that moves the section.
    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let travel: CGFloat = model.pagingDirection == .forward ? 60 : -60
        return .asymmetric(insertion: .offset(x: travel).combined(with: .opacity),
                           removal: .offset(x: -travel).combined(with: .opacity))
    }
}

/// Fields sharing a `rowNumber` render side by side; a single field fills the row.
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

/// Previous / Next / Sign Up. Paging is not a field: the schema describes sections, and this
/// bar is how the user moves between them. Nothing renders until the form has loaded. Place it
/// under `DynamicFormContent`, or wherever the design puts it — registration puts it in the
/// panel's footer beside the login row.
public struct FormNavigationBar: View {
    @ObservedObject private var model: DynamicFormModel
    private let onSubmit: DynamicFormView.SubmitHandler

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: DynamicFormModel, onSubmit: @escaping DynamicFormView.SubmitHandler) {
        _model = ObservedObject(wrappedValue: model)
        self.onSubmit = onSubmit
    }

    public var body: some View {
        if model.form != nil {
            HStack(spacing: .sm) {
                if !model.isFirstSection {
                    Button("Previous") { withAnimation(pagingAnimation) { model.goBack() } }
                        .buttonStyle(.jackpot(.secondary))
                }
                if model.isLastSection {
                    Button("Sign Up") { Task { await model.submit(onSubmit) } }
                        .buttonStyle(.jackpot)
                        .disabled(!model.isFormValid)
                        .jackpotLoading(model.isSubmitting)
                } else {
                    Button("Next") { withAnimation(pagingAnimation) { _ = model.advance() } }
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
struct DynamicFormView_Previews: PreviewProvider {
    private struct Harness: View {
        let model: DynamicFormModel
        var scheme: ColorScheme = .dark
        var body: some View {
            DynamicFormBody(model: model) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.background)
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

            // Through the real loader, so a schema change in the JSON shows up here.
            DynamicFormView(formName: .registration, dependencies: .mock(delay: 0)) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Registration — from JSON")
            DynamicFormView(formName: .registration, dependencies: .mock(delay: 0, error: FormLoadError.offline)) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Offline")
            DynamicFormView(formName: FormName("doesNotExist"), dependencies: .mock(delay: 0)) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Unknown form — 404")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**64.** `JackpotKit/Sources/JackpotForms/UI/FormPreview.swift`

Decodes the bundled JSON for the seeded-model previews, so the previews and the stub
cannot disagree about the schema.

```swift
#if DEBUG
import Foundation

/// The registration schema decoded from the bundled JSON, plus helpers that seed a model so
/// component previews render a chosen state without a fetch.
enum FormPreview {

    static let registration: FormSchema = {
        // A broken bundled schema should fail previews loudly rather than render nothing.
        try! StubFormRepository.decode(BundledForms.json(named: "registration"))
    }()

    static func field(_ identifier: String) -> FormField {
        guard let field = registration.field(identifiedBy: identifier) else {
            preconditionFailure("registration.json has no field \(identifier)")
        }
        return field
    }

    /// A one-section schema of just these fields, for previewing components alone.
    static func schema(_ fields: [FormField]) -> FormSchema {
        FormSchema(id: 1, codeName: FormName("preview"), title: "", subTitle: "", regionCode: "JZA",
                   sections: [FormSection(id: 1, codeName: "1", title: "", subTitle: "", order: 1,
                                          rows: fields.enumerated().map { FormRow(number: $0.offset + 1, fields: [$0.element]) })])
    }

    /// Model holding just these fields, optionally pre-filled and pre-touched so the
    /// invalid (red) state can be previewed without interacting.
    @MainActor
    static func model(_ fields: [FormField],
                      values: [String: FormValue] = [:],
                      touched: [String] = []) -> DynamicFormModel {
        .preview(schema: schema(fields), values: values, touched: touched)
    }

    /// Values that make section one valid, for previewing the enabled Next button.
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

At this point the engine renders the bundled schema end to end. Open `DynamicFormView.swift`
and resume **Registration — from JSON**, then wire the network:

**65.** `JackpotKit/Sources/JackpotForms/Remote/FormEndpoints.swift`

The cron URLs, the submit body, and `FormSubmitParser` — HTTP 200 is not success, the
envelope's `isSuccessful` is, and a body that is not the envelope is a rejection.

```swift
import Foundation
import JackpotNetworking

// Fetch, submit and app-data all live under `https://config.jpc.africa/cron`. Fetch carries
// `api-version=2.0` and submit carries none, so the version belongs on the request rather than
// on the environment.

extension APIEnvironment {
    /// The cron config service — `https://config.jpc.africa/cron`.
    static func cron(baseURL: URL) -> APIEnvironment {
        APIEnvironment(baseURL: baseURL)
    }

    /// `https://config.jpc.africa/crm` → `https://config.jpc.africa/cron`, because call sites
    /// historically passed a CRM base and production fetch is on cron.
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

/// `GET {cron}/forms/{brand}/{region}/{name}?api-version=2.0`, matching production `buildFormURL`.
struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    var path: String { "forms/\(brand)/\(region)/\(formName.rawValue)" }
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "api-version", value: "2.0")] }
}

/// `POST {cron}/forms/submit` — no `api-version` query item. Auth is not required, because
/// registration happens before login.
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

/// Wire shape of `FormSubmission`, so the domain type stays free of JSON key names.
struct FormSubmitBody: Encodable {
    let formId: String
    let formName: String
    let submittedAt: Date
    let fields: [String: FieldValue]
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case formId = "form_id"
        case formName = "form_name"
        case submittedAt = "submitted_at"
        case fields, metadata
    }

    init(_ submission: FormSubmission) {
        formId = submission.formId
        formName = submission.formCodeName.rawValue
        submittedAt = submission.submittedAt
        fields = submission.values.mapValues(\.fieldValue)
        metadata = submission.metadata
    }

    /// ISO-8601 is an assumption — the production encoder wasn't visible.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

/// Untagged JSON value for a form field.
///
/// The custom `encode` is required: synthesized `Codable` would emit a tagged object
/// (`{"bool":true}`) instead of a bare JSON value.
enum FieldValue: Equatable, Sendable, Encodable {
    case string(String)
    case bool(Bool)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .bool(let value):   try container.encode(value)
        case .null:              try container.encodeNil()
        }
    }
}

extension FormValue {
    var fieldValue: FieldValue {
        switch self {
        case .empty:         return .null
        case .text(let s):   return .string(s)
        case .bool(let b):   return .bool(b)
        case .option(let s): return .string(s)
        case .date(let d):   return .string(FormValue.iso8601.format(d))
        }
    }
}

/// HTTP 200 is not success: the body carries `isSuccessful` / `error`, so a client that only
/// looked for `"success"` would swallow a failed create.
struct FormSubmitEnvelope: Decodable {
    let data: FormSubmitDataDTO?
    let isSuccessful: Bool?
    let success: Bool?
    let error: FormSubmitErrorDTO?
}

struct FormSubmitDataDTO: Decodable {
    let accountId: String?
    let message: String?
    let status: String?
    let partialRegistrationStatus: Int?
    let complianceResponse: FormComplianceDTO?
}

struct FormSubmitErrorDTO: Decodable {
    let code: Int?
    let displayCode: Int?
    let message: String?
}

struct FormComplianceDTO: Decodable {
    let complianceStatus: Int?
    let requiredComplianceStatus: Int?
    let isValidId: Bool?
    let message: String?
    let accessToken: String?
}

enum FormSubmitParser {
    enum Outcome {
        case accepted(FormSubmitResult)
        case rejected(FormSubmitErrorDTO?)
    }

    static func parse(_ data: Data) -> Outcome {
        // An empty 2xx is taken as accepted (an assumption; see OPEN-QUESTIONS). Anything else
        // has to be the envelope: a gateway page served with status 200, or JSON that is not
        // this shape, is not a registered account.
        if data.isEmpty { return .accepted(FormSubmitResult()) }
        guard let envelope = try? JSONDecoder().decode(FormSubmitEnvelope.self, from: data),
              envelope.isEnvelope else {
            return .rejected(nil)
        }
        if envelope.failed { return .rejected(envelope.error) }
        return .accepted(FormSubmitResult(envelope.data))
    }
}

private extension FormSubmitEnvelope {
    /// Every field is optional so a partial body still decodes; a body with none of them is
    /// some other document that happened to parse.
    var isEnvelope: Bool {
        data != nil || isSuccessful != nil || success != nil || error != nil
    }

    var failed: Bool {
        if isSuccessful == false || success == false { return true }
        return error != nil && isSuccessful != true
    }
}

extension FormSubmitResult {
    init(_ data: FormSubmitDataDTO?) {
        self.init(
            accountId: data?.accountId,
            message: data?.message,
            status: data?.status,
            partialRegistrationStatus: data?.partialRegistrationStatus,
            compliance: data?.complianceResponse.map(FormComplianceResult.init)
        )
    }
}

extension FormComplianceResult {
    init(_ dto: FormComplianceDTO) {
        self.init(
            complianceStatus: dto.complianceStatus,
            requiredComplianceStatus: dto.requiredComplianceStatus,
            isValidId: dto.isValidId,
            message: dto.message,
            accessToken: dto.accessToken
        )
    }
}
```

**66.** `JackpotKit/Sources/JackpotForms/Remote/FormErrorMapper.swift`

The boundary that decides what the user reads. The engine cannot see `APIError`, so
anything not translated here becomes a generic failure on screen.

```swift
import Foundation
import JackpotNetworking

// The translation boundary. The form engine never sees `APIError`, so this is where transport
// concerns become something a person can read.
enum FormErrorMapper {

    /// - Parameter localizer: resolves an error `code` to localised copy when the session's
    ///   table carries one. That beats `problem.message`, which arrives in whatever language
    ///   the API defaulted to.
    static func map(_ error: any Error,
                    formName: FormName,
                    localizer: (any FormLocalizing)? = nil) -> any Error {
        guard let apiError = error as? APIError else { return error }

        switch apiError {
        case .cancelled:
            // Never user-facing: a cancelled load is a navigation event, not a failure.
            return CancellationError()

        case .transport where apiError.isOffline:
            return FormLoadError.offline

        case .unexpectedStatus(404, _):
            return FormLoadError.notFound(formName)

        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            // Localised copy for the code first, then whatever the server wrote, then ours —
            // the server is the only party that knows *why*.
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

**67.** `JackpotKit/Sources/JackpotForms/Remote/RemoteFormRepository.swift`

```swift
import Foundation
import JackpotNetworking

public struct RemoteFormRepository: FormRepository {
    private let apiClient: any ApiClient
    private let brand: String
    private let region: String
    /// Resolves error codes to localised copy. Optional: without it, errors fall back to the
    /// server's own message.
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
                throw FormLoadError.server(message: localized(error))
            }
        } catch {
            throw FormErrorMapper.map(error, formName: submission.formCodeName, localizer: localizer)
        }
    }

    private func localized(_ error: FormSubmitErrorDTO?) -> String {
        if let code = error?.code ?? error?.displayCode,
           let localized = localizer?.message(forErrorCode: code) {
            return localized
        }
        return error?.message ?? "We couldn't submit the form. Please try again."
    }
}
```

**68.** `JackpotKit/Sources/JackpotForms/Remote/TranslationsLocalizer.swift`

```swift
import Foundation
import JackpotLocalization

/// Adapts the app's session-wide `Translations` table to the form engine's `FormLocalizing`
/// seam.
///
/// An adapter rather than `extension Translations: FormLocalizing`: `Translations` belongs to
/// another module, so the conformance would be retroactive — which Swift 6 warns about, and
/// which breaks if that module later declares its own.
public struct TranslationsLocalizer: FormLocalizing {

    private let translations: Translations

    public init(_ translations: Translations) {
        self.translations = translations
    }

    /// `regional: true` covers both key shapes the schema uses: a plain key like `"username"`
    /// picks up its `-jza` override when one exists, and an already-suffixed key like
    /// `"receivePromotionalInformation-jza"` resolves directly.
    public func string(forKey key: String) -> String? {
        translations.string(forKey: key, regional: true)
    }

    public func message(forErrorCode code: Int) -> String? {
        translations.message(forErrorCode: code)
    }
}
```

**69.** `JackpotKit/Sources/JackpotForms/Remote/FormDependencies+Live.swift`

`.live(baseURL:)` — swap it for `.mock()` at the call site and nothing else changes.

```swift
import Foundation
import JackpotNetworking
import JackpotLocalization

public extension FormDependencies {

    /// The real thing. Swap `.mock()` for this at the call site and nothing else changes,
    /// because `DynamicFormView` only ever sees the `FormRepository` protocol.
    ///
    ///     DynamicFormView(formName: .registration,
    ///                     dependencies: .live(baseURL: URL(string: "https://config.jpc.africa/crm")!)) { … }
    ///
    /// `baseURL` may be the historical CRM URL; fetch and submit both run on the sibling cron
    /// service. `region` should be `AppSetupData.wmsNavigationRegionCode`.
    /// - Parameter translations: the session's locale table, from the once-per-session app-data
    ///   call. Supplying it resolves labels and dropdown options through the real CRM copy, and
    ///   turns API error *codes* into localised sentences.
    /// - Parameter localizer: overrides the table-derived localizer. During the migration the
    ///   app passes a `ClosureLocalizer` over its existing `getTranslation`; once
    ///   `JackpotLocalization` is adopted, omit it and pass `translations` instead.
    static func live(baseURL: URL,
                     translations: Translations = Translations(),
                     brand: String = "jackpotcity",
                     region: String = "JZA",
                     bearerToken: (@Sendable () async -> String?)? = nil,
                     localizer explicitLocalizer: (any FormLocalizing)? = nil) -> FormDependencies {
        let interceptors: [any RequestInterceptor] = bearerToken.map { [BearerTokenInterceptor(token: $0)] } ?? []
        let client = RemoteApiClient(
            environment: .cron(baseURL: APIEnvironment.cronBaseURL(fromCRM: baseURL)),
            interceptors: interceptors
        )
        // An empty table means app-data hasn't landed yet; the bundled placeholder copy keeps
        // the form legible rather than rendering raw keys.
        let localizer: any FormLocalizing = explicitLocalizer
            ?? (translations.isEmpty ? ComposedKeyLocalizer.jpcRegistration : TranslationsLocalizer(translations))

        return FormDependencies(
            repository: RemoteFormRepository(apiClient: client, brand: brand, region: region,
                                             localizer: localizer),
            localizer: localizer
        )
    }
}
```

**70.** `JackpotKit/Tests/JackpotFormsTests/FormDecodingTests.swift`

```swift
import XCTest
@testable import JackpotForms

final class FormDecodingTests: XCTestCase {

    private func loadRegistration() throws -> FormSchema {
        try StubFormRepository.decode(BundledForms.json(named: "registration"))
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

    /// The three types registration uses are the three this build renders.
    func testFieldTypesMapCorrectly() throws {
        let form = try loadRegistration()
        XCTAssertEqual(Set(form.allFields.map(\.type)), [.input, .dropdown, .checkbox])
        XCTAssertEqual(form.field(identifiedBy: "username")?.type, .input)
        XCTAssertEqual(form.field(identifiedBy: "username")?.inputType, .number)
        XCTAssertEqual(form.field(identifiedBy: "username")?.prefix, "+27")
        XCTAssertEqual(form.field(identifiedBy: "password")?.inputType, .password)
        XCTAssertEqual(form.field(identifiedBy: "email")?.inputType, .email)
        XCTAssertEqual(form.field(identifiedBy: "dateOfBirth")?.inputType, .calendar)
        XCTAssertEqual(form.field(identifiedBy: "idNumberType")?.type, .dropdown)
        XCTAssertEqual(form.field(identifiedBy: "terms")?.type, .checkbox)
    }

    /// The schema spells it "Calender". If the backend ever fixes the typo we must not silently
    /// downgrade the date picker to a text box.
    func testCalendarInputTypeAcceptsBothSpellings() {
        XCTAssertEqual(InputType(raw: "Calender"), .calendar)
        XCTAssertEqual(InputType(raw: "Calendar"), .calendar)
        XCTAssertEqual(InputType(raw: "date"), .calendar)
    }

    /// The most important behaviour in the decoder: a field type this build has never heard of
    /// must not fail the decode, because product edits the schema in a CMS without shipping.
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

    func testTheBundledSchemaIsRegistration() throws {
        XCTAssertEqual(Set(BundledForms.all.keys), [.registration])
        let form = try StubFormRepository.decode(try XCTUnwrap(BundledForms.all[.registration]))
        XCTAssertEqual(form.codeName, .registration)
    }
}

final class FormNameTests: XCTestCase {

    func testKnownNamesMapToTheirCodeNames() {
        XCTAssertEqual(FormName.registration.rawValue, "registration")
    }

    /// Forms are authored server-side, so a name this build has never heard of must still be
    /// constructible — that's why `FormName` isn't an enum.
    func testServerAuthoredNamesAreConstructible() {
        let deposit = FormName("deposit")
        XCTAssertEqual(deposit.rawValue, "deposit")
        XCTAssertNotEqual(deposit, .registration)
    }

    func testUsableAsADictionaryKey() {
        let forms: [FormName: Int] = [.registration: 1, FormName("deposit"): 2]
        XCTAssertEqual(forms[.registration], 1)
        XCTAssertEqual(forms[FormName("deposit")], 2)
        XCTAssertNil(forms[FormName("withdrawal")])
    }

    func testRoundTripsThroughRawValue() {
        XCTAssertEqual(FormName(rawValue: "registration"), .registration)
    }
}
```

**71.** `JackpotKit/Tests/JackpotFormsTests/FieldValidatorTests.swift`

```swift
import XCTest
@testable import JackpotForms

final class FieldValidatorTests: XCTestCase {

    private let validator = FieldValidator()

    private func field(_ identifier: String,
                       type: FieldType = .input,
                       inputType: InputType = .text,
                       required: Bool = true,
                       regex: String?) -> FormField {
        FormField(id: 1, identifier: identifier, type: type, inputType: inputType,
                  isRequired: required, regex: regex)
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
        let hidden = FormField(id: 1, identifier: "a", isRequired: true, isVisible: false, regex: "^impossible$")
        XCTAssertTrue(validator.validate(.text(""), against: hidden).isValid)

        let readOnly = FormField(id: 2, identifier: "b", isRequired: true, isReadOnly: true, regex: "^impossible$")
        XCTAssertTrue(validator.validate(.text(""), against: readOnly).isValid)
    }

    // MARK: Named regexes (the ID-type → ID-number dependency)

    func testNamedRegexResolvesFromTheCatalogue() {
        XCTAssertEqual(validator.optionPattern("idNumberRegex"), "^[0-9]{13}$")
        XCTAssertEqual(validator.optionPattern("passportNumberRegex"), "^.{5,20}$")
    }

    /// Passport is a length rule, not a character class. Too short fails; any 5–20
    /// characters pass — including punctuation the old alphanumeric guess would have rejected.
    func testPassportPatternIsACharacterCount() {
        let pattern = validator.optionPattern("passportNumberRegex")!
        let expression = try! NSRegularExpression(pattern: pattern)
        func matches(_ value: String) -> Bool {
            expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        }
        XCTAssertTrue(matches("A1234567"))
        XCTAssertTrue(matches("123456789"))
        XCTAssertTrue(matches("!!!!!!!!"))
        XCTAssertFalse(matches(""))
        XCTAssertFalse(matches("abc"))
        XCTAssertFalse(matches(String(repeating: "x", count: 21)))
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
        XCTAssertEqual(rules[0].description, "Minimum of 8 characters")
        XCTAssertEqual(rules[1].description, "Maximum of 20 characters")
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

**72.** `JackpotKit/Tests/JackpotFormsTests/DynamicFormModelTests.swift`

The behaviour a user experiences: untouched fields stay silent, Next reveals every error at
once, section gating, submit blocked while invalid, the payload keyed by
`fieldIdentifier`, and the ID-type → ID-number rule.

```swift
import Combine
import XCTest
@testable import JackpotForms

/// End-to-end validation behaviour against the real registration schema: what the user
/// actually experiences, rather than the regexes in isolation.
@MainActor
final class DynamicFormModelTests: XCTestCase {

    private func loaded(regexDependencies: [String: String] = ["idNumberType": "idNumber"]) async -> DynamicFormModel {
        let model = DynamicFormModel(
            formName: .registration,
            dependencies: FormDependencies(
                repository: StubFormRepository(forms: BundledForms.all, delay: 0),
                regexDependencies: regexDependencies
            )
        )
        await model.load()
        return model
    }

    private func field(_ model: DynamicFormModel, _ id: String) throws -> FormField {
        try XCTUnwrap(model.form?.field(identifiedBy: id))
    }

    // MARK: Loading

    func testLoadsSchemaAndSeedsEveryField() async throws {
        let model = await loaded()
        XCTAssertEqual(model.sections.count, 2)
        XCTAssertEqual(model.sectionIndex, 0)
        XCTAssertTrue(model.isFirstSection)
        XCTAssertFalse(model.isLastSection)
        // Checkboxes start false, not empty — so `terms` is correctly invalid up front.
        XCTAssertEqual(model.value(for: try field(model, "terms")), .bool(false))
    }

    /// Re-appearing on screen calls `load()` again; it must not reset a half-filled form.
    func testLoadIsANoOpOnceLoaded() async throws {
        let model = await loaded()
        model.setValue(.text("849134302"), for: try field(model, "username"))
        await model.load()
        XCTAssertEqual(model.value(for: try field(model, "username")), .text("849134302"))
    }

    func testAFailedLoadCanBeRetried() async throws {
        let repository = FailOnceRepository()
        let model = DynamicFormModel(formName: .registration,
                                     dependencies: FormDependencies(repository: repository))
        await model.load()
        XCTAssertEqual(model.viewState, .failed(FormLoadError.offline.errorDescription!))

        await model.load()
        XCTAssertNotNil(model.form, "the retry should reach the schema")
    }

    // MARK: Errors appear only after the user has engaged

    func testUntouchedFieldsShowNoErrorEvenWhenInvalid() async throws {
        let model = await loaded()
        let mobile = try field(model, "username")
        XCTAssertNil(model.error(for: mobile))          // empty + required, but untouched
        model.markTouched(mobile)
        XCTAssertNotNil(model.error(for: mobile))
    }

    func testAdvancingRevealsEveryErrorInTheSection() async throws {
        let model = await loaded()
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
        let model = await loaded()
        XCTAssertFalse(model.isCurrentSectionValid)

        try fillSectionOne(model)

        XCTAssertTrue(model.isCurrentSectionValid)
        XCTAssertTrue(model.advance())
        XCTAssertEqual(model.sectionIndex, 1)
        XCTAssertTrue(model.isLastSection)

        model.goBack()
        XCTAssertEqual(model.sectionIndex, 0)
    }

    /// The navigation bar can live away from the pages, so the pages learn which way to slide
    /// from the model rather than from the button that was tapped.
    func testPagingDirectionFollowsTheLastMove() async throws {
        let model = await loaded()
        try fillSectionOne(model)
        XCTAssertTrue(model.advance())
        XCTAssertEqual(model.pagingDirection, .forward)
        model.goBack()
        XCTAssertEqual(model.pagingDirection, .backward)
    }

    // MARK: The ID-type → ID-number dependency

    func testPassportSelectionRelaxesTheThirteenDigitIdRule() async throws {
        let model = await loaded()
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
        let model = await loaded()
        var called = false
        await model.submit { _ in called = true }
        XCTAssertFalse(called)
    }

    func testSubmitDeliversEveryValueKeyedByFieldIdentifier() async throws {
        let model = await loaded()
        try fillSectionOne(model)
        _ = model.advance()
        try fillSectionTwo(model)

        XCTAssertTrue(model.isFormValid)

        var received: FormSubmission?
        await model.submit { received = $0 }

        let submission = try XCTUnwrap(received)
        XCTAssertEqual(submission.formCodeName, .registration)
        XCTAssertEqual(submission.formId, "1052")
        XCTAssertEqual(submission["username"].stringValue, "849134302")
        XCTAssertEqual(submission["firstname"].stringValue, "Malcolm")
        XCTAssertEqual(submission["idNumberType"].stringValue, "idNumber")
        XCTAssertEqual(submission["terms"].stringValue, "true")
        XCTAssertEqual(submission["receivePromotionalInformation"].stringValue, "false")
        // Untouched optional field still present, as an empty string.
        XCTAssertEqual(submission["referralCode"].stringValue, "")
    }

    func testSubmitSurfacesAThrownError() async throws {
        let model = await loaded()
        try fillSectionOne(model)
        _ = model.advance()
        try fillSectionTwo(model)

        struct Boom: LocalizedError { var errorDescription: String? { "Registration failed" } }
        await model.submit { _ in throw Boom() }
        XCTAssertEqual(model.submitError, "Registration failed")
    }

    // MARK: Progress

    func testProgressTracksSatisfiedRequiredFields() async throws {
        let model = await loaded()
        XCTAssertEqual(model.progress, 0, accuracy: 0.001)
        try fillSectionOne(model)
        XCTAssertGreaterThan(model.progress, 0.3)
        XCTAssertLessThan(model.progress, 1.0)
        _ = model.advance()
        try fillSectionTwo(model)
        XCTAssertEqual(model.progress, 1.0, accuracy: 0.001)
    }

    // MARK: Render scheduling

    /// The return key marks the field on submit and the blur that follows marks it again.
    /// A second render there is what made the error appear a beat after focus moved.
    func testReTouchingAFieldSchedulesNoFurtherRender() async throws {
        let model = await loaded()
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
        let model = await loaded()
        let mobile = try field(model, "username")
        model.setValue(.text("123"), for: mobile)
        XCTAssertNil(model.error(for: mobile), "untouched, so still silent")

        model.markTouched(identifiedBy: "username")
        XCTAssertNotNil(model.error(for: mobile))

        model.markTouched(identifiedBy: "notAField")   // must not trap
    }

    // MARK: Return-key focus order

    func testFocusOrderCoversOnlyTextEntryInSchemaOrder() async throws {
        let model = await loaded()
        XCTAssertEqual(model.focusableIdentifiers,
                       ["username", "password", "firstname", "lastname", "email", "referralCode"])
    }

    func testReturnWalksToTheNextFieldAndStopsAtTheEnd() async throws {
        let model = await loaded()
        XCTAssertEqual(model.fieldAfter("username"), "password")
        XCTAssertEqual(model.fieldAfter("email"), "referralCode")
        XCTAssertNil(model.fieldAfter("referralCode"), "The last field dismisses rather than wrapping")
    }

    func testFocusOrderIgnoresUnknownAndAbsentFields() async throws {
        let model = await loaded()
        XCTAssertNil(model.fieldAfter(nil))
        XCTAssertNil(model.fieldAfter("notAField"))
    }

    func testDateAndPickerFieldsAreNotKeyboardFocusable() async throws {
        let model = await loaded()
        for identifier in ["dateOfBirth", "idNumberType", "sourceOfFunds", "terms"] {
            XCTAssertFalse(try field(model, identifier).acceptsKeyboardFocus,
                           "\(identifier) opens a picker or toggles, so the return key should skip it")
        }
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
}

/// Offline on the first fetch, the bundled schema after that.
private final class FailOnceRepository: FormRepository, @unchecked Sendable {
    private var hasFailed = false

    func form(named name: FormName) async throws -> FormSchema {
        if !hasFailed {
            hasFailed = true
            throw FormLoadError.offline
        }
        return try await StubFormRepository(forms: BundledForms.all, delay: 0).form(named: name)
    }

    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult { FormSubmitResult() }
}

/// Confirmed behaviour: the ID Number Type dropdown selects whether the user is entering a
/// South African ID or a passport, and the ID Number field validates accordingly.
///
/// The link is declared in `FormDependencies.regexDependencies` rather than inferred from
/// field order, so a CRM reorder can't silently disable it on a regulated field.
@MainActor
final class IDTypeRegexDependencyTests: XCTestCase {

    private func loadedSectionTwo(regexDependencies: [String: String] = ["idNumberType": "idNumber"]) async -> DynamicFormModel {
        let model = DynamicFormModel(
            formName: .registration,
            dependencies: FormDependencies(
                repository: StubFormRepository(forms: BundledForms.all, delay: 0),
                regexDependencies: regexDependencies
            )
        )
        await model.load()
        return model
    }

    private func field(_ model: DynamicFormModel, _ id: String) throws -> FormField {
        try XCTUnwrap(model.form?.field(identifiedBy: id))
    }

    func testSouthAfricanIDRequiresThirteenDigits() async throws {
        let model = await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("idNumber"), for: type)
        model.setValue(.text("9001015800089"), for: number)
        model.markTouched(number)
        XCTAssertNil(model.error(for: number))

        model.setValue(.text("A1234567"), for: number)
        XCTAssertNotNil(model.error(for: number), "a passport number is not a valid SA ID")
    }

    func testPassportAcceptsAnAlphanumericNumber() async throws {
        let model = await loadedSectionTwo()
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")

        model.setValue(.option("passport"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNil(model.error(for: number))
    }

    /// Switching type revalidates immediately — the user shouldn't have to re-type to see the
    /// rule change.
    func testSwitchingTypeRevalidatesWithoutRetyping() async throws {
        let model = await loadedSectionTwo()
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
        let model = await loadedSectionTwo()
        let source = try field(model, "sourceOfFunds")
        let promo = try field(model, "receivePromotionalInformation")

        model.setValue(.option("SalaryOrWages"), for: source)
        model.setValue(.bool(true), for: promo)
        model.markTouched(promo)
        XCTAssertNil(model.error(for: promo))
    }

    /// The engine's default is no links at all: without one, the field's own regex always
    /// applies, whatever the dropdown says.
    func testNoLinkMeansTheFieldsOwnRuleApplies() async throws {
        let model = await loadedSectionTwo(regexDependencies: [:])
        let type = try field(model, "idNumberType"), number = try field(model, "idNumber")
        model.setValue(.option("passport"), for: type)
        model.setValue(.text("A1234567"), for: number)
        model.markTouched(number)
        XCTAssertNotNil(model.error(for: number))
    }
}
```

**73.** `JackpotKit/Tests/JackpotFormsTests/FormErrorMappingTests.swift`

```swift
import XCTest
@testable import JackpotForms
import JackpotNetworking
import JackpotLocalization

final class CRMEnvironmentTests: XCTestCase {

    private let cron = URL(string: "https://config.jpc.africa/cron")!

    func testBuildsTheProductionFormURL() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: .registration)
            .urlRequest(in: .cron(baseURL: cron))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://config.jpc.africa/cron/forms/jackpotcity/JZA/registration?api-version=2.0")
    }

    func testServerAuthoredFormNameLandsInThePath() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: FormName("deposit"))
            .urlRequest(in: .cron(baseURL: cron))
        XCTAssertTrue(request.url?.path.hasSuffix("/deposit") == true)
    }
}

/// The server's own wording has to survive the trip from JSON to the screen, and every hop is a
/// place it could be dropped. The engine cannot see `APIError`, so without `FormLoadError`
/// carrying the message across that boundary everything becomes "Something went wrong".
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

    /// A cancelled load is a navigation event, not a failure — it must never reach the user.
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

/// The app-data response carries error copy keyed by code — `"6000328": "Maximum OTP tries…"` —
/// so an API error envelope's `code` is a localisation key.
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

    /// The table wins over the envelope's own text — it's the localised one.
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

    /// With no table loaded yet — first launch, app-data still in flight — show whatever the
    /// server said.
    func testEmptyTableDegradesToTheServersMessage() {
        let error = APIError.badRequest(APIProblem(code: 6000328, message: "Max OTP tries"))
        let mapped = FormErrorMapper.map(error, formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Max OTP tries")
    }
}

/// The schema hands the renderer keys, not text. These assert the join works for the key shapes
/// the registration schema actually uses.
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

    /// The schema gives this one already region-suffixed.
    func testPreSuffixedKeyResolves() {
        XCTAssertEqual(localizer.display("receivePromotionalInformation-jza"),
                       "Send Jackpot City Promotions to me")
    }

    /// A key with no entry renders humanised rather than blank, so QA sees the gap.
    func testMissingKeyIsVisibleNotBlank() {
        XCTAssertEqual(localizer.display("dateOfBirth"), "Date Of Birth")
    }
}
```

**74.** `JackpotKit/Tests/JackpotFormsTests/FormRepositoryTests.swift`

Both repositories are driven through the same protocol here, which is the check that the
stub and the live one are actually interchangeable.

```swift
import XCTest
@testable import JackpotForms
import JackpotNetworking

final class FormSubmitEndpointTests: XCTestCase {

    private let cron = URL(string: "https://config.jpc.africa/cron")!

    func testSubmitURLMatchesProduction() throws {
        let request = try FormSubmitRequest(Self.sample).urlRequest(in: .cron(baseURL: cron))
        XCTAssertEqual(request.url?.absoluteString, "https://config.jpc.africa/cron/forms/submit")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(request.url?.query, "submit has no api-version query item")
    }

    func testCronBaseURLIsDerivedFromTheCRMBase() {
        XCTAssertEqual(
            APIEnvironment.cronBaseURL(fromCRM: URL(string: "https://config.jpc.africa/crm")!).absoluteString,
            "https://config.jpc.africa/cron"
        )
        XCTAssertEqual(
            APIEnvironment.cronBaseURL(fromCRM: cron).absoluteString,
            "https://config.jpc.africa/cron"
        )
        XCTAssertEqual(
            APIEnvironment.cronBaseURL(fromCRM: URL(string: "https://config.jpc.africa")!).absoluteString,
            "https://config.jpc.africa/cron"
        )
    }

    func testFetchByNameMatchesProductionBuildFormURL() throws {
        let request = try FormRequest(brand: "jackpotcity", region: "JZA", formName: .registration)
            .urlRequest(in: .cron(baseURL: cron))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://config.jpc.africa/cron/forms/jackpotcity/JZA/registration?api-version=2.0")
    }

    func testSubmitBodyUsesSnakeCaseKeysAndTypedFields() throws {
        let data = try FormSubmitBody.encoder.encode(FormSubmitBody(Self.sample))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["form_id"] as? String, "1052")
        XCTAssertEqual(json["form_name"] as? String, "registration")
        XCTAssertEqual(json["submitted_at"] as? String, "1970-01-01T00:00:00Z")
        let fields = try XCTUnwrap(json["fields"] as? [String: Any])
        XCTAssertEqual(fields["username"] as? String, "849134302")
        XCTAssertEqual(fields["terms"] as? Bool, true)
        XCTAssertTrue(fields["referralCode"] is NSNull)
        XCTAssertNil(json["metadata"] as? [String: String])
    }

    func testEmptyBodyIsAnAcceptedSubmit() {
        if case .accepted(let result) = FormSubmitParser.parse(Data()) {
            XCTAssertNil(result.accountId)
        } else {
            XCTFail("empty body should be success")
        }
    }

    func testEnvelopeSuccessCarriesAccountAndToken() throws {
        let data = Data("""
        {"data":{"accountId":"32212b00-54d0-449e-877a-f712f0976823","message":"User Created Successfully.","status":"Success.","partialRegistrationStatus":1,"complianceResponse":{"complianceStatus":512,"requiredComplianceStatus":1,"isValidId":true,"message":"Auto FICA Verification Failed","accessToken":"act-jwt-x"}},"isSuccessful":true,"error":null,"metadata":null,"httpStatusCode":200}
        """.utf8)
        guard case .accepted(let result) = FormSubmitParser.parse(data) else {
            return XCTFail("expected accepted")
        }
        XCTAssertEqual(result.accountId, "32212b00-54d0-449e-877a-f712f0976823")
        XCTAssertEqual(result.message, "User Created Successfully.")
        XCTAssertEqual(result.partialRegistrationStatus, 1)
        XCTAssertTrue(result.isPartial)
        XCTAssertEqual(result.compliance?.accessToken, "act-jwt-x")
        XCTAssertEqual(result.compliance?.isValidId, true)
    }

    func testHTTP200WithIsSuccessfulFalseIsARejection() {
        let data = Data("""
        {"data":null,"isSuccessful":false,"error":{"code":153008,"displayCode":153008,"message":"An Error Occurred.","remediation":null,"additionalInformation":null,"properties":null},"metadata":null,"httpStatusCode":200}
        """.utf8)
        guard case .rejected(let error) = FormSubmitParser.parse(data) else {
            return XCTFail("HTTP 200 with isSuccessful false must not be treated as success")
        }
        XCTAssertEqual(error?.code, 153008)
        XCTAssertEqual(error?.message, "An Error Occurred.")
    }

    /// A gateway page served with status 200, or JSON of some other shape, is not a
    /// registered account.
    func testABodyThatIsNotTheEnvelopeIsARejection() {
        for body in ["<html>Access denied</html>", "{}", "[]", #"{"httpStatusCode":200}"#] {
            guard case .rejected(let error) = FormSubmitParser.parse(Data(body.utf8)) else {
                return XCTFail("\(body) must not read as success")
            }
            XCTAssertNil(error, body)
        }
    }

    private static let sample = FormSubmission(
        formCodeName: .registration,
        values: [
            "username": .text("849134302"),
            "terms": .bool(true),
            "referralCode": .empty,
        ],
        formId: "1052",
        submittedAt: Date(timeIntervalSince1970: 0)
    )
}

final class FormRepositoryOperationTests: XCTestCase {

    func testStubServesTheBundledForm() async throws {
        let repo = StubFormRepository(forms: BundledForms.all, delay: 0)
        let form = try await repo.form(named: .registration)
        XCTAssertEqual(form.id, 1052)
    }

    func testStubReportsAnUnknownFormAsNotFound() async {
        let repo = StubFormRepository(forms: BundledForms.all, delay: 0)
        do {
            _ = try await repo.form(named: FormName("deposit"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError, .notFound(FormName("deposit")))
        }
    }

    func testStubSubmitSucceeds() async throws {
        let repo = StubFormRepository(forms: [:], delay: 0)
        let submission = FormSubmission(formCodeName: .registration, values: [:], formId: "1052")
        let submitted = try await repo.submitForm(submission)
        XCTAssertNil(submitted.accountId)
    }

    func testRemoteSubmitPostsToCronAndReadsTheEnvelope() async throws {
        let client = ScriptedApiClient(data: Data(#"{"isSuccessful":true,"data":{"accountId":"abc"}}"#.utf8))
        let repo = RemoteFormRepository(apiClient: client)
        let result = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:], formId: "1"))
        XCTAssertEqual(result.accountId, "abc")
        XCTAssertEqual(client.lastPath, "forms/submit")
    }

    func testRemoteSubmitThrowsOnLogicalFailureDespiteHTTP200() async {
        let body = #"{"isSuccessful":false,"error":{"code":153008,"message":"An Error Occurred."}}"#
        let repo = RemoteFormRepository(apiClient: ScriptedApiClient(data: Data(body.utf8)))
        do {
            _ = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:]))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError, .server(message: "An Error Occurred."))
        }
    }

    func testRemoteSubmitLocalisesErrorCodes() async {
        let localizer = ClosureLocalizer({ _ in nil }, errorCode: { code in
            code == 153008 ? "The ID or Passport Number Provided Is Invalid" : nil
        })
        let body = #"{"isSuccessful":false,"error":{"code":153008,"message":"An Error Occurred."}}"#
        let repo = RemoteFormRepository(
            apiClient: ScriptedApiClient(data: Data(body.utf8)),
            localizer: localizer
        )
        do {
            _ = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:]))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError,
                           .server(message: "The ID or Passport Number Provided Is Invalid"))
        }
    }

    func testRemoteSubmitMapsTransportErrors() async {
        let repo = RemoteFormRepository(
            apiClient: ScriptedApiClient(error: APIError.transport(.notConnectedToInternet))
        )
        do {
            _ = try await repo.submitForm(FormSubmission(formCodeName: .registration, values: [:]))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? FormLoadError, .offline)
        }
    }
}

/// Records the last endpoint and returns scripted bytes. Fetch methods are unused in submit tests.
final class ScriptedApiClient: ApiClient, @unchecked Sendable {
    var data: Data
    var error: (any Error)?
    private(set) var lastPath: String?

    init(data: Data = Data(), error: (any Error)? = nil) {
        self.data = data
        self.error = error
    }

    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response {
        throw APIError.unexpectedStatus(404, nil)
    }

    func request(_ endpoint: some APIEndpoint) async throws {
        if let error { throw error }
    }

    func requestData(_ endpoint: some APIEndpoint) async throws -> Data {
        lastPath = endpoint.path
        if let error { throw error }
        return data
    }

    func requestConditional(_ endpoint: some APIEndpoint,
                           validators: HTTPValidators?) async throws -> ConditionalResponse {
        throw APIError.unexpectedStatus(404, nil)
    }
}
```

**75.**

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotForms

`JackpotFormsTests: Executed 83 tests, with 0 failures`

Open `DynamicFormView.swift` and resume the whole-form previews, including
**Registration — from JSON**, **Offline** and **Unknown form — 404**.

---

## PR 4 — JackpotRegistration

The feature: a registration service, the Sign Up sheet that drives the two-page form, the
rules registration adds to the generic engine, and the `UIHostingController` the existing
popup container can hold as-is.

**76.**

```bash
mkdir -p JackpotKit/Sources/JackpotRegistration
mkdir -p JackpotKit/Tests/JackpotRegistrationTests
```

**77.** `JackpotKit/Sources/JackpotRegistration/RegistrationService.swift`

```swift
import Foundation
import JackpotForms

/// What happens to the collected form values. The engine hands us a `FormSubmission`; this
/// turns it into an account.
public protocol RegistrationService: Sendable {
    func register(_ submission: FormSubmission) async throws -> RegistrationResult
}

/// What the app needs afterwards: an account, an optional session token, and whether FICA still
/// needs a manual upload.
public struct RegistrationResult: Equatable, Sendable {
    public let accountId: String?
    public let accessToken: String?
    public let partialRegistrationStatus: Int?
    public let isValidId: Bool?
    public let message: String?
    public let complianceMessage: String?

    public init(accountId: String?,
                accessToken: String? = nil,
                partialRegistrationStatus: Int? = nil,
                isValidId: Bool? = nil,
                message: String? = nil,
                complianceMessage: String? = nil) {
        self.accountId = accountId
        self.accessToken = accessToken
        self.partialRegistrationStatus = partialRegistrationStatus
        self.isValidId = isValidId
        self.message = message
        self.complianceMessage = complianceMessage
    }

    public init(_ submit: FormSubmitResult) {
        self.init(
            accountId: submit.accountId,
            accessToken: submit.compliance?.accessToken,
            partialRegistrationStatus: submit.partialRegistrationStatus,
            isValidId: submit.compliance?.isValidId,
            message: submit.message,
            complianceMessage: submit.compliance?.message
        )
    }

    /// Account exists but auto-FICA didn't finish — `jpc-partially-complete-profile`.
    public var isPartial: Bool { (partialRegistrationStatus ?? 0) != 0 }
}

/// Succeeds after a short delay, and fails if the mobile is `"0000000000"` — enough to demo
/// both paths and to drive previews and tests.
public struct MockRegistrationService: RegistrationService {
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.6) { self.delay = delay }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if submission["username"].stringValue == "0000000000" {
            throw RegistrationError.mobileAlreadyRegistered
        }
        return RegistrationResult(
            accountId: "27\(submission["username"].stringValue)",
            accessToken: "mock-token",
            message: "User Created Successfully."
        )
    }
}

/// Posts through `FormRepository.submitForm` and maps the envelope into a result.
public struct RemoteRegistrationService: RegistrationService {
    private let repository: any FormRepository

    public init(repository: any FormRepository) { self.repository = repository }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        do {
            return RegistrationResult(try await repository.submitForm(submission))
        } catch let error as FormLoadError {
            throw RegistrationError(error)
        }
    }
}

/// User-facing failures. `LocalizedError` because that's what the form engine displays.
public enum RegistrationError: LocalizedError, Equatable {
    case mobileAlreadyRegistered
    case offline
    case server(message: String)
    case unexpected

    init(_ error: FormLoadError) {
        switch error {
        case .offline:              self = .offline
        case .server(let message):  self = .server(message: message)
        case .notFound, .unexpected:
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

**78.** `JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift`

`RegistrationDependencies` applies `applyingRegistrationRules()` — the ID-type link and
the 18-year date cap — to whatever `forms` it is given. `RegistrationView` is the Sign Up
sheet: it owns the `DynamicFormModel`, puts `DynamicFormContent` inside `JackpotPanel`, and
fills the footer with the login row and `FormNavigationBar`, with `onClose` for the
header and `onLogin` for the row.

```swift
import SwiftUI
import JackpotUI
import JackpotForms

/// Everything the feature needs, supplied by the app at the one place it's presented.
public struct RegistrationDependencies {
    /// How the schema is fetched and localised — `.mock(localizer:)` until networking lands,
    /// `.live(baseURL:localizer:)` after — with registration's own rules applied on top.
    public let forms: FormDependencies
    /// What to do with the values once they validate.
    public let service: any RegistrationService
    public let theme: JackpotTheme

    public init(forms: FormDependencies,
                service: any RegistrationService,
                theme: JackpotTheme = .jackpotCity) {
        self.forms = forms.applyingRegistrationRules()
        self.service = service
        self.theme = theme
    }

    /// Bundled schema, mock service — works with no backend and no app.
    ///
    /// - Parameter localizer: the app's existing translation function, wrapped:
    ///   `ClosureLocalizer { key in … getTranslation(Key: key) … }`. Nil → bundled placeholder copy.
    public static func mock(localizer: (any FormLocalizing)? = nil) -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock(localizer: localizer), service: MockRegistrationService())
    }
}

extension FormDependencies {
    /// What registration adds to the generic engine: the ID-type dropdown decides which regex
    /// the ID-number field validates against, and the date-of-birth picker cannot select an
    /// under-18 date. The form's only other age gate is the terms checkbox, so the cap is a
    /// cheap second line of defence.
    func applyingRegistrationRules(now: Date = Date()) -> FormDependencies {
        var rules = self
        rules.regexDependencies = ["idNumberType": "idNumber"]
        rules.maximumDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: -18, to: now)
        return rules
    }
}

/// The Sign Up sheet as the app presents it: the two-page schema-driven form inside a
/// `JackpotPanel`, with the close button in the header and, in the footer, the login row with
/// Previous / Next / Sign Up beneath it.
///
/// The shell's copy ("Sign Up", "Already have an account?", "Login") is not in the CRM schema,
/// so it is fixed here like the Next / Previous labels are, until the app-data keys are known.
public struct RegistrationView: View {
    private let dependencies: RegistrationDependencies
    private let onClose: () -> Void
    private let onLogin: () -> Void
    private let onComplete: (RegistrationResult) -> Void
    @StateObject private var model: DynamicFormModel

    /// - Parameters:
    ///   - onClose: the header's close button.
    ///   - onLogin: the footer's "Already have an account? Login" row.
    ///   - onComplete: the account was created; route to OTP, login or home.
    public init(dependencies: RegistrationDependencies,
                onClose: @escaping () -> Void,
                onLogin: @escaping () -> Void,
                onComplete: @escaping (RegistrationResult) -> Void) {
        self.dependencies = dependencies
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
                FormNavigationBar(model: model) { submission in
                    // Thrown errors render under the fields; the form stays filled in.
                    onComplete(try await dependencies.service.register(submission))
                }
            }
        }
        .jackpotTheme(dependencies.theme)
        .task { await model.load() }
    }
}
```

**79.** `JackpotKit/Sources/JackpotRegistration/RegistrationPanelController.swift`

A drop-in for the view controller PR 5 deletes: same `addChild`/`popupContainer` call site,
SwiftUI behind it.

```swift
import UIKit
import SwiftUI

/// Drop-in replacement for the legacy registration popup.
///
/// Hosting in a view controller — rather than handing a bare `UIView` to the existing popup
/// container — is what makes safe areas, keyboard avoidance and environment propagation work.
/// `panelView` is there for containers that still expect a `UIView`.
///
/// ```swift
/// let controller = RegistrationPanelController(
///     dependencies: .mock(localizer: legacyLocalizer),
///     onClose: { popupContainer.dismiss() },
///     onLogin: { popupContainer.dismiss(); presentLogin() }
/// ) { result in
///     // route to OTP / login / home
/// }
/// addChild(controller)
/// popupContainer.show(controller.view)
/// controller.didMove(toParent: self)
/// ```
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

    /// For legacy containers that take a `UIView`. The controller must still be added as a
    /// child of whatever presents it.
    public var panelView: UIView { view }
}
```

**80.** `JackpotKit/Sources/JackpotRegistration/Previews.swift`

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

            // What the app does during the migration: its own translation function, wrapped.
            Page(dependencies: .mock(localizer: ClosureLocalizer { key in
                ["username": "Enter Mobile Number", "password": "Password", "email": "Email"][key]
            }))
            .preferredColorScheme(.dark)
            .previewDisplayName("Sign Up — app localizer")

            Page(dependencies: .init(forms: .mock(delay: 3600), service: MockRegistrationService()))
                .preferredColorScheme(.dark)
                .previewDisplayName("Loading")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

**81.** `JackpotKit/Tests/JackpotRegistrationTests/RegistrationServiceTests.swift`

```swift
import XCTest
@testable import JackpotRegistration
import JackpotForms

final class RegistrationServiceTests: XCTestCase {

    private func submission(mobile: String) -> FormSubmission {
        FormSubmission(formCodeName: .registration, values: ["username": .text(mobile), "terms": .bool(true)])
    }

    func testMockSucceedsAndReturnsAnAccount() async throws {
        let result = try await MockRegistrationService(delay: 0).register(submission(mobile: "849134302"))
        XCTAssertEqual(result, RegistrationResult(
            accountId: "27849134302",
            accessToken: "mock-token",
            message: "User Created Successfully."
        ))
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

    /// The form engine displays `LocalizedError.errorDescription`; every case must have one.
    func testEveryErrorHasUserFacingCopy() {
        let cases: [RegistrationError] = [.mobileAlreadyRegistered, .offline, .server(message: "x"), .unexpected]
        for c in cases { XCTAssertFalse((c.errorDescription ?? "").isEmpty, "\(c)") }
    }

    func testFormLoadErrorsMapToRegistrationErrors() {
        XCTAssertEqual(RegistrationError(FormLoadError.offline), .offline)
        XCTAssertEqual(RegistrationError(FormLoadError.server(message: "x")), .server(message: "x"))
        XCTAssertEqual(RegistrationError(FormLoadError.notFound(.registration)), .unexpected)
    }

    func testRemoteServicePostsThroughTheRepository() async throws {
        let result = try await RemoteRegistrationService(repository: FakeFormRepository(success: true))
            .register(submission(mobile: "849134302"))
        XCTAssertEqual(result.accountId, "abc")
        XCTAssertEqual(result.accessToken, "tok")
        XCTAssertTrue(result.isPartial)
    }

    func testRemoteServiceTreatsARejectedSubmitAsFailure() async {
        do {
            _ = try await RemoteRegistrationService(repository: FakeFormRepository(success: false))
                .register(submission(mobile: "849134302"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .server(message: "An Error Occurred."))
        }
    }

    func testRemoteServiceSurfacesRepositoryOffline() async {
        do {
            _ = try await RemoteRegistrationService(repository: FakeFormRepository(error: FormLoadError.offline))
                .register(submission(mobile: "849134302"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .offline)
        }
    }

    /// The migration seam: the app's `getTranslation` returns the key on a miss, and that must
    /// become nil so the engine can fall back to humanised copy.
    func testClosureLocalizerMapsKeyOnMissToNil() {
        let legacyGetTranslation: @Sendable (String) -> String = {
            $0 == "username" ? "Enter Mobile Number" : $0
        }
        let localizer = ClosureLocalizer { key in
            let value = legacyGetTranslation(key)
            return value == key ? nil : value
        }
        XCTAssertEqual(localizer.string(forKey: "username"), "Enter Mobile Number")
        XCTAssertNil(localizer.string(forKey: "dateOfBirth"))
        XCTAssertEqual(localizer.display("dateOfBirth"), "Date Of Birth")
    }
}

/// The engine ships with no cross-field links and no date cap; registration adds both, whatever
/// repository the host passes in.
final class RegistrationRulesTests: XCTestCase {

    func testRegistrationLinksIDTypeToIDNumber() {
        let dependencies = RegistrationDependencies.mock()
        XCTAssertEqual(dependencies.forms.regexDependencies, ["idNumberType": "idNumber"])
    }

    func testDateOfBirthIsCappedAtEighteenYearsAgo() throws {
        let now = Date(timeIntervalSince1970: 1_757_203_200)     // 2025-09-07
        let rules = FormDependencies.mock().applyingRegistrationRules(now: now)
        let cap = try XCTUnwrap(rules.maximumDate)
        let years = Calendar(identifier: .gregorian).dateComponents([.year], from: cap, to: now).year
        XCTAssertEqual(years, 18)
    }

    func testTheGenericEngineHasNeither() {
        let plain = FormDependencies.mock()
        XCTAssertTrue(plain.regexDependencies.isEmpty)
        XCTAssertNil(plain.maximumDate)
    }
}

private struct FakeFormRepository: FormRepository {
    var success: Bool = true
    var error: (any Error)?

    func form(named name: FormName) async throws -> FormSchema {
        throw CancellationError()
    }

    func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult {
        if let error { throw error }
        guard success else { throw FormLoadError.server(message: "An Error Occurred.") }
        return FormSubmitResult(
            accountId: "abc",
            partialRegistrationStatus: 1,
            compliance: FormComplianceResult(accessToken: "tok")
        )
    }
}
```

**82.**

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

### ▶ Create PR — JackpotRegistration

`JackpotRegistrationTests: Executed 11 tests, with 0 failures`

Open `Previews.swift` and run the flow end to end.

---

## PR 5 — Replace the current flow

**In Xcode:** File → Add Package Dependencies → Add Local… → `JackpotKit`, then add
**JackpotRegistration** to the app target's frameworks.

**83.** `Sources/Features/Registration/RegistrationPresenter.swift`

`ClosureLocalizer` is the migration seam. The app's `getTranslation` returns the key itself on
a miss; mapping that back to `nil` is what lets the engine fall through to humanised copy instead
of rendering a raw key. `MockRegistrationService` stays until the submit contract is confirmed;
`RemoteRegistrationService(repository:)` is the one-line swap.

```swift
import UIKit
import JackpotForms
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

**84.** Point every existing entry point at `presentRegistration()`:

- the header **SIGN UP** button
- the bottom bar **Sign Up** item
- `NavigationHandler` — the `registration` sitemap branch
- the Login panel's **Sign Up ›** link

**85.** Delete:

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

**86.**

```bash
grep -rn "registrationPopup\|flowOneViewController\|flowTwoViewController" --include=*.swift .
```

Expect no results.

---

### ▶ Create PR — Replace registration flow

Build and run. Open sign-up from the header and the bottom bar; complete both pages.

---
