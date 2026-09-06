# Building JackpotForms from scratch

A complete, self-contained rebuild guide. Every file, in an order that compiles, with a
numbered step for each one and a checkpoint at the end of every target.

**What you end up with:** an iOS 15+ SwiftUI package that renders CRM-authored JSON form
schemas as native, validated, multi-page forms. 5 targets, ~3,700 lines, 55 tests, 50 preview
variants, built on the `JackpotUI` design system. Networking is an optional target that arrives
two PRs later.

Read Parts 0–1 anywhere. Parts 2–8 are typing. Part 10 is the one to read before you touch the
existing app.

---

## Why this exists

The ticket:

> The form builder which is currently in web needs to be implemented on the native
> applications… manage dynamically generated forms via a json schema and render them
> wherever injected.
>
> The dynamic form should be encapsulated in a single component with effectively 2 arguments:
> **form name** (used to fetch the relevant form) and **callback** (used to handle the data).
>
> Create a testing page where we can see this in action.

So the deliverable is a **form engine**, not a Sign Up screen. Registration is its first
consumer — a `FormName` and a callback. That's why the package is `JackpotForms` and not `JackpotSignUp`:
a sign-up package would make the next form (deposit, KYC, contact-us) a second implementation
of the same thing.

The end state:

```swift
DynamicFormView(formName: .registration) { submission in
    try await auth.register(submission.stringValues)
}
.formDependencies(.live(baseURL: configURL, translations: session.translations))
```

For the registration schema that renders a two-page wizard with a progress bar, a
`+27`-prefixed mobile field, a password field with the expandable validity checklist, an
ID-type dropdown that changes what a valid ID number is, a date picker capped at 18 years ago,
a terms checkbox that must be ticked, and per-field red-border errors that appear only once
touched. None of it coded per-screen.

---

## Part 0 — The design, before you type anything

### The schema you're rendering

`GET https://config.jpc.africa/crm/forms/jackpotcity/JZA/registration?api-version=2.0` returns:

```
formId, formCodeName, formTitle, regionCode
└── sections[]        formSectionId, formSectionOrder, rows[]
    └── rows[]        rowNumber, fields[]
        └── fields[]  fieldId, fieldIdentifier, fieldType, inputType, fieldRegex,
                      isRequired, isVisible, isReadOnly, prefix, suffix,
                      fieldLabel, fieldPlaceholder, validationMessage,
                      fieldDropdowns[], fieldRadioGroup[]
```

Per the ticket: **sections page** (each is one wizard step), **rows lay out inline** (fields
sharing a row sit side by side), **fields belong to rows**. That's why the `+27` / mobile
pairing needs no special case — it's a `prefix` on one field.

### Seven decisions that shape everything

**1. Unknown field types must never throw.** Product edits the schema in a CMS *without
shipping an app build*. If an unrecognised `fieldType` failed the decode, one CRM edit would
brick registration on every installed version. `FieldType.unknown(String)` renders nothing and
gets reported. This is the single most important behaviour in the package.

**2. Server regexes are untrusted input.** `NSRegularExpression` throws on a malformed pattern —
one CRM typo would crash signup. A pattern that won't compile is treated as *no constraint* and
reported. Compiled expressions are cached, or you recompile twelve regexes per keystroke.

**3. `JackpotFormsUI` never imports `JackpotFormsData`, and `JackpotFormsData` never imports networking.** The renderer only knows the `FormRepository`
*protocol*; the mock lives in Data and the live implementation in `JackpotFormsRemote`. That's
what makes swapping mock for live a one-line change in composition, and what lets the engine and
a real registration screen ship before the networking package exists.

**4. The domain type is `FormSchema`, not `Form`.** `SwiftUI.Form` exists; the collision makes
every UI file ambiguous. I hit this during the original build. Don't "fix" it back.

**5. Form names are type-safe but the set stays open.** `FormName` is a `RawRepresentable`
wrapper, not an enum — forms are authored server-side and appear without an app release. Known
forms get static members (`.registration`); anything else is `FormName("deposit")`.

**6. The localisation table is also an error-code catalogue.** The app-data response contains
an entry keyed `6000328` whose value is the "Maximum OTP tries reached…" message, so a numeric
`code` in an API error envelope is a localisation key. `FormErrorMapper` resolves it.

**7. iOS 15 means `ObservableObject`, not `@Observable`.** And `PreviewProvider`, not
`#Preview` (that macro is `@available(iOS 17)`). Part 12 lists the upgrade seams.

### Target graph

```
  JackpotUI ◄──────────────────────────────────────── JackpotFormsUI
                                                            ▲
  JackpotFormsDomain ◄── JackpotFormsData ◄── JackpotFormsRemote ──► JackpotNetworking (JackpotCore)
          ▲                     ▲                    ▲
          └─────────────────────┴──── JackpotForms ──┘  (composition: .mock() from Data, .live() from Remote)
```

| Target | Package | Holds | Depends on |
|---|---|---|---|
| `JackpotUI` | JackpotUI | the design system — text fields, buttons, choice controls, cards, theme | — |
| `JackpotFormsDomain` | JackpotForms | entities, validation, protocols. Foundation only. | — |
| `JackpotFormsData` | JackpotForms | DTOs, mapper, **the mock repository** | Domain |
| `JackpotFormsUI` | JackpotForms | binds the model to `JackpotUI` components | Domain, JackpotUI |
| `JackpotFormsRemote` | JackpotForms | the live repository, endpoints, error mapping | Domain, Data, JackpotNetworking |
| `JackpotForms` | JackpotForms | composition — `.mock()` / `.live()` | all of the above |

The app imports **`JackpotForms`** for the form and **`JackpotUI`** for its own screens.

---

## Part 1 — Prerequisites

- Xcode 14+ (Swift 5.7), or a Swift 5.7+ toolchain for the command line
- No API access needed — the package runs mock-first
- No third-party packages

You will type files in dependency order and compile after each target.

---

## Part 2 — Create the package

#### Step 2.1 · make the folders

`Packages/JackpotUI` comes from its own README — build that first (Part 3). `Packages/JackpotCore` is
only needed for Part 5b.

