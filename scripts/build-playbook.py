#!/usr/bin/env python3
"""Rebuild docs/BUILD-PLAYBOOK.md (and .pdf) from the files actually on disk.

Six steps: the design system, the form engine and the registration sheet on the bundled
schema, the transport, the live wiring and the app swap, the localisation migration, and the
app-data migration.

Every code block is read from the repository at build time and emitted verbatim, so the
document cannot drift from the code. Every `Package.swift` block is the manifest as it stands
after that step, rendered from one table below; the final step is checked against the real
manifest on every run, so the steps cannot drift from it either. The playbook lists source
files only: the test suite stays in this repository, so the rendered manifests omit the test
targets while the check against the real manifest still includes them.

    python3 scripts/build-playbook.py             # Markdown — stdlib only
    python3 scripts/build-playbook.py --pdf       # Markdown + PDF (not committed)
    python3 scripts/build-playbook.py --manifest  # print the final Package.swift

The PDF renderer needs a little setup:

    brew install pango
    python3 -m venv .venv && .venv/bin/pip install weasyprint pygments
    .venv/bin/python scripts/build-playbook.py --pdf

Adding a file to a step means adding it to that step's `files([...])` list; adding a target
or a dependency means adding it to TARGETS with the step it arrives at, then updating
Package.swift to match (`--manifest` prints it).
"""

import os, sys, html, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs/BUILD-PLAYBOOK.md")
OUT_PDF = os.path.join(ROOT, "docs/BUILD-PLAYBOOK.pdf")
MANIFEST = os.path.join(ROOT, "JackpotKit/Package.swift")

# ---------------------------------------------------------------- the manifest, as data

FINAL_STEP = 6


class Target:
    def __init__(self, name, step, deps=(), resources=None, test=False):
        self.name = name
        self.step = step            # the step that creates the target
        self.deps = list(deps)      # (dependency, the step that adds the edge)
        self.resources = resources
        self.test = test


TARGETS = [
    Target("JackpotUI", 1),
    Target("JackpotUITests", 1, [("JackpotUI", 1)], test=True),

    Target("JackpotForms", 2, [("JackpotUI", 2), ("JackpotNetworking", 4)], resources="Resources"),
    Target("JackpotFormsTests", 2, [("JackpotForms", 2), ("JackpotNetworking", 4)], test=True),
    Target("JackpotRegistration", 2, [("JackpotUI", 2), ("JackpotForms", 2)]),
    Target("JackpotRegistrationTests", 2, [("JackpotRegistration", 2), ("JackpotForms", 2)], test=True),

    Target("JackpotNetworking", 3),
    Target("JackpotNetworkingTests", 3, [("JackpotNetworking", 3)], test=True),

    Target("JackpotLocalization", 5),
    Target("JackpotLocalizationTests", 5, [("JackpotLocalization", 5)], test=True),

    Target("JackpotAppData", 6, [("JackpotNetworking", 6), ("JackpotLocalization", 6)]),
    Target("JackpotAppDataTests", 6, [("JackpotAppData", 6), ("JackpotNetworking", 6)], test=True),
]

MANIFEST_HEAD = """// swift-tools-version: 5.10
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
    platforms: [.iOS(.v15)],"""


def quoted(names):
    return ", ".join(f'"{n}"' for n in names)


def manifest(step, tests=True):
    """Package.swift as it stands after `step`; the playbook renders it without the test targets."""
    present = [t for t in TARGETS if t.step <= step and (tests or not t.test)]
    modules = [t.name for t in present if not t.test]
    lines = [MANIFEST_HEAD, "    products: ["]

    chunks = [modules[i:i + 3] for i in range(0, len(modules), 3)]
    lines.append("        .library(")
    lines.append('            name: "JackpotKit",')
    for i, chunk in enumerate(chunks):
        prefix = "            targets: [" if i == 0 else "                      "
        suffix = "]" if i == len(chunks) - 1 else ","
        lines.append(prefix + quoted(chunk) + suffix)
    lines.append("        ),")
    for m in modules:
        lines.append(f'        .library(name: "{m}", targets: ["{m}"]),')
    lines.append("    ],")

    lines.append("    targets: [")
    previous_step = None
    for t in present:
        if previous_step is not None and t.step != previous_step:
            lines.append("")
        previous_step = t.step
        deps = [d for d, at in t.deps if at <= step]
        kind = ".testTarget" if t.test else ".target"
        parts = [f'name: "{t.name}"']
        if deps:
            parts.append(f"dependencies: [{quoted(deps)}]")
        if t.resources:
            parts.append(f'resources: [.process("{t.resources}")]')
        if not t.test:
            parts.append("swiftSettings: strict")
        if t.resources:
            lines.append(f"        {kind}(")
            for i, part in enumerate(parts):
                lines.append(f"            {part}" + ("," if i < len(parts) - 1 else ""))
            lines.append("        ),")
        else:
            lines.append(f"        {kind}({', '.join(parts)}),")
    lines.append("    ]")
    lines.append(")")
    return "\n".join(lines) + "\n"


if "--manifest" in sys.argv:
    sys.stdout.write(manifest(FINAL_STEP))
    sys.exit(0)

with open(MANIFEST) as f:
    if f.read() != manifest(FINAL_STEP):
        sys.exit("JackpotKit/Package.swift does not match TARGETS in scripts/build-playbook.py; "
                 "update one of them (`--manifest` prints the rendered final manifest)")

# ---------------------------------------------------------------- recording

blocks = []
step = 0


