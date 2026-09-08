#!/usr/bin/env python3
"""Rebuild docs/BUILD-PLAYBOOK.md (and .pdf) from the files actually on disk.

Documents the registration path: `RegistrationView` over `DynamicFormView(formName:
.registration)`, fed by the bundled `registration.json` or the live CRM schema.

Every code block is read from the repository at build time and emitted verbatim, so the
document cannot drift from the code it documents. Content is recorded once as a list of
structured blocks and rendered twice, so the Markdown and the PDF cannot drift from each
other either.

    python3 scripts/build-playbook.py          # Markdown — stdlib only
    python3 scripts/build-playbook.py --pdf    # Markdown + PDF (not committed; see below)

The PDF renderer needs a little setup:

    brew install pango
    python3 -m venv .venv && .venv/bin/pip install weasyprint pygments
    .venv/bin/python scripts/build-playbook.py --pdf

Adding a file to a PR means adding it to that PR's `files([...])` list below; the step
numbering and the contents page follow from the order of those lists. Update TESTS from the
last suite run.
"""

import os, sys, html, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs/BUILD-PLAYBOOK.md")
OUT_PDF = os.path.join(ROOT, "docs/BUILD-PLAYBOOK.pdf")

SIM = "'platform=iOS Simulator,name=iPhone 17 Pro'"
TEST_CMD = f"cd JackpotKit\nxcodebuild -scheme JackpotKit-Package -destination {SIM} test"

# Executed-test counts per suite, from the last `xcodebuild … test` run.
TESTS = {
    "JackpotUITests": 20,
    "JackpotNetworkingTests": 34,
    "JackpotLocalizationTests": 16,   # TranslationsTests; the store's 6 are the follow-up
    "JackpotFormsTests": 83,
    "JackpotRegistrationTests": 11,
}

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


def executed(*suites):
    return "\n".join(f"`{s}: Executed {TESTS[s]} tests, with 0 failures`" for s in suites)


# ---------------------------------------------------------------- header