```bash
mkdir -p Packages/JackpotForms/Sources/{JackpotFormsDomain,JackpotFormsData,JackpotFormsRemote,JackpotForms}
mkdir -p Packages/JackpotForms/Sources/JackpotFormsUI/{Fields,Demo,Resources}
mkdir -p Packages/JackpotForms/Tests/JackpotFormsTests/Fixtures
cd Packages/JackpotForms
```

#### Step 2.2 · create `Package.swift`

Five targets and two path dependencies. `JackpotFormsData` has **no** networking dependency; only `JackpotFormsRemote` does. `JackpotFormsUI` depends on `JackpotUI` and declares resources (the sample schemas).

```swift
// swift-tools-version: 5.7
import PackageDescription

// Renders CRM-authored JSON form schemas as native SwiftUI, on top of the JackpotUI design
// system. The mock repository has no networking dependency; the live one lives in its own
// target so the forms package can ship and be reviewed before the networking package exists.
let package = Package(
    name: "JackpotForms",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        // One product, every target: consumers add this and import the modules they use.
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
        // Entities + rules. Foundation only — no networking, no SwiftUI.
        .target(name: "JackpotFormsDomain"),

        // DTOs, mapper, and the bundled-JSON stub repository. No networking. (PR 2)
        .target(name: "JackpotFormsData", dependencies: ["JackpotFormsDomain"]),

        // SwiftUI rendering over the design system. Depends on Domain only — never on Data.
        .target(
            name: "JackpotFormsUI",
            dependencies: [
                "JackpotFormsDomain",
                .product(name: "JackpotUI", package: "JackpotUI"),
            ],
            resources: [.process("Resources")]
        ),

        // The live repository, endpoints and error mapping. The only forms target that
        // touches networking. (PR 4)
        .target(
            name: "JackpotFormsRemote",
            dependencies: [
                "JackpotFormsDomain",
                "JackpotFormsData",
                .product(name: "JackpotNetworking", package: "JackpotCore"),
            ]
        ),

        // Composition: `.mock()` and `.live()`. The only target that sees everything.
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

#### Step 2.3 · ignore build output

```bash
cat > .gitignore <<'EOF'
.build/
.swiftpm/
*.xcuserdatad
EOF
```

At this point `swift build` will fail — there are no sources yet. That's expected.

---

## Part 3 — `JackpotUI` (build this first)

The design system is a **separate package**, `JackpotUI`, and this one depends on it by path.
Its README is a complete build guide for fourteen files and a gallery preview. Build it, open the
gallery, then come back.

It is separate because a text field's *look* has nothing to do with a dynamic form's
*mechanics* — the login panel, Account Settings and the deposit flow all need the same text
field, and none of them are dynamic forms. `JackpotUI` owns the components; this package makes
them work with the schema.

`JackpotCore` (networking) is **not** needed until Part 5b. In the delivery plan it's PR 3.

```
Packages/
├── JackpotUI/            ← components. Build first. (PR 1)
├── JackpotForms/         ← this package.           (PR 2)
├── JackpotCore/          ← networking.             (PR 3)
└── JackpotRegistration/  ← the feature.            (PR 4)
```

---

## Part 4 — `JackpotFormsDomain` (10 files)

Entities and rules. Imports `Foundation` only — no networking, no SwiftUI. This is the target
that must stay clean; if it ever needs `UIKit`, something is in the wrong layer.

Order matters only in that `FormName` and `FormField` are referenced by everything else. Type
them in the order below and nothing forward-references.

#### Step 4.1 · create `Sources/JackpotFormsDomain/FormName.swift`

Type-safe form identifiers. Deliberately **not** an enum — forms are authored server-side and appear without an app release, so a closed set would fight the architecture. It's the `Notification.Name` pattern: known forms get static members, unknown ones stay constructible.

Also deliberately **not** `ExpressibleByStringLiteral` — if it were, `formName: "registraton"` would still compile and you'd be back to a runtime 404.

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

#### Step 4.2 · create `Sources/JackpotFormsDomain/Form.swift`

`FormSchema` → sections → rows → fields. Sections page, rows lay out inline. (Remember: **not** `Form` — `SwiftUI.Form` collides.)

Note `FormSection.codeName` is a plain `String` — a section's code name is `"1"`/`"2"`, not a form name.

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

#### Step 4.3 · create `Sources/JackpotFormsDomain/FormField.swift`

The heart of it. `FieldType.unknown(String)` is decision #1 from Part 0 — load-bearing, not defensive padding. `InputType` accepts both `"Calender"` (the schema's spelling) and `"Calendar"`, so a server-side fix can't silently downgrade every date field to a text box.

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

#### Step 4.4 · create `Sources/JackpotFormsDomain/FormValue.swift`

Every case renders as a string because the schema validates with regexes — including checkboxes, whose patterns are literally `^true$`. So `stringValue` is both what gets validated and what gets submitted. `.bool(false)` counts as *empty*, which is what makes a required `terms` checkbox behave.

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

#### Step 4.5 · create `Sources/JackpotFormsDomain/RegexResolving.swift`

Dropdown options carry a `regex` that is sometimes a pattern (`"[a-zA-Z]"`) and sometimes a **name** (`"idNumberRegex"`). This resolves names; the `looksLikeRegexPattern` heuristic tells the two apart. **An assumption** — see Part 11.

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

#### Step 4.6 · create `Sources/JackpotFormsDomain/FieldValidator.swift`

Decision #2 from Part 0. Order: skip decorative → required-and-empty fails → **optional-and-empty short-circuits before the regex** (this is what makes optional mean optional) → regex match. A pattern that won't compile is no constraint, never a crash. Compiled expressions are cached behind a lock.

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

#### Step 4.7 · create `Sources/JackpotFormsDomain/PasswordPolicy.swift`

Parses `{8,20}` out of the password regex to produce the two checklist rules in the design. **An assumption** — the schema has one regex but the web UI shows two independently ticking rules. See Part 11.

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

#### Step 4.8 · create `Sources/JackpotFormsDomain/FormLoadError.swift`

Why a form couldn't load, in words a person can read.

This exists because `JackpotFormsUI` depends on Domain only — never on `JackpotNetworking` — so `APIError` cannot reach a view model. That's the layering working, but it means the server's own wording would be decoded, carried all the way up, and then discarded for a generic string. `FormErrorMapper` in the Data layer is the translation point.

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

#### Step 4.9 · create `Sources/JackpotFormsDomain/FormRepository.swift`

Two lines. This protocol is the entire seam between rendering and fetching — it's why mock↔live is a one-line swap.

```swift
import Foundation