def text(s):
    blocks.append(("p", s.rstrip("\n")))


def fence(lang, body):
    blocks.append(("code", (lang, body.rstrip("\n"))))


def bash(body, note=None):
    global step
    step += 1
    text(f"**{step}.**")
    fence("bash", body)
    if note:
        text(note)


def swift_literal(label, body, note=None, suffix=""):
    global step
    step += 1
    text(f"**{step}.** `{label}`{suffix}")
    if note:
        text(note)
    fence("swift", body)


def manifest_step(n, note):
    global step
    step += 1
    text(f"**{step}.** `JackpotKit/Package.swift` — the whole file after this step")
    text(note)
    fence("swift", manifest(n, tests=False))


def file_step(rel, note=None):
    global step
    full = os.path.join(ROOT, rel)
    if not os.path.exists(full):
        sys.exit(f"missing: {rel}")
    with open(full) as f:
        body = f.read()
    step += 1
    text(f"**{step}.** `{rel}`")
    if note:
        text(note)
    fence("swift", body)


def files(pairs):
    for item in pairs:
        if isinstance(item, tuple):
            file_step(*item)
        else:
            file_step(item)


def table(headers, rows):
    blocks.append(("table", (headers, rows)))


def rule():
    blocks.append(("hr", None))


def create_pr(title, note=None):
    rule()
    text(f"### ▶ Create PR — {title}")
    if note:
        text(note)
    rule()


# ---------------------------------------------------------------- header

text("# Build Playbook")
text(
    "Create the files in the order given. Run the commands where they appear. Open a PR where\n"
    "marked. Every code block is the file exactly as it is in the repository, and every\n"
    "`Package.swift` block is the manifest as it stands after that step."
)
text(
    "Six steps. The registration sheet runs from step 2 with no backend. It goes live in the app\n"
    "at step 4, on the app's existing translation function. Steps 5 and 6 are the localisation\n"
    "and app-data migrations from\n"
    "[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md); registration\n"
    "does not wait for them."
)
table(
    ["Step", "Adds", "Demoable as"],
    [
        ["1", "`JackpotUI`", "the gallery: every component, every state"],
        ["2", "`JackpotForms` on the bundled schema, `JackpotRegistration`", "the Sign Up sheet, both pages, faked submit"],
        ["3", "`JackpotNetworking`", "`RemoteApiClient` against a stubbed transport"],
        ["4", "`JackpotForms/Remote`, `.live()`, the app swap", "registration live in the app, copy from `getTranslation`"],
        ["5", "`JackpotLocalization`", "the same copy from a table built once; `getTranslation` becomes a shim"],
        ["6", "`JackpotAppData`", "config served from disk on launch, revalidated behind it"],
    ],
)
text(
    "`JackpotKit` is one package; each folder under `Sources/` is a module. The floor is iOS 15,\n"
    "the host app's. The test suite stays in this repository; the playbook lists source files only."
)
text("### Registration catalog")
text(
    "Twelve fields over two sections, checked against the bundled capture and the live CRM\n"
    "response. The `fieldType` values on registration are **Input**, **Dropdown** and\n"
    "**Checkbox**; `FieldType` has exactly those three cases plus `unknown`. Date of birth is\n"
    "`Input` + `inputType: Calender` (the schema spelling)."
)
table(
    ["Step", "Identifier", "`fieldType`", "`inputType`", "Renders as"],
    [
        ["1.1", "`username`", "Input", "Number", "`JackpotTextField` · `.phoneNumber` · `+27` prefix"],
        ["1.2", "`password`", "Input", "Password", "`JackpotTextField` · `.newPassword` · `JackpotChecklist` while focused"],
        ["1.3", "`firstname`", "Input", "Text", "`JackpotTextField` · `.givenName`"],
        ["1.4", "`lastname`", "Input", "Text", "`JackpotTextField` · `.familyName`"],
        ["1.5", "`email`", "Input", "Email", "`JackpotTextField` · `.email`"],
        ["1.6", "`referralCode`", "Input", "Text", "`JackpotTextField` · optional"],
        ["2.1", "`idNumberType`", "Dropdown", "Text", "`JackpotDropdown` · drives the `idNumber` regex"],
        ["2.2", "`idNumber`", "Input", "Text", "`JackpotTextField`"],
        ["2.3", "`dateOfBirth`", "Input", "Calender", "`JackpotDateField` · capped at 18 years ago"],
        ["2.4", "`sourceOfFunds`", "Dropdown", "Text", "`JackpotDropdown`"],
        ["2.5", "`receivePromotionalInformation`", "Checkbox", "Text", "`Toggle` · `.jackpotCheckbox`"],
        ["2.6", "`terms`", "Checkbox", "Text", "`Toggle` · `.jackpotCheckbox` · required `^true$`"],
    ],
)
text(
    "The bundled capture ships `username.prefix = \"+27\"`; the live payload currently leaves\n"
    "prefix empty (the view still maps `username` to `.phoneNumber`)."
)
text(
    "Every field keeps its label **inside** the control: it sits where a placeholder would and\n"
    "floats to the top edge on focus or once there is a value (`JackpotFloatingField`). Error\n"
    "text sits beneath the control and the ring turns red, both from one modifier,\n"
    "`.jackpotFieldError(_:)`. Field data — label, kind, prefix — is an initialiser argument on\n"
    "the field; only the theme, a button's loading state and the shared focus value travel\n"
    "through the environment."
)
text("### How to go to the next screen")
text(
    "The buttons at the bottom of registration are `FormNavigationBar` in `DynamicFormContent.swift`,\n"
    "which registration places in the panel's footer under the login row. `RegistrationView`\n"
    "owns a `DynamicFormModel` and composes `DynamicFormContent` (the pages) and\n"
    "`FormNavigationBar` around it. The bundled `registration.json` and the live CRM schema are\n"
    "the twelve fields above — paging is not a field."
)
table(
    ["Visible control", "Style", "When", "Action"],
    [
        ["**Next**", "`.jackpot` (primary)", "Section 1 — not last", "`DynamicFormModel.advance()`"],
        ["**Previous**", "`.jackpot(.secondary)`", "Section 2+", "`goBack()` — values kept"],
        ["**Sign Up**", "`.jackpot` (primary)", "Last section", "`model.submit()`"],
    ],
)
text(
    "`Next` stays **disabled** — the accent fill dimmed to `accentFillDisabled` under\n"
    "`textPrimary` — until every visible field on the current section validates\n"
    "(`isCurrentSectionValid`); tapping it increments `sectionIndex`. `Sign Up` stays disabled\n"
    "until `isFormValid`, then `submit()` posts through `FormRepository.submitForm` and hands the\n"
    "result to `onComplete`. A progress bar (`.jackpotBar`) sits above the scroll view when\n"
    "`sections.count > 1`."
)
text("### Registration rules and the preview path")
text(
    "1. **Schema.** `JackpotForms/Resources/registration.json`, the CRM's response saved\n"
    "   verbatim; `StubFormRepository` serves it.\n"
    "2. **Mock wiring.** `FormDependencies.mock()` is the stub repository plus the placeholder\n"
    "   copy table `FormDependencies.registrationCopy`, behind the engine's one translation seam:\n"
    "   `translate`, a `(String) -> String` closure shaped like the app's `getTranslation`, the key\n"
    "   back on a miss. `.live(baseURL:translate:)` swaps in `RemoteFormRepository` at step 4;\n"
    "   nothing else changes.\n"
    "3. **Registration's rules.** The engine ships with no cross-field regex links and no date\n"
    "   cap. `RegistrationDependencies` adds `regexDependencies: [\"idNumber\": \"idNumberType\"]`\n"
    "   and an 18-years-ago `maximumDate` on top of whatever `forms` the host passes in.\n"
    "4. **Sandbox.** In this repository the app's `SearchView` presents `RegistrationSandbox` with\n"
    "   `.jackpotPopup`, the way the app presents its panels; the sandbox hosts\n"
    "   `RegistrationView(dependencies: .mock())` and shows the `RegistrationResult` it gets\n"
    "   back, so the whole panel runs on a device with no backend.\n"
    "5. **The sheet.** `RegistrationView` is the form inside `JackpotPanel`: title and close\n"
    "   button on `surface`, the pages on `background`, and in the footer band `JackpotLinkRow`\n"
    "   with `FormNavigationBar` beneath it.\n"
    "6. **Previews.** One file, `JackpotRegistration/Previews.swift`: the sheet on `.mock()`, dark\n"
    "   and light, plus the loading state. `JackpotPreviewPanel.swift` is the component gallery."
)
rule()