text("# Build Playbook")
text(
    "Create the files in the order given. Run the commands where they appear. Open a PR where\n"
    "marked. Every code block is the file exactly as it is in the repository."
)
text(
    "This playbook covers the **registration** path: `RegistrationView` hosts\n"
    "`DynamicFormView(formName: .registration)`, which renders either the bundled\n"
    "`JackpotKit/Sources/JackpotForms/Resources/registration.json` or the live CRM schema at\n"
    "`config.jpc.africa/cron/forms/jackpotcity/JZA/registration` — the same twelve fields."
)
text(
    "`JackpotKit` is one package; each folder under `Sources/` is a module. Registration is\n"
    "carried by four of them — `JackpotUI` (design system), `JackpotNetworking` (transport),\n"
    "`JackpotForms` (the schema-driven engine) and `JackpotRegistration` (the feature) — plus\n"
    "the `Translations` value type from `JackpotLocalization`. `JackpotAppData` and the store half\n"
    "of `JackpotLocalization` are the app-data follow-up\n"
    "([ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md)); the manifest\n"
    "lists them, so copy their files from the repository or drop those two targets until you\n"
    "need them. They are not covered here."
)
text(
    "The floor is iOS 15, the host app's. The whole suite runs in a simulator via\n"
    "`xcodebuild -scheme JackpotKit-Package` — there is no macOS destination, because `JackpotUI`\n"
    "imports `UIKit`."
)
text(f"**{sum(TESTS.values())} tests** through PR 5.")
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
    "The buttons at the bottom of registration are `FormNavigationBar` in `DynamicFormView.swift`,\n"
    "which registration places in the panel's footer under the login row. `RegistrationView`\n"
    "owns a `DynamicFormModel` and composes `DynamicFormContent` (the pages) and\n"
    "`FormNavigationBar` around it; `DynamicFormView` is the same two stacked, for hosts that\n"
    "want the bar under the pages. The bundled `registration.json` and the live CRM schema are\n"
    "the twelve fields above — paging is not a field."
)
table(
    ["Visible control", "Style", "When", "Action"],
    [
        ["**Next**", "`.jackpot` (primary)", "Section 1 — not last", "`DynamicFormModel.advance()`"],
        ["**Previous**", "`.jackpot(.secondary)`", "Section 2+", "`goBack()` — values kept"],
        ["**Sign Up**", "`.jackpot` (primary)", "Last section", "`model.submit(onSubmit)`"],
    ],
)
text(
    "`Next` stays **disabled** — the accent fill dimmed to `accentFillDisabled` under\n"
    "`textPrimary` — until every visible field on the current section validates\n"
    "(`isCurrentSectionValid`). Tapping it marks the section touched, revalidates, and if valid\n"
    "increments `sectionIndex`. `Sign Up` stays disabled until `isFormValid`, then\n"
    "`RegistrationView`'s callback calls `RegistrationService.register`. A progress bar\n"
    "(`.jackpotBar`) sits above the scroll view when `sections.count > 1`."
)
text("### Registration rules and the preview path")
text(
    "1. **Schema.** `JackpotForms/Resources/registration.json`, the CRM's response saved\n"
    "   verbatim. `BundledForms.all` reads it; `StubFormRepository` serves it.\n"
    "2. **Mock wiring.** `FormDependencies.mock()` is the stub repository plus the placeholder\n"
    "   copy table `ComposedKeyLocalizer.jpcRegistration`. `.live(baseURL:)` swaps in\n"
    "   `RemoteFormRepository`; nothing else changes.\n"
    "3. **Registration's rules.** The engine ships with no cross-field regex links and no date\n"
    "   cap. `RegistrationDependencies` adds `regexDependencies: [\"idNumberType\": \"idNumber\"]`\n"
    "   and an 18-years-ago `maximumDate` on top of whatever `forms` the host passes in.\n"
    "4. **Sandbox.** The app's `SearchView` presents `RegistrationSandbox` with `.jackpotPopup`,\n"
    "   the way the app presents its panels; the sandbox hosts `RegistrationView(dependencies:\n"
    "   .mock())` and shows the `RegistrationResult` it gets back, so the whole panel runs on a\n"
    "   device with no backend.\n"
    "5. **Previews.** `FormPreview.registration` decodes the bundled JSON through the real mapper\n"
    "   for the seeded-model previews in `DynamicFormView.swift` and each field view.\n"
    "   `JackpotPreviewPanel.swift` is the component gallery.\n"
    "6. **The sheet.** `RegistrationView` is the form inside `JackpotPanel`: title and close\n"
    "   button on `surface`, the pages on `background`, and in the footer band `JackpotLinkRow`\n"
    "   with `FormNavigationBar` beneath it.\n"
    "   **Sign Up — dark / light** in `JackpotRegistration/Previews.swift` and **Sheet shell** in\n"
    "   the gallery render it in both appearances."
)
rule()

# ---------------------------------------------------------------- PR 1

text("## PR 1 — JackpotUI")
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
    "mkdir -p JackpotKit/Tests/JackpotUITests\n"
    "cd JackpotKit\n"
    "printf '.build/\\n.swiftpm/\\n*.xcuserdatad\\n' > .gitignore"
)

files(
    [
        (
            "JackpotKit/Package.swift",
            "The whole manifest, once. Later PRs add files to targets it already declares, so it\n"
            "never changes again in this playbook. Every target opts into strict concurrency\n"
            "checking to match the app's `SWIFT_STRICT_CONCURRENCY = complete`.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift",
            "Adaptive light/dark palette. Hexes are the locked token table above; `Palette.emphasis`\n"
            "is the shared #E1E1E5 so focused border and dark text are one value, not aliases.",
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
            "JackpotKit/Sources/JackpotUI/Components/JackpotPopup.swift",
            "`.jackpotPopup(isPresented:)` presents a panel the way the app does: over the page, which\n"
            "dims behind a `background` scrim, inset and pinned to the top. Not a system sheet.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotPanel.swift",
            "The shell registration is presented in: the header and footer bands on `surface`, the\n"
            "close button and the content on `background`. Resume **Sheet shell** in the gallery to see\n"
            "the layers.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift",
            "The panel wraps a preview in the themed surface. Resume **Gallery** for every registration\n"
            "component in one place.",
        ),
        "JackpotKit/Tests/JackpotUITests/JackpotThemeTests.swift",
    ]
)