/// Fetches a form definition by name.
/// Implementation lives in JackpotFormsData; the UI only ever sees this.
public protocol FormRepository: Sendable {
    func form(named name: FormName) async throws -> FormSchema
}
```

#### Step 4.10 · create `Sources/JackpotFormsDomain/FormLocalizing.swift`

The schema ships **keys**, not text. Unresolved keys fall back to a humanised key (`"dateOfBirth"` → `"Date Of Birth"`) so a missing string is visible in QA rather than blank.

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

**✓ Checkpoint 4**

```bash
swift build --target JackpotFormsDomain
```

Expected:

```
Build complete!
```

If it doesn't compile, fix it before moving on — later errors cascade and become much harder
to read.

---

## Part 5 — `JackpotFormsData` (3 files) — the mock

Wire shapes, the mapping to domain, and a repository that serves bundled JSON.
**No networking dependency.** This is what lets PR 2 ship — and PR 3 put a real registration
screen on a device — before the networking package exists.

Every DTO field is optional except the identifiers you can't render without. The schema is
edited by product in a CMS; a missing `prefix` must not fail the whole decode.

#### Step 5.1 · create `Sources/JackpotFormsData/FormDTO.swift`

Exactly what the CRM sends. `public` so the Remote target (Part 5b) can decode the same shape.

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

#### Step 5.2 · create `Sources/JackpotFormsData/FormMapper.swift`

DTO → domain, with fail-safe defaults: an unspecified field is optional and visible, not silently blocking. Sections and rows are sorted here, so the UI never has to.

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

#### Step 5.3 · create `Sources/JackpotFormsData/StubFormRepository.swift`

Serves the captured `registration.json`. This is the **mock interface** — the same `FormRepository` protocol the live implementation satisfies in Part 5b, so swapping them is one line in composition.

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

**✓ Checkpoint 5**

```bash
swift build --target JackpotFormsData
```

Expected:

```
Build complete!
```

If it doesn't compile, fix it before moving on — later errors cascade and become much harder
to read.

---

## Part 5b — `JackpotFormsRemote` (4 files) — the live repository *(PR 3)*

The only forms target that touches networking. Depends on `JackpotNetworking` from
`JackpotCore` — build that package first (its README is a full guide) before this part.

In the delivery plan this target arrives in **PR 3**, one PR after the rest of the forms
package. That's the point of the split: the engine and the mock are reviewable and demonstrable before
any of this exists.

#### Step 5b.1 · create `Sources/JackpotFormsRemote/CRMEnvironment.swift`

The CRM config service's calling convention: `api-version=2.0` on every request.

This deliberately does **not** live in `JackpotCore`. A networking layer that names `config.jpc.africa` is not generic, it just hasn't been asked to serve a second host yet. The knowledge belongs next to `FormRequest`, which already encodes the rest of the same contract.

```swift
import Foundation
import JackpotNetworking

// The CRM config service's calling convention.
//
// This used to live on `APIEnvironment` in JackpotCore, which was wrong for the same reason the
// reference project's `APIEndpoint.asURLRequest()` splicing in `StackExchangeRequest
// .commonQueryItems()` was wrong: it bakes one service's identity into a type that is meant
// to describe *any* service. A generic networking layer that names `config.jpc.africa` is
// not generic — it just hasn't been asked to serve a second host yet.
//
// The knowledge belongs next to `FormRequest`, which already encodes the rest of the same
// contract (the `forms/{brand}/{region}/{name}` path shape).

public extension APIEnvironment {

    /// The JackpotCity CRM config service — `https://config.jpc.africa/crm`.
    ///
    /// `api-version` is a query item on every call, not a header, and applies to the whole
    /// service rather than to the forms resource. Pass the version explicitly when the CRM
    /// moves on; the default tracks whatever the forms endpoint currently expects.
    ///
    /// If another feature starts talking to the same CRM, promote this to a shared target —
    /// don't copy it.
    static func crm(baseURL: URL, apiVersion: String = "2.0") -> APIEnvironment {
        APIEnvironment(
            baseURL: baseURL,
            defaultHeaders: ["Accept": "application/json"],
            defaultQueryItems: [URLQueryItem(name: "api-version", value: apiVersion)]
        )
    }
}
```

#### Step 5b.2 · create `Sources/JackpotFormsRemote/FormEndpoints.swift`

`GET {base}/forms/{brand}/{region}/{formName}`. The version query item comes from the environment, not from here.

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain

/// GET {base}/forms/{brand}/{region}/{formCodeName}?api-version=2.0
///
/// The ticket's example call is
/// `https://config.jpc.africa/crm/forms/jackpotcity/JZA/registration?api-version=2.0`,
/// so brand and region are path components and the version is an environment-wide
/// query item (see `APIEnvironment.crm(baseURL:)` in this target).
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

#### Step 5b.3 · create `Sources/JackpotFormsRemote/FormErrorMapper.swift`

`APIError` → `FormLoadError`, at the layer boundary.

Resolution order: **localised copy for the error code** (via the `FormLocalizing` protocol from Domain, so this target needs no localisation dependency), then the server's own `message`, then ours. Note `.cancelled` maps to `CancellationError` — a cancelled load is a navigation event, not a failure, and must never reach the user.

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain

// The translation boundary. `JackpotFormsUI` never sees `APIError`, so this is where transport
// concerns become something a person can read.
//
// Order matters: the server's own message wins over anything we'd write, because it is the
// only party that knows *why* — "Mobile number already registered" is worth more than any
// generic string we could substitute.
enum FormErrorMapper {