# ---------------------------------------------------------------- step 1

text("## Step 1 — JackpotUI")
text(
    "The design system, with no knowledge of forms. Components take a title, a binding and their\n"
    "own configuration; the theme travels through the environment. Every component previews\n"
    "alone in the gallery."
)
text("### Colour tokens")
text(
    "Locked `JackpotColors` set. Same hex is one `Palette` entry — roles that share a value point\n"
    "at it, and a role gets its own name when it can diverge (`surface` and `fieldBackground`).\n"
    "There is no `link` token; that Android role is `accent`."
)
table(
    ["Token", "Light", "Dark", "Role"],
    [
        ["`background`", "#FFFFFF", "#131316", "The base layer screens and components draw on; the form body, the Previous button, and the close button and login row on a band (Android `formBackground`)"],
        ["`surface`", "#F0F0F2", "#202126", "The raised layer: sheet header and footer bands, the date picker sheet (Android `surface`)"],
        ["`fieldBackground`", "#F0F0F2", "#202126", "Field fill and the checklist — same pair as `surface`, its own role"],
        ["`fieldBorder`", "#E1E2E6", "#3E3E48", "Hairline, progress track, Previous button"],
        ["`fieldBorderFocused`", "#0060EC", "#0060EC", "Focus ring, the brand blue in both appearances (same value as `accentFill`)"],
        ["`fieldBorderInvalid`", "#DF0000", "#FF6B6B", "Invalid ring — same value as `error`"],
        ["`textPrimary`", "#2F2F37", "#E1E1E5", "Titles and values (Android `titleText` / Text Priority)"],
        ["`textSecondary`", "#565A63", "#E1E1E5", "Labels and placeholders"],
        ["`textOnAccent`", "#FFFFFF", "#FFFFFF", "Label on `accentFill`"],
        ["`accent`", "#0060EC", "#4D8FFF", "Tint, raised label when focused, ticks (Android `link`)"],
        ["`accentFill`", "#0060EC", "#0060EC", "Primary button fill"],
        ["`accentFillDisabled`", "#D4E4F8", "#262B3B", "Disabled primary button fill, under `textPrimary`. Both read from the app's screens pending the Android pair"],
        ["`error`", "#DF0000", "#FF6B6B", "Validation and load errors"],
        ["`warning`", "#945C05", "#F59E21", "Checklist incomplete"],
        ["`success`", "#0F7542", "#33B870", "Checklist complete"],
    ],
)
text(
    "Android light-mode `bodyText` / `labelText` / `placeholderText` / `primary` / `onPrimary` /\n"
    "`link` were all #E1E1E5 — 1.15:1 on #F0F0F2. Light text uses the documented Text Priority\n"
    "hex and the existing #565A63 secondary; interactive fills keep the isolated brand blue so\n"
    "`textOnAccent` still clears 4.5:1. Dark `error` lightens from #DF0000 because the brand red\n"
    "is ~3.2:1 on #202126. Light `error` on the field fill is 4.46:1, the locked #DF0000."
)