bash(TEST_CMD)
rule()
text("### ▶ Create PR — JackpotUI")
text(executed("JackpotUITests"))
text(
    "Open `JackpotPreviewPanel.swift` and resume the **Gallery** preview in both appearances."
)
rule()

# ---------------------------------------------------------------- PR 2

text("## PR 2 — JackpotNetworking + Translations")
text(
    "The transport, and the localisation table the form engine adapts. Both are standalone\n"
    "modules with nothing above them, so they land before the engine that uses them. 200 / 400 /\n"
    "401 / 500 are the contract; `unexpectedStatus` carries anything infrastructure returns."
)

bash(
    "mkdir -p JackpotKit/Sources/{JackpotNetworking,JackpotLocalization}\n"
    "mkdir -p JackpotKit/Tests/{JackpotNetworkingTests,JackpotLocalizationTests}"
)

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
            "protocol method, so the types have to exist.",
        ),
        "JackpotKit/Sources/JackpotNetworking/RemoteApiClient.swift",
        "JackpotKit/Tests/JackpotNetworkingTests/MockHTTPClient.swift",
        "JackpotKit/Tests/JackpotNetworkingTests/APIEndpointTests.swift",
        "JackpotKit/Tests/JackpotNetworkingTests/APIProblemTests.swift",
        (
            "JackpotKit/Tests/JackpotNetworkingTests/RemoteApiClientTests.swift",
            "The retry policy is the part worth asserting: a 5xx or a dropped connection is retried, a\n"
            "4xx never is, and a non-idempotent request is retried only when the transport failed before\n"
            "the server could have seen it.",
        ),
        (
            "JackpotKit/Sources/JackpotLocalization/Translations.swift",
            "The session's localisation table. Two lookups matter: keys are tried region-suffixed first\n"
            "(`terms-jza` before `terms`), and API error codes are keys too, which is what lets a server\n"
            "error come back in the user's language. `TranslationsRepository.swift` and\n"
            "`TranslationsStore.swift` in the same folder are the app-data follow-up.",
        ),
        "JackpotKit/Tests/JackpotLocalizationTests/TranslationsTests.swift",
    ]
)

bash(TEST_CMD)
rule()
text("### ▶ Create PR — JackpotNetworking + Translations")
text(executed("JackpotNetworkingTests", "JackpotLocalizationTests"))
rule()

# ---------------------------------------------------------------- PR 3

text("## PR 3 — JackpotForms")
text(
    "One module, four folders pointing one way: `Domain` (types and rules, no I/O), `Data`\n"
    "(wire shapes, the bundled stub), `UI` (the engine and the renderer) and `Remote` (the live\n"
    "repository and `.live()`). The engine only ever sees `FormRepository`, which is what lets the\n"
    "stub and the network be swapped at one line in composition. Wire types are `internal`;\n"
    "nothing outside `Data/` and `Remote/` knows a JSON key name."
)