    /// - Parameter localizer: resolves an error `code` to localised copy when the session's
    ///   table carries one. That beats `problem.message`, which arrives in whatever language
    ///   the API defaulted to. Depends on the Domain protocol rather than on a concrete
    ///   translation table, so this target ships without a localisation dependency.
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
            // Localised copy for the code first, then whatever the server wrote, then ours.
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

#### Step 5b.4 · create `Sources/JackpotFormsRemote/RemoteFormRepository.swift`

The live `FormRepository`. Same protocol as the stub; composition picks one.

```swift
import Foundation
import JackpotNetworking
import JackpotFormsData
import JackpotFormsDomain

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
            let dto: FormDTO = try await apiClient.request(
                FormRequest(brand: brand, region: region, formName: name)
            )
            return FormMapper.map(dto)
        } catch {
            // Translate here, at the layer boundary — the UI can't see APIError.
            throw FormErrorMapper.map(error, formName: name, localizer: localizer)
        }
    }
}
```

**✓ Checkpoint 5b**

```bash
swift build --target JackpotFormsRemote
```

Expected:

```
Build complete!
```

If it doesn't compile, fix it before moving on — later errors cascade and become much harder
to read.

---

## Part 6 — `JackpotFormsUI` (14 files)

The renderer, built on `JackpotUI`. Every field view here is thin: it reads the model, hands a
binding to a `JackpotUI` component, and calls `markTouched` when the component reports an edit
ended. The components never learn what a form is.

**One caveat on ordering.** This target's files are mutually referential: `FormRowView` →
`FieldRenderer` → the field views → back to `DynamicFormBody` in `DynamicFormView.swift`. That's fine inside one module, but it means **there is no useful
intermediate compile check.** Type all sixteen files, then build once at the end of Part 6.

Within the part, order still matters in one place: `PreviewFixtures` comes before the field
views, because their previews depend on it.

### 6a — Foundations

#### Step 6.1 · create `Sources/JackpotFormsUI/FormDependencies.swift`

Repository, validator, localizer, password policy — injected through the environment. This is what keeps the public call site at the two arguments the ticket asks for while nothing hides in a global. The default value asserts rather than silently rendering an empty form.

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

#### Step 6.2 · create `Sources/JackpotFormsUI/DynamicFormModel.swift`

The engine: values, touched state, errors, paging, progress, submit. `ObservableObject` because iOS 15.

Three things worth reading closely:

- **`markTouched`** — errors are suppressed until a field is touched, and `advance()`/`submit()` mark everything in scope at once. That's the web behaviour in the designs.
- **`overrideRegex(for:)`** — the ID-type → ID-number dependency. A dropdown option whose regex is a *name* overrides the **next** field's pattern.
- **The `#if DEBUG` preview factory at the bottom** must live in this file: `apply(_:)` is `private`, and `private` in Swift is file-scoped, so an extension here can seed a model without widening the real API.

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