bash(
    "mkdir -p JackpotKit/Sources/JackpotUI/{Theme,Styles,Fields,Components,Preview}\n"
    "cd JackpotKit\n"
    "printf '.build/\\n.swiftpm/\\n*.xcuserdatad\\n' > .gitignore"
)
manifest_step(1, "One module. Every target opts into strict concurrency checking to match\n"
                 "the app's `SWIFT_STRICT_CONCURRENCY = complete`.")
files(
    [
        (
            "JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift",
            "Adaptive light/dark palette. Hexes are the locked token table above; `Palette.emphasis`\n"
            "is the shared #E1E1E5 for dark text.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Theme/JackpotEnvironment.swift",
            "The environment carries what genuinely cascades. `jackpotFieldError` is internal: it is\n"
            "set by the `jackpotFieldError(_:)` modifier and read by the chrome.",
        ),
        "JackpotKit/Sources/JackpotUI/Theme/JackpotStyling.swift",
        (
            "JackpotKit/Sources/JackpotUI/Styles/JackpotButtonStyle.swift",
            "`.jackpot` is Next / Sign Up: `accentFill` + `textOnAccent` when enabled,\n"
            "`accentFillDisabled` under `textPrimary` when disabled. `.jackpot(.secondary)` is Previous:\n"
            "`background` fill, `fieldBorder` hairline, `textPrimary` label.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Styles/JackpotCheckboxToggleStyle.swift",
            "Registration's two consents use `.jackpotCheckbox`.",
        ),
        "JackpotKit/Sources/JackpotUI/Styles/JackpotProgressViewStyle.swift",
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotFieldKind.swift",
            "Keyboard / autofill kinds, passed as `kind:` to `JackpotTextField`. Registration uses\n"
            "text, name, email, phone, number and new-password.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotFieldChrome.swift",
            "The shared background, the `jackpotFieldError(_:)` row, and `JackpotFloatingField` — the\n"
            "one place the in-field label's rise is laid out.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotTextField.swift",
            "Title, kind, prefix and suffix on `init`. Secure entry and the reveal button follow\n"
            "from `kind.isSecure`.",
        ),
        "JackpotKit/Sources/JackpotUI/Fields/JackpotDropdown.swift",
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotDateField.swift",
            "The `Calender` input type: a read-only field presenting a wheel picker in a sheet.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotChecklist.swift",
            "The live password-rules panel on `password`.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotErrorView.swift",
            "Shown when a form fails to load.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotLinkRow.swift",
            "The \"Already have an account? Login\" row, filled with `background` on the footer band, and\n"
            "its mirror under Login.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotPanel.swift",
            "The shell registration is presented in: the header and footer bands on `surface`, the\n"
            "close button and the content on `background`. Resume **Sheet shell** in the gallery to see\n"
            "the layers.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotPopup.swift",
            "`.jackpotPopup(isPresented:)` presents a panel the way the app does: over the page, which\n"
            "dims behind a `background` scrim, inset and pinned below the host's header. Not a system\n"
            "sheet.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift",
            "The panel wraps a preview in the themed surface. Resume **Gallery** for every registration\n"
            "component in one place.",
        ),
    ]
)
create_pr("JackpotUI",
          note="Open `JackpotPreviewPanel.swift` and resume the **Gallery** and **Sheet shell** previews in\n"
               "both appearances.")

# ---------------------------------------------------------------- step 2

text("## Step 2 — JackpotForms on the bundled schema, and the registration sheet")
text(
    "The engine, with no network. One module, three folders pointing one way: `Domain` (types\n"
    "and rules, no I/O), `Data` (wire shapes and the bundled stub) and `UI` (the model and the\n"
    "renderer). The engine only ever sees `FormRepository`; `StubFormRepository` serves the\n"
    "captured `registration.json` and fakes the submit, which is what lets the whole sheet run\n"
    "before any endpoint exists. `JackpotRegistration` is the feature on top: the sheet and\n"
    "registration's own rules."
)
bash(
    "mkdir -p JackpotKit/Sources/JackpotForms/{Domain,Data,UI/Fields,Resources}\n"
    "mkdir -p JackpotKit/Sources/JackpotRegistration"
)
manifest_step(2, "`JackpotForms` depends on `JackpotUI` alone at this step; the network joins it at step 4.\n"
                 "Wire types are `internal`.")