bash(
    "mkdir -p JackpotKit/Sources/JackpotForms/{Domain,Data,Remote,UI/Fields,Resources}\n"
    "mkdir -p JackpotKit/Tests/JackpotFormsTests"
)

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
        "JackpotKit/Sources/JackpotForms/Domain/PasswordPolicy.swift",
        (
            "JackpotKit/Sources/JackpotForms/Domain/RegexResolving.swift",
            "How a dropdown changes another field's rule: the schema names a pattern, this resolves it.",
        ),
        "JackpotKit/Sources/JackpotForms/Domain/FieldValidator.swift",
        "JackpotKit/Sources/JackpotForms/Domain/FormLoadError.swift",
        "JackpotKit/Sources/JackpotForms/Domain/FormLocalizing.swift",
        "JackpotKit/Sources/JackpotForms/Domain/FormRepository.swift",
        "JackpotKit/Sources/JackpotForms/Data/FormDTO.swift",
        "JackpotKit/Sources/JackpotForms/Data/FormMapper.swift",
        "JackpotKit/Sources/JackpotForms/Data/StubFormRepository.swift",
        "JackpotKit/Sources/JackpotForms/Data/BundledForms.swift",
        (
            "JackpotKit/Sources/JackpotForms/Data/RegistrationCopy.swift",
            "The placeholder copy table, until the app-data `locales` section is wired in.",
        ),
    ]
)

bash(
    "cp registration.json JackpotKit/Sources/JackpotForms/Resources/registration.json",
    note="`registration.json` is the CRM's response saved verbatim — 12 fields over two sections.\n"
    "`JackpotForms` processes it as a resource; `BundledForms` reads it from `Bundle.module`\n"
    "for the stub repository, the previews and the tests alike.",
)

files(
    [
        (
            "JackpotKit/Sources/JackpotForms/UI/FormDependencies.swift",
            "The engine's dependencies and `.mock()`. Defaults are generic: no regex links, no date\n"
            "cap. Registration adds its own in PR 4.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/DynamicFormModel.swift",
            "The engine. `load()` is `async` and a no-op once loaded, so re-appearing on screen cannot\n"
            "reset a half-filled form. `advance()` / `goBack()` / `submit()` are what Next, Previous\n"
            "and Sign Up call. `touched` is why an untouched field stays silent until Next, and\n"
            "`overrideRegex(for:)` is how selecting Passport relaxes the SA-ID rule on a different\n"
            "field.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/Fields/FieldRenderer.swift",
            "The switch is the whole contract. Registration hits `.input` (Calender →\n"
            "`DateFieldView`), `.dropdown` and `.checkbox`.",
        ),
        "JackpotKit/Sources/JackpotForms/UI/Fields/InputFieldView.swift",
        "JackpotKit/Sources/JackpotForms/UI/Fields/DropdownFieldView.swift",
        "JackpotKit/Sources/JackpotForms/UI/Fields/DateFieldView.swift",
        (
            "JackpotKit/Sources/JackpotForms/UI/Fields/CheckboxFieldView.swift",
            "`receivePromotionalInformation` and `terms`.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/DynamicFormView.swift",
            "Three views over one model. `DynamicFormContent` is the pages; `FormNavigationBar` is\n"
            "Previous / Next / Sign Up — that is how step 1 becomes step 2 — and slides the pages\n"
            "using the direction the model publishes; `DynamicFormView` stacks the two for hosts that\n"
            "want the bar under the pages. Registration composes the first two itself.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/UI/FormPreview.swift",
            "Decodes the bundled JSON for the seeded-model previews, so the previews and the stub\n"
            "cannot disagree about the schema.",
        ),
    ]
)

text(
    "At this point the engine renders the bundled schema end to end. Open `DynamicFormView.swift`\n"
    "and resume **Registration — from JSON**, then wire the network:"
)