    // MARK: Inputs
    private let formName: FormName
    private var dependencies: FormDependencies
    private var isConfigured: Bool
    private var touched: Set<String> = []
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
    public func markTouched(_ field: FormField) {
        touched.insert(field.identifier)
        objectWillChange.send()
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

    // MARK: Submitting

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

#### Step 6.3 · create `Sources/JackpotFormsUI/Demo/PreviewFixtures.swift`

Hand-built fixtures mirroring the real schema. (`JackpotPreviewPanel` from `JackpotUI` is the preview surface.) Built in Swift rather than decoded, because `JackpotFormsUI` has no decoder (decision #3) — and previews that don't touch the bundle render faster and can't fail on a missing resource.

Type this **before** the field views: their previews depend on it.

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

### 6b — Field components

One file per `fieldType`. Each follows the same shape: read `model.value(for: field)`, write
through `model.setValue(_:for:)`, call `model.markTouched(field)` on blur or selection, and
show `model.error(for: field)` beneath.

#### Step 6.4 · create `Sources/JackpotFormsUI/Fields/FieldRenderer.swift`

The switch that **is** the contract between the CRM and the app, plus the `DynamicFormModel` binding helpers (`text(for:)`, `selection(for:)`, `bool(for:)`, `date(for:)`, `options(for:)`) that every field view uses to hand a `JackpotUI` component a `Binding`.

Note `.unknown` renders `EmptyView()` — decision #1.

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
        case .textArea:                 TextAreaFieldView(field: field, model: model)
        case .dropdown:                 DropdownFieldView(field: field, model: model)
        case .checkbox:                 CheckboxFieldView(field: field, model: model)
        case .toggle:                   ToggleFieldView(field: field, model: model)
        case .radio, .radioGroup:       RadioGroupFieldView(field: field, model: model)
        case .divider:                  JackpotDivider()
        case .welcomeOffer:             WelcomeOfferFieldView(field: field, model: model)
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
            .font(.caption)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .jackpotFieldBorder(isInvalid: false)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Shared bindings

extension DynamicFormModel {
    /// Text binding for a field, writing back as `.text`.
    func text(for field: FormField) -> Binding<String> {
        Binding(get: { self.value(for: field).stringValue },
                set: { self.setValue(.text($0), for: field) })
    }

    /// Selection binding for dropdowns and radio groups. An empty selection is `.option("")`.
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

#### Step 6.5 · create `Sources/JackpotFormsUI/Fields/InputFieldView.swift`

Binds `JackpotTextField` — and, for password fields, `JackpotChecklist` — to the model. The `prefix` cell renders `+27` from the schema, not from a hardcoded South Africa assumption. Maps `inputType` to `UIKeyboardType` and the field identifier to `UITextContentType` for autofill.

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
                        prefix: field.prefix,              // "+27" comes from the schema
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

#### Step 6.6 · create `Sources/JackpotFormsUI/Fields/DropdownFieldView.swift`

`Menu`-based. Options come from `fieldDropdowns`; the displayed text is a localization key.

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

#### Step 6.7 · create `Sources/JackpotFormsUI/Fields/CheckboxFieldView.swift`

Checkbox and toggle. Values validate as the strings `"true"` / `"false"`.

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

#### Step 6.8 · create `Sources/JackpotFormsUI/Fields/RadioGroupFieldView.swift`

From `fieldRadioGroup`. 44pt minimum row height for the tap target.

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

#### Step 6.9 · create `Sources/JackpotFormsUI/Fields/DateFieldView.swift`

`inputType: "Calender"`. Serialises through ISO-8601 because the `dateOfBirth` regex expects a date-*time*. The picker is capped at 18 years ago — the form's only age gate is the T&C checkbox, so this is a cheap second line of defence.

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
        JackpotLabeledField(label: model.localized(field.labelKey), error: model.error(for: field)) {
            JackpotDateField(
                model.localized(field.placeholderKey),
                title: model.localized(field.labelKey),
                date: model.date(for: field),
                // The form's only age gate is the T&C checkbox; capping the picker stops an
                // under-18 date being entered at all.
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

#### Step 6.10 · create `Sources/JackpotFormsUI/Fields/TextAreaFieldView.swift`

`TextEditor` has no placeholder on iOS 15, hence the overlay.

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

#### Step 6.11 · create `Sources/JackpotFormsUI/Fields/WelcomeOfferFieldView.swift`

Locked until `model.isFormValid` — not a flag, which is why filling the form unlocks it exactly as the real one does. **Note:** there is no `welcomeOffer` field in the registration payload; see Part 11.

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// "Welcome Offer" is a first-class field type in the builder's type list. Options come from
/// `fieldDropdowns`; the picker unlocks with `model.isFormValid`, matching the design.
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

### 6c — The component

#### Step 6.12 · create `Sources/JackpotFormsUI/DynamicFormView.swift`

The two-argument public API, `DynamicFormBody` (the rendered form for a given model — previews drive it without a fetch), `FormRowView`, `FormNavigationBar`, and the whole-form previews. All chrome comes from `JackpotUI`.

The `configureIfNeeded` dance in `init` exists because `@StateObject` can't read `@Environment` from an initializer — the real dependencies are swapped in on first appearance. That goes away on iOS 17.

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


// MARK: - Previews

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

### 6d — Demo and resources

#### Step 6.13 · create `Sources/JackpotFormsUI/Demo/PreviewSupport.swift`

The placeholder localization table mapping the schema's keys to the copy in the designs, plus bundled-JSON access. `Bundle.module` is internal, so it can't be a public default argument — hence the explicit overload.

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

#### Step 6.14 · create `Sources/JackpotFormsUI/Demo/FormSandboxView.swift`

The testing page the ticket asks for: pick a form, fill it, inspect exactly what the callback received.

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

#### Step 6.15 · create `Sources/JackpotFormsUI/Resources/registration.json`

The real captured response, verbatim. This is your mock until the endpoint is wired up.

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

#### Step 6.16 · create `Sources/JackpotFormsUI/Resources/kitchenSink.json`

Every supported field type, plus one deliberately unknown (`"SignaturePad"`) so you can see decision #1 working.

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

**✓ Checkpoint 6**

```bash
xcodebuild -scheme JackpotForms -destination 'generic/platform=iOS' build
```

Expected:

```
BUILD SUCCEEDED
```

If it doesn't compile, fix it before moving on — later errors cascade and become much harder
to read.

---

## Part 7 — `JackpotForms` composition (3 files)

The composition target — the only one that sees Data **and** UI. Your app imports this and
nothing else.

#### Step 7.1 · create `Sources/JackpotForms/TranslationsLocalizer.swift`

The join between the app's session-wide translation table (`JackpotLocalization`) and the engine's `FormLocalizing` seam. An adapter rather than a retroactive conformance. Arrives with the localisation follow-up.

```swift
import Foundation
import JackpotLocalization
import JackpotFormsDomain

/// Adapts the app's session-wide `Translations` table to the form engine's `FormLocalizing`
/// seam.
///
/// An adapter rather than `extension Translations: FormLocalizing`, for two reasons:
///
/// 1. Neither type is ours — `Translations` lives in `JackpotLocalization`, `FormLocalizing` in
///    `JackpotFormsDomain` — so a conformance would be *retroactive*, which Swift 6 warns about and
///    which breaks if either module later declares its own.
/// 2. It makes the region policy explicit and visible in one place rather than buried in a
///    conformance somebody has to go looking for.
///
/// `JackpotFormsUI` still only ever sees the protocol, so the renderer stays previewable with a
/// fixed table.
public struct TranslationsLocalizer: FormLocalizing {

    private let translations: Translations

    public init(_ translations: Translations) {
        self.translations = translations
    }

    /// The schema hands the renderer keys, not text: `fieldLabel: "username"`,
    /// `fieldDropdowns[].text: "jpc-reg-idnumber"`, and — already region-suffixed —
    /// `fieldLabel: "receivePromotionalInformation-jza"`.
    ///
    /// `regional: true` covers both shapes: a plain key picks up its `-jza` override when one
    /// exists, and a pre-suffixed key resolves directly.
    public func string(forKey key: String) -> String? {
        translations.string(forKey: key, regional: true)
    }

    /// The table doubles as an error-code catalogue.
    public func message(forErrorCode code: Int) -> String? {
        translations.message(forErrorCode: code)
    }
}

public extension FormLocalizing where Self == TranslationsLocalizer {
    /// `.translations(session.translations)` at a call site expecting a localizer.
    static func translations(_ table: Translations) -> TranslationsLocalizer {
        TranslationsLocalizer(table)
    }
}
```

#### Step 7.2 · create `Sources/JackpotForms/JackpotForms.swift`

`.mock()` (PR 2) and `.live()` (PR 3). The `@_exported import`s are what let the app get the whole API from one import. Note `.live(translations:)` falls back to bundled placeholder copy when the table is empty, so a form still renders legibly before app-data lands.

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain
import JackpotFormsUI
import JackpotLocalization
import JackpotFormsData
import JackpotFormsRemote

// The composition target: the one place that knows both how forms are fetched (Data)
// and how they are rendered (UI). Everything else stays one-directional.
//
// Consumers import the modules they actually use — JackpotFormsDomain for types, JackpotFormsUI
// for the view, JackpotForms for .mock()/.live(). All are vended by the JackpotForms product.

public extension FormDependencies {

    /// **Mock-first, and the default while the endpoint is not wired up.**
    /// Serves the real `registration` schema captured from
    /// `config.jpc.africa/crm/forms/jackpotcity/JZA/registration?api-version=2.0`
    /// out of the package bundle, so the whole feature is buildable and reviewable
    /// before the API is reachable from the app.
    ///
    ///     DynamicFormView(formName: .registration) { ... }
    ///         .formDependencies(.mock())
    ///
    /// - Parameters:
    ///   - delay: fake latency, so loading states are visible in the sandbox.
    ///   - error: set to exercise the failure state.
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

    /// The real thing. Swap `.mock()` for this at the call site — nothing else changes,
    /// because `DynamicFormView` only ever sees the `FormRepository` protocol.
    ///
    ///     .formDependencies(.live(baseURL: URL(string: "https://config.jpc.africa/crm")!))
    /// - Parameter translations: the session's locale table, from the once-per-session
    ///   app-data call. Supplying it makes the form resolve its labels, placeholders and
    ///   dropdown options through the real CRM copy, and turns API error *codes* into
    ///   localised sentences. Omit it and the form falls back to bundled placeholder copy.
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
            environment: .crm(baseURL: baseURL),
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

public extension FormSandboxView {
    /// The testing page the ticket asks for, wired to the bundled schemas.
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

#### Step 7.3 · create `Sources/JackpotForms/Previews.swift`

JSON-backed previews. These go through the real decoder, so a schema change breaks a preview instead of surfacing at runtime — the hand-built fixtures in Part 6a wouldn't catch that.

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsData
import JackpotNetworking
import JackpotFormsUI

/// JSON-backed previews — these go through the real decoder against the captured
/// `registration.json`, so they catch a schema change that the hand-built fixtures in
/// `JackpotFormsUI` would not. This is the only target that can see both layers.
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

**✓ Checkpoint 7**

```bash
xcodebuild -scheme JackpotForms -destination 'generic/platform=iOS' build
```

Expected:

```
BUILD SUCCEEDED
```

If it doesn't compile, fix it before moving on — later errors cascade and become much harder
to read.

---

## Part 8 — Tests (4 files)

61 tests, ~0.1s. They cover the parts that are pure and load-bearing; there are no view tests —
the 50 preview variants cover the state matrix at lower cost.

#### Step 8.1 · create `Tests/JackpotFormsTests/Fixtures/registration.json`

Same payload as the UI resource. Duplicated deliberately: the test target shouldn't reach into another target's bundle.

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

#### Step 8.2 · create `Tests/JackpotFormsTests/FormDecodingTests.swift`

Decoding, `FormName`, the CRM URL, error mapping and the localisation join. Six suites in one file.

The most important single test is `testUnknownFieldTypeDoesNotFailTheDecode` — that's decision #1, and it's the one that stops a CRM edit bricking registration on shipped builds.

```swift
import XCTest
@testable import JackpotFormsData
@testable import JackpotFormsRemote
import JackpotFormsDomain
import JackpotNetworking
import JackpotLocalization
import JackpotForms

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

final class CRMEnvironmentTests: XCTestCase {

    private let baseURL = URL(string: "https://config.jpc.africa/crm")!

    /// The exact call from the ticket:
    /// https://config.jpc.africa/crm/forms/jackpotcity/JZA/registration?api-version=2.0
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

/// The server's own wording has to survive the trip from JSON to the screen. Every hop below
/// is a place it could be dropped, and before `FormLoadError` existed it was dropped at the
/// last one — `JackpotFormsUI` can't see `APIError`, so everything became "Something went wrong".
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

/// The app-data response carries error copy keyed by code —
/// `"6000328": "Maximum OTP tries reached, …"` — so an API error envelope's `code` is a
/// localisation key. Without this, the code was decoded and then ignored, and the player got
/// whatever language the API happened to answer in.
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

    /// With no table loaded yet — first launch, app-data still in flight — behaviour must be
    /// exactly what it was before: show whatever the server said.
    func testEmptyTableDegradesToTheServersMessage() {
        let error = APIError.badRequest(APIProblem(code: 6000328, message: "Max OTP tries"))
        let mapped = FormErrorMapper.map(error, formName: .registration)
        XCTAssertEqual((mapped as? LocalizedError)?.errorDescription, "Max OTP tries")
    }
}

/// The schema hands the renderer keys, not text. These assert the join works for the shapes
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

#### Step 8.3 · create `Tests/JackpotFormsTests/FieldValidatorTests.swift`

Every real pattern from the schema, required vs optional-empty, checkbox-as-string, named-regex resolution, ISO-8601 dates, and **a malformed server pattern doesn't block the user**.

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

#### Step 8.4 · create `Tests/JackpotFormsTests/DynamicFormModelTests.swift`

The behaviour a user actually experiences: untouched fields stay silent, Next reveals every error at once, section gating, submit blocked while invalid, payload keyed by `fieldIdentifier`, thrown errors surface, progress. Including the subtle one — **selecting Passport relaxes the 13-digit SA-ID rule, and switching back re-applies it.**

```swift
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

**✓ Final checkpoint**

`JackpotFormsUI` is an iOS view target, so the suite runs in a simulator rather than through
`swift test`.

```bash
xcodebuild -scheme JackpotForms -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Expected:

```
Executed 61 tests, with 0 failures
```

If you get there, you've rebuilt the package.

---
## Part 9 — Using it in your app

### Step 9.1 · add the packages

Xcode → **File → Add Package Dependencies… → Add Local…** → `Packages/JackpotUI`,
`Packages/JackpotForms`, `Packages/JackpotCore`, `Packages/JackpotRegistration`.

Select your app target → **General → Frameworks, Libraries, and Embedded Content → +** and add:

- **`JackpotRegistration`** — the complete sign-up feature; this is what the app presents
- **`JackpotUI`** — the design system, for your own screens
- **`JackpotForms`** — the engine, only if you're rendering another form yourself

### Step 9.2 · prove it renders

```swift
import SwiftUI
import JackpotForms

struct DebugRoot: View {
    var body: some View { FormSandboxView.mocked() }
}
```

You should get a segmented picker (Registration / All field types), a rendered form, and — after
filling it in and pressing Sign Up — a sheet listing every submitted value.

**If you see an empty screen**, you forgot `.formDependencies(...)`. See Part 13.

### Step 9.3 · own the translation table

One instance, created at your composition root, injected — never a singleton.

```swift
@MainActor
final class AppComposition {
    let apiClient: any ApiClient
    let translations: TranslationsStore

    init(configBaseURL: URL) {
        apiClient = RemoteApiClient(environment: .init(baseURL: configBaseURL))
        translations = TranslationsStore(
            repository: RemoteTranslationsRepository(apiClient: apiClient)
        )
    }

    func bootstrap() {
        translations.load(region: "JZA", tenant: "synapse", locale: "en-US")
    }
}
```

`load` is coalesced, so calling it from several places still makes one request.

### Step 9.4 · render the form

```swift
struct SignUpPanel: View {
    let composition: AppComposition
    var onComplete: (FormSubmission) -> Void

    var body: some View {
        DynamicFormView(formName: .registration) { submission in
            try await api.register(submission.stringValues)
            onComplete(submission)
        }
        .formDependencies(.live(baseURL: configURL, localizer: legacyLocalizer))
    }
}
```

### Step 9.5 · handle submission

```swift
let payload = submission.stringValues        // [String: String], ready for a JSON body
let mobile  = submission["username"].stringValue
let agreed  = submission["terms"].boolValue
let dob     = submission["dateOfBirth"].dateValue
```

**Throw to show an error** above the Sign Up button. The form stays filled in so the user can
correct and resubmit — don't dismiss the panel yourself on failure.

```swift
struct RegistrationError: LocalizedError {
    var errorDescription: String? { "That mobile number is already registered." }
}
```

If you throw an `APIError` from your own call, wrap it — the form's engine can't see
`JackpotNetworking`. `FormErrorMapper` only runs on the *schema fetch*, not on your submit handler.

### Step 9.6 · theme it

```swift
.formTheme(FormTheme(
    surface: Color("surface"),
    fieldBackground: Color("surfaceElevated"),
    fieldBorderFocused: Color("actionSecondary"),
    fieldBorderInvalid: Color("destructive"),
    accent: Color("actionSecondary"),
    error: Color("destructive")
))
```

Set it once, high up — it flows down the environment to every field.

### Step 9.7 · keep the mock reachable

A debug-menu toggle between `.mock()` and `.live()` is worth the ten lines: it makes the form
workable when the config service is down, and makes QA's failure-state testing trivial.

```swift
.formDependencies(useMockForms ? .mock() : .live(baseURL: url, translations: table))
```

---

## Part 10 — Adopting this in the existing codebase

The current app has `GlobalData.shareData`, a free `getTranslation` function, and per-feature
`*API` classes. **None of that has to go away before sign-up ships on the clean stack.**

The sequence is `docs/PR-STRATEGY.md`: four package PRs nobody calls, then one app PR that swaps
the old popup for `JackpotRegistration` and deletes it. No feature flags — the app has none, and
the swap is one commit, so it reverts as one commit.

### PRs 1–4 — packages only

`JackpotUI` → `JackpotForms` (mock) → `JackpotCore` + `JackpotFormsRemote` (live) →
`JackpotRegistration`. Each is demoable from its previews or the sandbox. The app target does
not change.

### PR 5 — the swap

Three parts, one file added, three deleted. The whole thing:

**Step 10.1 · wrap the existing translation function**

```swift
// TRANSITIONAL. Deleted by the localisation follow-up.
let legacyLocalizer = ClosureLocalizer { key in
    let value = getTranslation(Key: key)
    return value == key ? nil : value      // getTranslation returns the key on a miss
}
```

That last line matters. `getTranslation` returns the **key itself** when it has no translation;
`FormLocalizing` uses `nil` to mean "unresolved" so the engine can fall back to humanised copy.
Without the mapping, a missing string renders as `username` instead of `Username`.

This is the **only** new code that references the legacy world, and it's deleted by the
follow-up.

**Step 10.2 · present the package where the old popup was**

```swift
let controller = RegistrationPanelController(
    dependencies: RegistrationDependencies(
        forms: .live(baseURL: configURL, localizer: legacyLocalizer),
        service: MockRegistrationService()   // → RemoteRegistrationService once the endpoint is confirmed
    )
) { [weak self] result in
    self?.routeAfterRegistration(result)
}
addChild(controller)
popupContainer.show(controller.view)
controller.didMove(toParent: self)
```

`RegistrationPanelController` is a `UIHostingController`, so it must be a child of whatever
presents it — otherwise safe areas, keyboard avoidance and environment propagation break.

**Step 10.3 · delete the old flow**

`registrationPopup`, `flowOneViewController`, `flowTwoViewController`, their nibs, their
`GlobalData` handles, and the `NavigationHandler` branches that reached them. Net negative.

**What PR 5 gets you:** registration on the clean stack, no god-object coupling, three nibs
gone, one transitional wrapper with a deletion date.

### Follow-up — localisation, last

Everything from ADR-0001 that touches copy, after PR 5. It changes the mechanism behind every
string in the app and has no dependency on registration shipping.

1. `getTranslation` becomes a shim over `Translations` — the app-wide performance fix, zero
   call-site changes. `@available(*, deprecated)` turns every remaining call site into a
   compiler warning: a burn-down list generated by the compiler.

```swift
@available(*, deprecated, message: "Inject TranslationsStore; call translations(key)")
@MainActor
func getTranslation(Key: String, regional: Bool = false) -> String {
    // `regional` passed through as given: existing call sites return byte-identical strings.
    AppContainer.shared.translations.translations(Key, regional: regional)
}
```

2. The registration `ClosureLocalizer` becomes `TranslationsLocalizer`; error codes start
   resolving to localised copy.
3. Call sites burn down by count:

```bash
grep -rn "getTranslation(" --include=*.swift . | cut -d: -f1 | sort | uniq -c | sort -rn
```

Existing `*TranslationsKeys` enums are kept — they conform to `LocalizationKey` with an empty
conformance.

### New endpoints, after PR 3

- **New endpoint** → an `APIEndpoint` type through `ApiClient`. No exceptions.
- **Existing endpoint** → converts when the screen that calls it is being worked on anyway.
- **Last caller gone** → delete the `*API` class.

### What not to do

- **Don't add a feature flag.** The app has none; the swap is one revertable commit.
- **Don't wait for `GlobalData` to die before PR 5.** The feature doesn't read it.
- **Don't let new code import `GlobalData`.** One `ClosureLocalizer`, deleted later.
- **Don't rewrite the `*API` classes wholesale.** Convert on demand.

---

## Part 11 — Open questions for the backend team

Four documented assumptions. Each is one line to change.

1. **Named regexes on dropdown options.** `idNumberType` options carry `"idNumberRegex"` /
   `"passportNumberRegex"` — names, not patterns — while `sourceOfFunds` options carry literal
   `"[a-zA-Z]"`. Where do the named ones resolve from, and do they replace the *dependent*
   field's rule (my assumption, matching the UI) or validate the selection itself?
   Disable with `FormDependencies(appliesOptionRegexToDependentField: false)`.
2. **Validation message keys.** Every field carries `"validationMessage": "regex"`, yet the UI
   shows per-field copy. I assumed `jpc-reg-{fieldIdentifier}-{validationMessage}`. The real
   locale table has keys like `select-password-reset-method`, so this is still a guess.
3. **Password rules.** One regex `^(.){8,20}$`, but two independently ticking rules plus a
   strength bar. I parse the quantifier.
4. **Welcome Offer.** It's in the builder's field-type list and all over the designs, but there
   is **no `welcomeOffer` field in the registration payload**. Built schema-driven so it works
   either way — but note the app-data response has its own `registration: Registration?`
   section, which is the most likely home for the offer list. Worth checking what
   `ConfigData.registration` actually contains before assuming a newer form schema will carry
   it.

Plus two product questions:

5. **What does the registration POST return**, and does the app auto-login, go to OTP, or bounce
   to Login? The callback currently just hands you the values.
6. **Is `code: 0` meaningful?** The app-data table has entries like `6000328`, so codes are
   real localisation keys. If `0` means "no specific code", the current message-only fallback is
   right; if it's a real code, add it to the table.

---

## Part 12 — Moving to iOS 17

Three mechanical changes, all inside `JackpotFormsUI` (plus `TranslationsStore` in `JackpotCore`):

| iOS 15 (now) | iOS 17 |
|---|---|
| `final class DynamicFormModel: ObservableObject` + `@Published` | `@Observable`; drop `@Published`, add `@ObservationIgnored` to dependencies |
| `@StateObject` / `@ObservedObject` | `@State` / plain `let` |
| `configureIfNeeded(with:)` in `DynamicFormView.init` | delete it — `@State` can be initialised from the environment in `.task` |
| `NavigationView` + `.navigationViewStyle(.stack)` | `NavigationStack` |
| `PreviewProvider` | `#Preview` |
| `NSRegularExpression` | **keep it** — `Regex` literals can't be built from runtime strings |

`JackpotNetworking`, `JackpotFormsDomain` and `JackpotFormsData` need no changes at all.

---

## Part 13 — Errors you'll hit

I hit five of these building it.

| Error | Fix |
|---|---|
| `'Form' is ambiguous for type lookup` | The type is `FormSchema`. `SwiftUI.Form` collides. |
| `cannot find 'APIError' in scope` | `import JackpotNetworking`. `JackpotForms` re-exports Domain/UI/Data, not Networking. |
| `'#Preview' is only available in iOS 17.0 or newer` | Use `PreviewProvider`. |
| `static property 'module' is internal and cannot be referenced from a default argument value` | `Bundle.module` can't be a *public* function's default arg. Use an explicit overload. |
| `call to main actor-isolated ... in a synchronous nonisolated context` | `DynamicFormModel` and `TranslationsStore` are `@MainActor`; anything constructing one needs to be too. |
| `'await' in an autoclosure that does not support concurrency` | Assign to a local first: `let n = await spy.count; XCTAssertEqual(n, 1)`. |
| `'navigationBarTitleDisplayMode' is unavailable in macOS` | `swift test` builds for the macOS host. Guard iOS-only APIs with `#if os(iOS)`. |
| `extension declares a conformance of imported type to imported protocol` | Use an adapter struct, not a retroactive conformance — see `TranslationsLocalizer`. |
| Empty screen / "Form dependencies were not configured." | You forgot `.formDependencies(...)`. |
| A field is missing from the render | Its `fieldType` isn't supported. Check `model.unsupportedFields` (printed in DEBUG). |
| A field is stuck invalid for no reason | Its regex may not compile. `FieldValidator.invalidPatterns(in: form)` lists them. |
| Every error message is empty | The problem envelope's shape changed. `APIProblemTests` in `JackpotCore` covers this. |

---

## Appendix — File map

```
Packages/
├── JackpotCore/                     ← its own README is a full build guide (68 tests)
│   ├── Sources/JackpotNetworking/   HTTPMethod · HTTPClient · APIEnvironment · APIEndpoint ·
│   │                           APIError · RequestInterceptor · RemoteApiClient    (PR 4)
│   ├── Sources/JackpotAppData/      AppDataRequest · AppDataResponse
│   └── Sources/JackpotLocalization/ Translations · LocalizationKey · TranslationsRepository · TranslationsStore
├── JackpotUI/                  ← design system, its own README (gallery preview)
├── JackpotRegistration/        ← the feature, its own README (PR 4)
└── JackpotForms/
    ├── Package.swift
    ├── Sources/
    │   ├── JackpotFormsDomain/      FormName · Form · FormField · FormValue · RegexResolving ·
    │   │                       FieldValidator · PasswordPolicy · FormLoadError ·
    │   │                       FormRepository · FormLocalizing
    │   ├── JackpotFormsData/        FormDTO · FormMapper · StubFormRepository            (mock)
    │   ├── JackpotFormsRemote/      CRMEnvironment · FormEndpoints · FormErrorMapper ·
    │   │                       RemoteFormRepository                                (live, PR 4)
    │   ├── JackpotFormsUI/
    │   │   ├── FormDependencies · DynamicFormModel · DynamicFormView
    │   │   ├── Fields/         FieldRenderer · Input · Dropdown · Checkbox · RadioGroup ·
    │   │   │                   Date · TextArea · WelcomeOffer   (each binds a JackpotUI component)
    │   │   ├── Demo/           PreviewFixtures · PreviewSupport · FormSandboxView
    │   │   └── Resources/      registration.json · kitchenSink.json
    │   └── JackpotForms/            JackpotForms (composition) · TranslationsLocalizer · Previews
    └── Tests/JackpotFormsTests/     FormDecoding · FieldValidator · DynamicFormModel   (55 tests)
```

~3,700 lines of Swift across five targets, on top of `JackpotUI`. Every code block in this document is the verified
source — the package builds clean and all 55 tests pass (plus 68 in `JackpotCore` and the `JackpotUI` gallery).