files(
    [
        (
            "JackpotKit/Sources/JackpotForms/Domain/FormName.swift",
            "`.registration` is the live form.",
        ),
        "JackpotKit/Sources/JackpotForms/Domain/FormValue.swift",
        (
            "JackpotKit/Sources/JackpotForms/Domain/FormField.swift",
            "`FieldType` is Input, Dropdown and Checkbox — the registration catalog — plus `unknown`,\n"
            "which is what keeps the form usable when the CRM adds a type this build cannot draw.",
        ),
        "JackpotKit/Sources/JackpotForms/Domain/FormSchema.swift",
        "JackpotKit/Sources/JackpotForms/Domain/FormSubmitResult.swift",
        "JackpotKit/Sources/JackpotForms/Domain/FormError.swift",
        "JackpotKit/Sources/JackpotForms/Domain/FormRepository.swift",
        (
            "JackpotKit/Sources/JackpotForms/Data/FormDTO.swift",
            "The wire shapes and, on each, the domain value it maps to.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/Data/StubFormRepository.swift",
            "Serves the bundled `registration.json` and fakes the submit.",
        ),
    ]
)
bash(
    "cp registration.json JackpotKit/Sources/JackpotForms/Resources/registration.json",
    note="`registration.json` is the CRM's response saved verbatim — 12 fields over two sections.\n"
    "`JackpotForms` processes it as a resource; `StubFormRepository` reads it from `Bundle.module`\n"
    "for the sandbox, the previews and the tests alike.",
)
files(
    [
        (
            "JackpotKit/Sources/JackpotForms/UI/FormDependencies.swift",
            "The engine's dependencies, `.mock()` and the placeholder copy. `translate` is the one\n"
            "translation seam: a key in, its text out, the key itself on a miss, so the app's\n"
            "`getTranslation` plugs in as it is. Defaults are generic: no regex links, no date cap;\n"
            "`namedPatterns` is what a name on a dropdown option's `regex` stands for, which is how\n"
            "a dropdown changes another field's rule. Registration adds its own links below.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/DynamicFormModel.swift",
            "The engine. Its state is `values` and `touched`; validity, errors and progress are computed\n"
            "from those on every read, so nothing has to be re-validated when a dropdown changes\n"
            "another field's rule. `load()` is `async` and a no-op once loaded, so re-appearing on screen\n"
            "cannot reset a half-filled form. `advance()` / `goBack()` / `submit()` are what Next,\n"
            "Previous and Sign Up call; `submit()` posts through the same `FormRepository` that loaded\n"
            "the form. `overrideRegex(for:)` is how selecting Passport relaxes the SA-ID rule on a\n"
            "different field. A field's rule is `FormField.accepts(_:overrideRegex:)`: a server regex\n"
            "that will not compile is no constraint.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/Fields/FieldRenderer.swift",
            "The switch is the whole contract. Registration hits `.input` with `Calender` (the date\n"
            "picker), `.input`, `.dropdown` and `.checkbox`; only text entry needs a view of its own.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/Fields/InputFieldView.swift",
            "The text field, with the password rules read off the `{min,max}` in its regex.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/DynamicFormContent.swift",
            "Two views over one model. `DynamicFormContent` is the pages; `FormNavigationBar` is\n"
            "Previous / Next / Sign Up — that is how step 1 becomes step 2 — and slides the pages\n"
            "using the direction the model publishes. Registration composes the two inside its panel.",
        ),
    ]
)
text(
    "At this point the engine renders the bundled schema end to end. Now the feature that presents it:"
)
files(
    [
        (
            "JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift",
            "`RegistrationDependencies` applies `applyingRegistrationRules()` — the ID-type link and\n"
            "the 18-year date cap — to whatever `forms` it is given. `RegistrationView` is the Sign Up\n"
            "sheet: it owns the `DynamicFormModel`, puts `DynamicFormContent` inside `JackpotPanel`, and\n"
            "fills the footer with the login row and `FormNavigationBar`, with `onClose` for the\n"
            "header, `onLogin` for the row and `onComplete` for the `RegistrationResult` the submit\n"
            "returns.",
        ),
        (
            "JackpotKit/Sources/JackpotRegistration/RegistrationPanelController.swift",
            "A drop-in for the view controller step 4 deletes: same `addChild`/`popupContainer` call\n"
            "site, SwiftUI behind it.",
        ),
        "JackpotKit/Sources/JackpotRegistration/Previews.swift",
    ]
)
create_pr("JackpotForms + JackpotRegistration, on the bundled schema",
          note="Open `JackpotRegistration/Previews.swift` and resume **Sign Up — dark**: the whole flow,\n"
               "both pages, success and the duplicate-mobile failure (`0000000000`), with no app and no\n"
               "backend.")

# ---------------------------------------------------------------- step 3

text("## Step 3 — JackpotNetworking")
text(
    "The transport: `HTTPClient` is the seam tests stub, `APIEndpoint` is one request shape,\n"
    "`RemoteApiClient` is the pipeline. 200 / 400 / 401 / 500 are the contract;\n"
    "`unexpectedStatus` carries anything infrastructure returns. Nothing here knows about forms,\n"
    "and nothing here needs translations: the app keeps `getTranslation` for now."
)
bash(
    "mkdir -p JackpotKit/Sources/JackpotNetworking"
)
manifest_step(3, "A standalone module; nothing depends on it yet.")
files(
    [
        "JackpotKit/Sources/JackpotNetworking/HTTPMethod.swift",
        "JackpotKit/Sources/JackpotNetworking/HTTPClient.swift",
        "JackpotKit/Sources/JackpotNetworking/APIEnvironment.swift",
        "JackpotKit/Sources/JackpotNetworking/APIEndpoint.swift",
        "JackpotKit/Sources/JackpotNetworking/APIError.swift",
        "JackpotKit/Sources/JackpotNetworking/RequestInterceptor.swift",
        (
            "JackpotKit/Sources/JackpotNetworking/ConditionalRequest.swift",
            "Registration never sends a conditional request; `RemoteApiClient` still implements the\n"
            "protocol method, so the types have to exist. Step 6 uses them.",
        ),
        (
            "JackpotKit/Sources/JackpotNetworking/RemoteApiClient.swift",
            "The retry policy is the part to read: a 5xx or a dropped connection is retried, a 4xx never\n"
            "is, and a non-idempotent request is retried only when the transport failed before the\n"
            "server could have seen it.",
        ),
    ]
)
create_pr("JackpotNetworking")