files(
    [
        (
            "JackpotKit/Sources/JackpotForms/Remote/FormEndpoints.swift",
            "The cron URLs, the submit body, and `FormSubmitParser` — HTTP 200 is not success, the\n"
            "envelope's `isSuccessful` is, and a body that is not the envelope is a rejection.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/Remote/FormErrorMapper.swift",
            "The boundary that decides what the user reads. The engine cannot see `APIError`, so\n"
            "anything not translated here becomes a generic failure on screen.",
        ),
        "JackpotKit/Sources/JackpotForms/Remote/RemoteFormRepository.swift",
        "JackpotKit/Sources/JackpotForms/Remote/TranslationsLocalizer.swift",
        (
            "JackpotKit/Sources/JackpotForms/Remote/FormDependencies+Live.swift",
            "`.live(baseURL:)` — swap it for `.mock()` at the call site and nothing else changes.",
        ),
        "JackpotKit/Tests/JackpotFormsTests/FormDecodingTests.swift",
        "JackpotKit/Tests/JackpotFormsTests/FieldValidatorTests.swift",
        (
            "JackpotKit/Tests/JackpotFormsTests/DynamicFormModelTests.swift",
            "The behaviour a user experiences: untouched fields stay silent, Next reveals every error at\n"
            "once, section gating, submit blocked while invalid, the payload keyed by\n"
            "`fieldIdentifier`, and the ID-type → ID-number rule.",
        ),
        "JackpotKit/Tests/JackpotFormsTests/FormErrorMappingTests.swift",
        (
            "JackpotKit/Tests/JackpotFormsTests/FormRepositoryTests.swift",
            "Both repositories are driven through the same protocol here, which is the check that the\n"
            "stub and the live one are actually interchangeable.",
        ),
    ]
)

bash(TEST_CMD)
rule()
text("### ▶ Create PR — JackpotForms")
text(executed("JackpotFormsTests"))
text(
    "Open `DynamicFormView.swift` and resume the whole-form previews, including\n"
    "**Registration — from JSON**, **Offline** and **Unknown form — 404**."
)
rule()

# ---------------------------------------------------------------- PR 4

text("## PR 4 — JackpotRegistration")
text(
    "The feature: a registration service, the Sign Up sheet that drives the two-page form, the\n"
    "rules registration adds to the generic engine, and the `UIHostingController` the existing\n"
    "popup container can hold as-is."
)

bash(
    "mkdir -p JackpotKit/Sources/JackpotRegistration\n"
    "mkdir -p JackpotKit/Tests/JackpotRegistrationTests"
)

files(
    [
        "JackpotKit/Sources/JackpotRegistration/RegistrationService.swift",
        (
            "JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift",
            "`RegistrationDependencies` applies `applyingRegistrationRules()` — the ID-type link and\n"
            "the 18-year date cap — to whatever `forms` it is given. `RegistrationView` is the Sign Up\n"
            "sheet: it owns the `DynamicFormModel`, puts `DynamicFormContent` inside `JackpotPanel`, and\n"
            "fills the footer with the login row and `FormNavigationBar`, with `onClose` for the\n"
            "header and `onLogin` for the row.",
        ),
        (
            "JackpotKit/Sources/JackpotRegistration/RegistrationPanelController.swift",
            "A drop-in for the view controller PR 5 deletes: same `addChild`/`popupContainer` call site,\n"
            "SwiftUI behind it.",
        ),
        "JackpotKit/Sources/JackpotRegistration/Previews.swift",
        "JackpotKit/Tests/JackpotRegistrationTests/RegistrationServiceTests.swift",
    ]
)

bash(TEST_CMD)
rule()
text("### ▶ Create PR — JackpotRegistration")
text(executed("JackpotRegistrationTests"))
text("Open `Previews.swift` and run the flow end to end.")
rule()

# ---------------------------------------------------------------- PR 5

text("## PR 5 — Replace the current flow")
text(
    "**In Xcode:** File → Add Package Dependencies → Add Local… → `JackpotKit`, then add\n"
    "**JackpotRegistration** to the app target's frameworks."
)

swift_literal(
    "Sources/Features/Registration/RegistrationPresenter.swift",
    """import UIKit
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
""",
    note="`ClosureLocalizer` is the migration seam. The app's `getTranslation` returns the key itself on\n"
    "a miss; mapping that back to `nil` is what lets the engine fall through to humanised copy instead\n"
    "of rendering a raw key. `MockRegistrationService` stays until the submit contract is confirmed;\n"
    "`RemoteRegistrationService(repository:)` is the one-line swap.",
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

rule()
text("### ▶ Create PR — Replace registration flow")
text("Build and run. Open sign-up from the header and the bottom bar; complete both pages.")
rule()

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