# ---------------------------------------------------------------- step 4

text("## Step 4 — Connect the forms to the network, and replace the flow in the app")
text(
    "The `Remote` folder joins `JackpotForms`: the cron endpoints, the submit envelope, the error\n"
    "boundary and `.live()` — the two files that import `JackpotNetworking`. The engine is\n"
    "untouched — that is the point of the protocol — and the sheet is untouched too; the only line\n"
    "that changes at the call site is `.mock()` → `.live(baseURL:translate:)`, and `translate` is\n"
    "the app's existing `getTranslation`, passed as it is."
)
bash("mkdir -p JackpotKit/Sources/JackpotForms/Remote")
manifest_step(4, "`JackpotForms` gains `JackpotNetworking`. No new targets.")
files(
    [
        (
            "JackpotKit/Sources/JackpotForms/Remote/FormEndpoints.swift",
            "The cron paths, the submit request and the envelope it comes back in.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/Remote/RemoteFormRepository.swift",
            "The fetch, the submit — HTTP 200 is not success, the envelope's `isSuccessful` is, and a\n"
            "body that is not the envelope is a rejection — and the boundary that decides what the\n"
            "user reads: the engine cannot see `APIError`, so anything not translated in `userFacing`\n"
            "becomes a generic failure on screen. Error codes are translation keys and go through\n"
            "`translate`. `.live(baseURL:translate:)` is at the bottom: swap it for `.mock()` at the\n"
            "call site and nothing else changes.",
        ),
    ]
)
text(
    "Then the app, once. **In Xcode:** File → Add Package Dependencies → Add Local… →\n"
    "`JackpotKit`, then add **JackpotRegistration** to the app target's frameworks."
)
swift_literal(
    "Sources/Features/Registration/RegistrationPresenter.swift",
    """import UIKit
import JackpotRegistration

extension MainViewController {

    func presentRegistration() {
        let controller = RegistrationPanelController(
            dependencies: RegistrationDependencies(
                forms: .live(
                    baseURL: URL(string: "https://config.jpc.africa")!,
                    translate: { getTranslation(Key: $0) }
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
""",
    note="`.live` makes the fetch and the submit real together; `.mock()` keeps the faked submit for a\n"
    "build without the backend.",
)
step += 1
text(f"**{step}.** Point every existing entry point at `presentRegistration()`:")
text(
    "- the header **SIGN UP** button\n"
    "- the bottom bar **Sign Up** item\n"
    "- `NavigationHandler` — the `registration` sitemap branch\n"
    "- the Login panel's **Sign Up ›** link"
)
step += 1
text(f"**{step}.** Delete:")
fence(
    "",
    "RegistrationViewController.swift\n"
    "RegistrationViewController.xib\n"
    "FlowOneViewController.swift\n"
    "FlowOneViewController.xib\n"
    "FlowTwoViewController.swift\n"
    "FlowTwoViewController.xib",
)
text("And from `GlobalData.swift`:")
fence("", "registrationPopup\nflowOneViewController\nflowTwoViewController")
bash(
    'grep -rn "registrationPopup\\|flowOneViewController\\|flowTwoViewController" --include=*.swift .',
    note="Expect no results.",
)
create_pr("live registration in the app",
          note="Build and run. Open sign-up from the header and the bottom bar; complete both pages.\n"
               "Every label reads as it did — that is `getTranslation` plugged straight in.")

# ---------------------------------------------------------------- step 5

text("## Step 5 — Fix translations")
text(
    "[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md) phase 2.\n"
    "`Translations` is the session's table, normalised once at construction instead of on every\n"
    "lookup; `TranslationsStore` owns it for the session. `getTranslation` becomes a shim over the\n"
    "store, which fixes the per-lookup rebuild for the whole app with no call-site changes —\n"
    "registration included, since it only ever held the function."
)
bash(
    "mkdir -p JackpotKit/Sources/JackpotLocalization"
)
manifest_step(5, "`JackpotLocalization` arrives with no dependencies; nothing depends on it until step 6.")
files(
    [
        (
            "JackpotKit/Sources/JackpotLocalization/Translations.swift",
            "Keys are tried region-suffixed first (`terms-jza` before `terms`), and a miss returns the\n"
            "key, the same contract as `getTranslation` — which is what lets `translations(_:)` stand\n"
            "in for it.",
        ),
        (
            "JackpotKit/Sources/JackpotLocalization/TranslationsRepository.swift",
            "The protocol and the fixed-table stub. The live implementation reads the app-data payload\n"
            "and arrives with it at step 6.",
        ),
        "JackpotKit/Sources/JackpotLocalization/TranslationsStore.swift",
    ]
)
swift_literal(
    "the app",
    """// 1. The store is created once, at the composition root, and injected.
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

// 3. Registration needs no change: the closure it was given at step 4 now reads the store.
//    Once the deprecation burns down, pass the table directly.
forms: .live(baseURL: configURL, translate: { translations.translations($0) })
""",
    suffix=" — two changes and a non-change",
)
create_pr("translations",
          note="Every label and error reads as before; the table is built once instead of per lookup.")

# ---------------------------------------------------------------- step 6

text("## Step 6 — Fix app data")
text(
    "[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md) phase 1 and\n"
    "[LAUNCH-PERFORMANCE](LAUNCH-PERFORMANCE.md). `AppDataResponse` splits the bootstrap payload\n"
    "by top-level key so one null section cannot lose the other five; `FileAppDataCache` keeps the\n"
    "last good payload; `AppDataLoader` serves it at zero latency and revalidates behind it;\n"
    "`RemoteTranslationsRepository` feeds the store from the same payload."
)
bash(
    "mkdir -p JackpotKit/Sources/JackpotAppData"
)
manifest_step(6, "The last module. The manifest in the repository, less its test targets.")
files(
    [
        "JackpotKit/Sources/JackpotAppData/AppData.swift",
        "JackpotKit/Sources/JackpotAppData/AppDataCache.swift",
        "JackpotKit/Sources/JackpotAppData/AppDataLoader.swift",
        "JackpotKit/Sources/JackpotAppData/RemoteTranslationsRepository.swift",
    ]
)
swift_literal(
    "the app — bootstrap",
    """let loader = AppDataLoader(apiClient: client, cache: FileAppDataCache(), policy: .default)

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
""",
)
create_pr("app data",
          note="Log `AppDataSnapshot.origin` at launch; a low `.cache` rate means `maxStale` is too tight.")

# ================================================================ renderers

STEP_RE = re.compile(r"^\*\*(\d+)\.\*\*")


def classify(payload):
    """Map a recorded paragraph onto the element it should become."""
    if payload.startswith("### "):
        return "h3", payload[4:]
    if payload.startswith("## "):
        return "h2", payload[3:]
    if payload.startswith("# "):
        return "h1", payload[2:]
    if STEP_RE.match(payload):
        return "step", payload
    if payload.startswith("- "):
        return "ul", payload
    return "p", payload


# ---------------------------------------------------------------- markdown


def render_markdown():
    out = []
    for kind, payload in blocks:
        if kind == "p":
            out.append(payload)
            out.append("")
        elif kind == "code":
            lang, body = payload
            out.append(f"```{lang}")
            out.append(body)
            out.append("```")
            out.append("")
        elif kind == "hr":
            out.append("---")
            out.append("")
        elif kind == "table":
            headers, rows = payload
            out.append("| " + " | ".join(headers) + " |")
            out.append("| " + " | ".join("---" for _ in headers) + " |")
            for row in rows:
                out.append("| " + " | ".join(row) + " |")
            out.append("")
    return "\n".join(out).rstrip("\n") + "\n"


# ---------------------------------------------------------------- html

CODE_SPAN = re.compile(r"`([^`]+)`")
BOLD = re.compile(r"\*\*([^*]+)\*\*")
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def inline(s):
    """Markdown inlines → HTML, with code spans shielded from later passes."""
    shelf = []

    def stash(m):
        shelf.append(m.group(1))
        return f"\x00{len(shelf) - 1}\x00"

    s = CODE_SPAN.sub(stash, s)
    s = html.escape(s, quote=False)
    s = BOLD.sub(r"<strong>\1</strong>", s)
    s = LINK.sub(r'<a href="\2">\1</a>', s)
    s = re.sub(r"\x00(\d+)\x00", lambda m: f"<code>{html.escape(shelf[int(m.group(1))])}</code>", s)
    return s


def highlight(lang, body):
    from pygments import highlight as pyg
    from pygments.lexers import SwiftLexer, BashLexer, TextLexer
    from pygments.formatters import HtmlFormatter

    lexer = {"swift": SwiftLexer, "bash": BashLexer}.get(lang, TextLexer)()
    return pyg(body, lexer, HtmlFormatter(nowrap=True))


def render_html():
    from pygments.formatters import HtmlFormatter

    body, toc, slug_n, toc_slot = [], [], 0, None
    for kind, payload in blocks:
        if kind == "hr":
            body.append('<hr class="rule">')
            continue

        if kind == "code":
            lang, src = payload
            body.append(f'<pre class="code {lang}">{highlight(lang, src)}</pre>')
            continue

        if kind == "table":
            headers, rows = payload
            head = "".join(f"<th>{inline(h)}</th>" for h in headers)
            body_rows = "".join(
                "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>" for row in rows
            )
            body.append(f"<table><thead><tr>{head}</tr></thead><tbody>{body_rows}</tbody></table>")
            continue

        tag, content = classify(payload)
        slug_n += 1
        anchor = f"s{slug_n}"

        if tag == "h1":
            body.append(f"<h1>{inline(content)}</h1>")
        elif tag == "h2":
            # Contents belongs after the cover, so reserve its slot at the first PR.
            if toc_slot is None:
                toc_slot = len(body)
                body.append("")
            body.append(f'<h2 id="{anchor}">{inline(content)}</h2>')
            toc.append((2, content, anchor))
        elif tag == "h3":
            body.append(f'<h3 id="{anchor}">{inline(content)}</h3>')
            toc.append((3, content, anchor))
        elif tag == "step":
            n = STEP_RE.match(content).group(1)
            rest = STEP_RE.sub("", content).strip()
            # The visual number is a badge; the outline needs a readable label of its own.
            plain = re.sub(r"[`*]", "", rest).strip(" —") or "shell"
            body.append(
                f'<p class="step" id="{anchor}" data-label="{html.escape(n + " · " + plain, quote=True)}">'
                f'<span class="n">{n}</span>{inline(rest)}</p>'
            )
        elif tag == "ul":
            items = "".join(
                f"<li>{inline(line[2:])}</li>" for line in content.split("\n") if line.startswith("- ")
            )
            body.append(f"<ul>{items}</ul>")
        else:
            body.append(f"<p>{inline(content)}</p>")

    toc_html = "".join(
        f'<li class="l{level}"><a href="#{anchor}">{inline(title)}</a></li>' for level, title, anchor in toc
    )
    if toc_slot is not None:
        body[toc_slot] = f"<nav><h2>Contents</h2><ul>{toc_html}</ul></nav>"

    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Build Playbook</title>
<style>
{HtmlFormatter(style="xcode").get_style_defs('.code')}
@page {{
  size: A4;
  margin: 16mm 13mm 16mm 13mm;
  @bottom-center {{
    content: counter(page);
    font: 7.5pt "Helvetica Neue", sans-serif; color: #8a8f98;
  }}
  @top-right {{
    content: string(section);
    font: 7.5pt "Helvetica Neue", sans-serif; color: #8a8f98;
  }}
}}
@page :first {{ @top-right {{ content: normal }} @bottom-center {{ content: normal }} }}

body {{
  font: 9.4pt/1.5 "Helvetica Neue", Helvetica, sans-serif;
  color: #1d2025; margin: 0;
}}
h1 {{
  font-size: 25pt; letter-spacing: -0.4pt; margin: 0 0 4mm;
  bookmark-level: 1; bookmark-label: content();
}}
h2 {{
  font-size: 15pt; letter-spacing: -0.2pt; margin: 0 0 3mm;
  padding-bottom: 2mm; border-bottom: 0.7pt solid #d4d8dd;
  string-set: section content(); break-before: page;
  bookmark-level: 2; bookmark-label: content();
}}
h3 {{
  font-size: 11pt; margin: 6mm 0 2.5mm;
  bookmark-level: 3; bookmark-label: content();
}}
h1 + p {{ font-size: 10.4pt; color: #4a5058; }}
p {{ margin: 0 0 2.6mm; orphans: 2; widows: 2; }}
ul {{ margin: 0 0 3mm; padding-left: 5mm; }}
li {{ margin-bottom: 1mm; }}

p.step {{
  margin: 5.5mm 0 2mm; font-weight: 600; font-size: 9.6pt;
  break-after: avoid; break-inside: avoid;
  bookmark-level: 4; bookmark-label: attr(data-label);
}}
p.step .n {{
  display: inline-block; min-width: 7.4mm; height: 5mm;
  margin-right: 2mm; padding: 0 1.4mm;
  background: #1d2025; color: #fff; border-radius: 1mm;
  font-size: 8pt; text-align: center; font-weight: 700;
}}
p.step code {{ font-weight: 600; background: none; padding: 0; color: #0b4fa8; }}

code {{
  font-family: Menlo, Monaco, monospace; font-size: 0.87em;
  background: #f1f3f5; padding: 0.3mm 1mm; border-radius: 0.8mm;
}}
a {{ color: #0b4fa8; text-decoration: none; }}

pre.code {{
  font-family: Menlo, Monaco, monospace;
  font-size: 6.6pt; line-height: 1.42;
  background: #fbfbfc; border: 0.5pt solid #e2e5e9;
  border-left: 1.6pt solid #b8bfc7;
  border-radius: 1mm; padding: 2.2mm 2.6mm;
  margin: 0 0 3.4mm;
  white-space: pre-wrap; overflow-wrap: anywhere; tab-size: 4;
}}
pre.code.bash {{ background: #1d2025; border-color: #1d2025; border-left-color: #6b7280; color: #e8eaed; }}
pre.code.bash span {{ color: #e8eaed !important; font-style: normal !important; }}
hr.rule {{ border: 0; border-top: 0.5pt solid #e2e5e9; margin: 5mm 0; }}
table {{
  width: 100%; border-collapse: collapse; margin: 0 0 3.4mm;
  font-size: 8.4pt;
}}
th, td {{
  border: 0.5pt solid #e2e5e9; padding: 1.2mm 1.6mm; text-align: left; vertical-align: top;
}}
th {{ background: #f1f3f5; font-weight: 600; }}
td:nth-child(2), td:nth-child(3) {{ font-family: Menlo, Monaco, monospace; font-size: 7.6pt; }}

nav {{ break-before: page; }}
nav h2 {{ break-before: avoid; }}
nav ul {{ list-style: none; padding: 0; margin: 0; }}
nav li a {{ color: #1d2025; }}
nav li a::after {{
  content: " " leader('.') " " target-counter(attr(href), page);
  color: #8a8f98;
}}
nav li.l2 {{ margin-top: 2.4mm; font-weight: 600; }}
nav li.l3 {{ padding-left: 5mm; font-weight: 400; color: #4a5058; }}
</style></head>
<body>
{"".join(body)}
</body></html>"""


# ---------------------------------------------------------------- emit

markdown = render_markdown()

with open(OUT, "w") as f:
    f.write(markdown)
print(f"wrote {OUT}: {markdown.count(chr(10))} lines, {step} steps")

if "--pdf" in sys.argv:
    from weasyprint import HTML

    page = render_html()
    HTML(string=page, base_url=ROOT).write_pdf(OUT_PDF)
    print(f"wrote {OUT_PDF}: {os.path.getsize(OUT_PDF) / 1_048_576:.1f} MB")
