#!/usr/bin/env python3
"""Rebuild docs/BUILD-PLAYBOOK.md (and .pdf) from the files actually on disk.

Documents the registration flow (`DynamicFormView(formName: .registration)` +
`registration.json`) and the registration-only preview harness. Shared sources
are shown as the registration-used slice.

Every code block in the playbook is read from source at build time, so the document cannot
drift from the code it documents. Content is recorded once as a list of structured blocks and
rendered twice, so the Markdown and the PDF cannot drift from each other either.

    python3 scripts/build-playbook.py          # Markdown — stdlib only
    python3 scripts/build-playbook.py --pdf    # Markdown + PDF

The PDF renderer needs a little setup:

    brew install pango
    python3 -m venv .venv && .venv/bin/pip install weasyprint pygments
    .venv/bin/python scripts/build-playbook.py --pdf

Adding a file to a PR means adding it to that PR's `files([...])` list below; the step
numbering, the outline and the contents page all follow from the order of those lists.
"""

import os, sys, html, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs/BUILD-PLAYBOOK.md")
OUT_PDF = os.path.join(ROOT, "docs/BUILD-PLAYBOOK.pdf")

SIM = "'platform=iOS Simulator,name=iPhone 17 Pro'"
TEST_CMD = f"cd JackpotKit\nxcodebuild -scheme JackpotKit-Package -destination {SIM} test"

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


def file_step(rel, note=None, transform=None):
    global step
    full = os.path.join(ROOT, rel)
    if not os.path.exists(full):
        sys.exit(f"missing: {rel}")
    with open(full) as f:
        body = f.read()
    if transform:
        body = transform(body, rel)
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


def require_replace(body, old, new, rel):
    if old not in body:
        sys.exit(f"playbook excerpt ({rel}): missing {old!r}")
    return body.replace(old, new, 1)


def drop_from_marker(body, marker, rel):
    idx = body.find(marker)
    if idx == -1:
        sys.exit(f"playbook excerpt ({rel}): missing marker {marker!r}")
    return body[:idx].rstrip() + "\n"


def registration_button_style(body, rel):
    body = require_replace(body, "        case primary\n        case secondary\n        case tertiary\n",
                           "        case primary\n        case secondary\n", rel)
    body = require_replace(body, "            case .primary:\n"
                                 "                theme.sizes.fieldShape.fill(isDimmed ? theme.colors.fieldBackground : theme.colors.accentFill)\n"
                                 "            case .secondary:\n"
                                 "                JackpotButtonHairline(fill: theme.colors.surface)\n"
                                 "            case .tertiary:\n"
                                 "                theme.sizes.fieldShape.fill(Color.clear)\n",
                           "            case .primary:\n"
                           "                theme.sizes.fieldShape.fill(isDimmed ? theme.colors.fieldBackground : theme.colors.accentFill)\n"
                           "            case .secondary:\n"
                           "                JackpotButtonHairline(fill: theme.colors.surface)\n", rel)
    body = require_replace(body, "            case .primary:   return isDimmed ? theme.colors.textSecondary : theme.colors.textOnAccent\n"
                                 "            case .secondary: return isDimmed ? theme.colors.textSecondary : theme.colors.textPrimary\n"
                                 "            case .tertiary:  return isDimmed ? theme.colors.textSecondary : theme.colors.accent\n",
                           "            case .primary:   return isDimmed ? theme.colors.textSecondary : theme.colors.textOnAccent\n"
                           "            case .secondary: return isDimmed ? theme.colors.textSecondary : theme.colors.textPrimary\n", rel)
    return drop_from_marker(body, "// MARK: - Selectable card", rel)


def registration_toggle_style(body, rel):
    body = require_replace(body, "        case checkbox\n        case `switch`\n",
                           "        case checkbox\n", rel)
    body = require_replace(body, "            switch appearance {\n            case .checkbox: checkbox\n            case .switch:   platformSwitch\n            }\n",
                           "            checkbox\n", rel)
    body = require_replace(body, "        private var platformSwitch: some View {\n"
                                 "            Toggle(configuration)\n"
                                 "                .toggleStyle(.switch)\n"
                                 "                .jackpotTextStyle(\\.rowLabel)\n"
                                 "        }\n\n",
                           "", rel)
    return require_replace(body, "    static var jackpotCheckbox: JackpotToggleStyle { JackpotToggleStyle(.checkbox) }\n"
                                 "    static var jackpotSwitch: JackpotToggleStyle { JackpotToggleStyle(.switch) }\n",
                           "    static var jackpotCheckbox: JackpotToggleStyle { JackpotToggleStyle(.checkbox) }\n", rel)


def registration_field_chrome(body, rel):
    return drop_from_marker(body, "// MARK: - Divider", rel)


def registration_field_kind(body, rel):
    return require_replace(body, "    public static let oneTimeCode = JackpotFieldKind(keyboard: .numberPad,\n"
                                 "                                                     contentType: .oneTimeCode,\n"
                                 "                                                     capitalization: .never,\n"
                                 "                                                     disablesAutocorrection: true)\n\n",
                           "", rel)


def registration_theme(body, rel):
    body = require_replace(body, "    /// Accent as *text* and tint — tertiary labels, selected shell. This is the Android\n",
                           "    /// Accent as *text* and tint — selected shell. This is the Android\n", rel)
    return require_replace(body, "    public var progressBarHeight: CGFloat = JackpotSpacing.xxs.rawValue\n"
                                 "    public var textAreaMinHeight: CGFloat = 110\n"
                                 "    public var cardMinHeight: CGFloat = 140\n",
                           "    public var progressBarHeight: CGFloat = JackpotSpacing.xxs.rawValue\n", rel)


def registration_form_field(body, rel):
    body = require_replace(
        body,
        "public enum FieldType: Equatable, Hashable, Sendable {\n"
        "    case input\n"
        "    case button\n"
        "    case checkbox\n"
        "    case radio\n"
        "    case radioGroup\n"
        "    case dropdown\n"
        "    case divider\n"
        "    case textArea\n"
        "    case recaptchaV2\n"
        "    case recaptchaV3\n"
        "    case toggle\n"
        "    case welcomeOffer\n"
        "    case unknown(String)\n"
        "\n"
        "    public init(raw: String) {\n"
        "        switch raw.lowercased().replacingOccurrences(of: \" \", with: \"\") {\n"
        "        case \"input\":                    self = .input\n"
        "        case \"button\":                   self = .button\n"
        "        case \"checkbox\":                 self = .checkbox\n"
        "        case \"radio\":                    self = .radio\n"
        "        case \"radiogroup\":               self = .radioGroup\n"
        "        case \"dropdown\", \"select\":       self = .dropdown\n"
        "        case \"divider\":                  self = .divider\n"
        "        case \"textarea\":                 self = .textArea\n"
        "        case \"recapchav2\", \"recaptchav2\": self = .recaptchaV2\n"
        "        case \"recapchav3\", \"recaptchav3\": self = .recaptchaV3\n"
        "        case \"toggle\":                   self = .toggle\n"
        "        case \"welcomeoffer\":             self = .welcomeOffer\n"
        "        default:                         self = .unknown(raw)\n"
        "        }\n"
        "    }\n"
        "\n"
        "    /// Layout-only types hold no value and are never validated or submitted.\n"
        "    public var isDecorative: Bool {\n"
        "        switch self {\n"
        "        case .divider, .button: return true\n"
        "        default:                return false\n"
        "        }\n"
        "    }\n"
        "}\n",
        "public enum FieldType: Equatable, Hashable, Sendable {\n"
        "    case input\n"
        "    case checkbox\n"
        "    case dropdown\n"
        "    case unknown(String)\n"
        "\n"
        "    public init(raw: String) {\n"
        "        switch raw.lowercased().replacingOccurrences(of: \" \", with: \"\") {\n"
        "        case \"input\":              self = .input\n"
        "        case \"checkbox\":           self = .checkbox\n"
        "        case \"dropdown\", \"select\": self = .dropdown\n"
        "        default:                   self = .unknown(raw)\n"
        "        }\n"
        "    }\n"
        "}\n",
        rel,
    )
    body = require_replace(
        body,
        "\npublic struct RadioOption: Identifiable, Equatable, Hashable, Sendable {\n"
        "    public let value: String\n"
        "    public let textKey: String\n"
        "\n"
        "    public var id: String { value }\n"
        "\n"
        "    public init(value: String, textKey: String) {\n"
        "        self.value = value\n"
        "        self.textKey = textKey\n"
        "    }\n"
        "}\n",
        "",
        rel,
    )
    body = require_replace(body, "    public let dropdownOptions: [DropdownOption]\n"
                                 "    public let radioOptions: [RadioOption]\n",
                           "    public let dropdownOptions: [DropdownOption]\n", rel)
    body = require_replace(body, "                dropdownOptions: [DropdownOption], radioOptions: [RadioOption]) {",
                           "                dropdownOptions: [DropdownOption]) {", rel)
    body = require_replace(body, "        self.dropdownOptions = dropdownOptions\n"
                                 "        self.radioOptions = radioOptions\n",
                           "        self.dropdownOptions = dropdownOptions\n", rel)
    return require_replace(body, "        isVisible && !type.isDecorative && !(type == .recaptchaV2 || type == .recaptchaV3)\n",
                           "        isVisible\n", rel)


def registration_form_dto(body, rel):
    body = require_replace(body, "    let fieldDropdowns: [FieldDropdownDTO]?\n"
                                 "    let fieldRadioGroup: [FieldRadioDTO]?\n",
                           "    let fieldDropdowns: [FieldDropdownDTO]?\n", rel)
    return require_replace(
        body,
        "\npublic struct FieldRadioDTO: Decodable {\n"
        "    let value: String\n"
        "    let text: String?\n"
        "}\n",
        "",
        rel,
    )


def registration_form_mapper(body, rel):
    return require_replace(
        body,
        "            dropdownOptions: (dto.fieldDropdowns ?? []).map {\n"
        "                DropdownOption(value: $0.value, textKey: $0.text ?? $0.value, regex: $0.regex)\n"
        "            },\n"
        "            radioOptions: (dto.fieldRadioGroup ?? []).map {\n"
        "                RadioOption(value: $0.value, textKey: $0.text ?? $0.value)\n"
        "            }\n",
        "            dropdownOptions: (dto.fieldDropdowns ?? []).map {\n"
        "                DropdownOption(value: $0.value, textKey: $0.text ?? $0.value, regex: $0.regex)\n"
        "            }\n",
        rel,
    )


def registration_environment(body, rel):
    body = require_replace(body, "    @Entry public var jackpotIsLoading: Bool = false\n"
                                 "    @Entry public var jackpotIsSelected: Bool = false\n",
                           "    @Entry public var jackpotIsLoading: Bool = false\n", rel)
    return require_replace(
        body,
        "\n    func jackpotSelected(_ isSelected: Bool = true) -> some View {\n"
        "        environment(\\.jackpotIsSelected, isSelected)\n"
        "    }\n",
        "",
        rel,
    )


def registration_validator_tests(body, rel):
    return body.replace(", radioOptions: []", "")


def registration_form_model(body, rel):
    return require_replace(
        body,
        "        switch field.type {\n"
        "        case .checkbox, .toggle: return .bool(false)\n"
        "        case .dropdown, .radio, .radioGroup: return .option(\"\")\n"
        "        default: return field.inputType == .calendar ? .empty : .text(\"\")\n"
        "        }\n",
        "        switch field.type {\n"
        "        case .checkbox: return .bool(false)\n"
        "        case .dropdown: return .option(\"\")\n"
        "        default: return field.inputType == .calendar ? .empty : .text(\"\")\n"
        "        }\n",
        rel,
    )


def registration_field_renderer(body, rel):
    body = require_replace(
        body,
        "        switch field.type {\n"
        "        case .input:                    InputFieldView(field: field, model: model)\n"
        "        case .textArea:                 TextAreaFieldView(field: field, model: model)\n"
        "        case .dropdown:                 DropdownFieldView(field: field, model: model)\n"
        "        case .checkbox:                 CheckboxFieldView(field: field, model: model)\n"
        "        case .toggle:                   ToggleFieldView(field: field, model: model)\n"
        "        case .radio, .radioGroup:       RadioGroupFieldView(field: field, model: model)\n"
        "        case .divider:                  JackpotDivider()\n"
        "        case .welcomeOffer:             WelcomeOfferFieldView(field: field, model: model)\n"
        "        case .button:                   EmptyView()          // the form's footer owns navigation\n"
        "        case .recaptchaV2, .recaptchaV3: RecaptchaPlaceholderView(field: field)\n"
        "        case .unknown:                  EmptyView()          // reported via model.unsupportedFields\n"
        "        }\n",
        "        switch field.type {\n"
        "        case .input:    InputFieldView(field: field, model: model)\n"
        "        case .dropdown: DropdownFieldView(field: field, model: model)\n"
        "        case .checkbox: CheckboxFieldView(field: field, model: model)\n"
        "        default:        EmptyView()\n"
        "        }\n",
        rel,
    )
    body = require_replace(
        body,
        "\n/// reCAPTCHA needs a `WKWebView` bridge. The type is recognised without one so the form still\n"
        "/// renders and validates around it.\n"
        "struct RecaptchaPlaceholderView: View {\n"
        "    let field: FormField\n"
        "    @Environment(\\.jackpotTheme) private var theme\n"
        "\n"
        "    var body: some View {\n"
        "        #if DEBUG\n"
        "        Text(\"reCAPTCHA (\\(field.identifier)) — not implemented\")\n"
        "            .jackpotTextStyle(\\.error, color: \\.textSecondary)\n"
        "            .frame(maxWidth: .infinity, minHeight: 60)\n"
        "            .jackpotFieldBackground()\n"
        "        #else\n"
        "        EmptyView()\n"
        "        #endif\n"
        "    }\n"
        "}\n",
        "",
        rel,
    )
    body = require_replace(body, "    /// Only single-line text entry joins return-key navigation. A date opens a picker, and a\n"
                                 "    /// text area needs the return key for newlines.\n",
                           "    /// Only single-line text entry joins return-key navigation. A date opens a picker.\n", rel)
    body = require_replace(body, "    /// Selection binding for dropdowns and radio groups. An empty selection is `.option(\"\")`.\n",
                           "    /// Selection binding for dropdowns. An empty selection is `.option(\"\")`.\n", rel)
    return require_replace(
        body,
        "\n    func radioOptions(for field: FormField) -> [JackpotOption] {\n"
        "        field.radioOptions.map { JackpotOption(id: $0.value, label: localized($0.textKey)) }\n"
        "    }\n",
        "",
        rel,
    )


def registration_checkbox_field(body, rel):
    return require_replace(
        body,
        "\nstruct ToggleFieldView: View {\n"
        "    let field: FormField\n"
        "    @ObservedObject var model: DynamicFormModel\n"
        "\n"
        "    var body: some View {\n"
        "        JackpotLabeledField(error: model.error(for: field)) {\n"
        "            Toggle(model.localized(field.labelKey), isOn: model.bool(for: field))\n"
        "                .toggleStyle(.jackpotSwitch)\n"
        "                .disabled(field.isReadOnly)\n"
        "        }\n"
        "    }\n"
        "}\n",
        "",
        rel,
    )


def registration_preview_fixtures(body, rel):
    body = require_replace(body, "                             dropdowns: [DropdownOption] = [],\n"
                                 "                             radios: [RadioOption] = []) -> FormField {\n",
                           "                             dropdowns: [DropdownOption] = []) -> FormField {\n", rel)
    body = require_replace(body, "            dropdownOptions: dropdowns,\n"
                                 "            radioOptions: radios\n",
                           "            dropdownOptions: dropdowns\n", rel)
    body = require_replace(
        body,
        "    public static let notes = field(\"notes\", type: .textArea, label: \"Notes\",\n"
        "                                    placeholder: \"Anything else?\", required: false)\n"
        "\n"
        "    public static let contactMethod = field(\n"
        "        \"contactMethod\", type: .radioGroup, label: \"Preferred contact method\", required: true,\n"
        "        regex: \"^.+$\",\n"
        "        radios: [\n"
        "            RadioOption(value: \"sms\", textKey: \"SMS\"),\n"
        "            RadioOption(value: \"email\", textKey: \"Email\"),\n"
        "            RadioOption(value: \"whatsapp\", textKey: \"WhatsApp\"),\n"
        "        ]\n"
        "    )\n"
        "\n"
        "    public static let welcomeOffer = field(\n"
        "        \"welcomeOffer\", type: .welcomeOffer, label: \"Select your Welcome Offer:\", required: false,\n"
        "        dropdowns: [\n"
        "            DropdownOption(value: \"depositMatch\", textKey: \"100% Deposit Match\", regex: nil),\n"
        "            DropdownOption(value: \"freeSpins\", textKey: \"50 Free Spins\", regex: nil),\n"
        "        ]\n"
        "    )\n\n",
        "",
        rel,
    )
    return require_replace(body, "    /// Values that make section one valid — useful for previewing the unlocked\n"
                                 "    /// Welcome Offer and the enabled Next button.\n",
                           "    /// Values that make section one valid — useful for previewing the enabled Next button.\n", rel)


def registration_input_field(body, rel):
    return require_replace(body, "        case \"otp\", \"pin\", \"code\":                 return .oneTimeCode\n",
                           "", rel)


def table(headers, rows):
    blocks.append(("table", (headers, rows)))


def rule():
    blocks.append(("hr", None))


# ---------------------------------------------------------------- header

text("# Build Playbook")
text(
    "Create the files in the order given. Run the commands where they appear. Open a PR where\n"
    "marked. Shared sources are reproduced as registration uses them."
)
text(
    "This playbook documents the **registration** path and the **preview harness** that renders\n"
    "those same twelve fields. Registration is `DynamicFormView(formName: .registration)` driven\n"
    "by `JackpotKit/Sources/JackpotFormsUI/Resources/registration.json` (mirrored under Tests).\n"
    "The live CRM schema at `config.jpc.africa/cron/forms/jackpotcity/JZA/registration` uses the\n"
    "same `fieldType` set. Shared theme tokens stay because those screens consume them."
)
text(
    "`JackpotKit` is one package; each folder under `Sources/` is a module, and later PRs append\n"
    "targets to the same manifest. The whole suite runs in a simulator via\n"
    "`xcodebuild -scheme JackpotKit-Package` — there is no macOS destination, because `JackpotUI`\n"
    "imports `UIKit`."
)
text("**153 tests** through PR 5.")
text("### Registration catalog")
text(
    "Twelve fields over two sections. Re-checked against the bundled fixture, the test fixture,\n"
    "and the live CRM response. The `fieldType` values on registration are **Input**,\n"
    "**Dropdown**, and **Checkbox**. Date of birth is `Input` + `inputType: Calender` (the schema\n"
    "spelling)."
)
table(
    ["Step", "Identifier", "`fieldType`", "`inputType`", "Renders as"],
    [
        ["1.1", "`username`", "Input", "Number", "`JackpotTextField` + `+27` prefix (bundled), `.phoneNumber` / `.number`"],
        ["1.2", "`password`", "Input", "Password", "`JackpotTextField` + `JackpotChecklist` while focused"],
        ["1.3", "`firstname`", "Input", "Text", "`JackpotTextField`, `.givenName`"],
        ["1.4", "`lastname`", "Input", "Text", "`JackpotTextField`, `.familyName`"],
        ["1.5", "`email`", "Input", "Email", "`JackpotTextField`, `.email`"],
        ["1.6", "`referralCode`", "Input", "Text", "`JackpotTextField` (optional)"],
        ["2.1", "`idNumberType`", "Dropdown", "Text", "`JackpotDropdown` (drives `idNumber` regex)"],
        ["2.2", "`idNumber`", "Input", "Text", "`JackpotTextField`"],
        ["2.3", "`dateOfBirth`", "Input", "Calender", "`JackpotDateField`"],
        ["2.4", "`sourceOfFunds`", "Dropdown", "Text", "`JackpotDropdown`"],
        ["2.5", "`receivePromotionalInformation`", "Checkbox", "Text", "Toggle + `.jackpotCheckbox`"],
        ["2.6", "`terms`", "Checkbox", "Text", "Toggle + `.jackpotCheckbox` (required `^true$`)"],
    ],
)
text(
    "Live CRM matches those twelve identifiers and three `fieldType`s. The bundled capture still\n"
    "ships `username.prefix = \"+27\"`; the live payload currently leaves prefix empty (the view\n"
    "still maps `username` to `.phoneNumber`)."
)
text(
    "Input and Dropdown keep the label **inside** the control: it sits in the field and floats\n"
    "to the top edge on focus or when the field has a value. `dateOfBirth` keeps\n"
    "`JackpotLabeledField` above `JackpotDateField`. Checkboxes keep the toggle label. Error\n"
    "text stays below the control."
)
text(
    "The form shell actually uses: `JackpotLabeledField` (above-field label on date; error\n"
    "shell on Input / Dropdown / Checkbox), `FormNavigationBar` with `.jackpot` /\n"
    "`.jackpot(.secondary)` (Next / Sign Up / Previous — see below), `.jackpotBar` progress,\n"
    "`JackpotErrorView` on load failure, and the locked colour / spacing / size tokens below."
)
text("### How to go to the next screen")
text(
    "The gold/blue button at the bottom of registration is **host shell** on\n"
    "`FormNavigationBar` in `DynamicFormView.swift`. `RegistrationView` is a thin wrapper\n"
    "around `DynamicFormView`. The bundled `registration.json` and the live CRM schema\n"
    "(`GET …/cron/forms/jackpotcity/JZA/registration?api-version=2.0`) are the twelve fields\n"
    "above — paging is not a field."
)
table(
    ["Visible control", "Style", "When", "Action"],
    [
        ["**Next**", "`.jackpot` (primary)", "Section 1 — not last", "`advance()` → `DynamicFormModel.advance()`"],
        ["**Previous**", "`.jackpot(.secondary)`", "Section 2+", "`goBack()` — values kept"],
        ["**Sign Up**", "`.jackpot` (primary)", "Last section", "`model.submit(onSubmit)`"],
    ],
)
text(
    "`Next` stays **disabled** until every value-carrying field on the visible section\n"
    "validates (`isCurrentSectionValid`). Tapping it marks the section touched, revalidates,\n"
    "and if valid increments `sectionIndex` (step 1 → step 2). `Sign Up` stays disabled until\n"
    "`isFormValid`, then `RegistrationView`'s callback calls `RegistrationService.register`.\n"
    "A progress bar (`.jackpotBar`) sits above the scroll view when `sections.count > 1`.\n"
    "Previous is `surface` + `fieldBorder` + `textPrimary`. Next / Sign Up use `accentFill` +\n"
    "`textOnAccent` when enabled, and the field-fill disabled treatment when not."
)
text("### Registration preview path")
text(
    "`kitchenSink.json` is the bundled **registration-fields** schema — the same twelve\n"
    "identifiers and three `fieldType`s as `registration.json`."
)
text(
    "1. **Schema.** `JackpotFormsUI/Resources/kitchenSink.json` — `formCodeName: kitchenSink`,\n"
    "   `formTitle: Registration fields`. Types: `Input` (Text / Number / Password / Email /\n"
    "   Calender), `Dropdown`, `Checkbox`. Same twelve fields as registration.\n"
    "2. **Name.** `FormName.kitchenSink` is in `FormName.bundled` with `.registration`.\n"
    "3. **Load.** `FormPreviewData.bundledForms` reads both JSON resources into\n"
    "   `StubFormRepository`. `.mock()` and the on-device sandbox use that dictionary.\n"
    "4. **Sandbox.** `FormSandboxView.mocked()` and `RegistrationSandbox` pick\n"
    "   Registration / Registration fields. Both load through `DynamicFormView`.\n"
    "5. **Canvas.** `JackpotForms/Previews.swift` → `DynamicFormView(formName: .kitchenSink)`\n"
    "   titled **Registration fields — from JSON**.\n"
    "6. **FormPreview.** `PreviewFixtures.swift` is the hand-built twin used by per-field\n"
    "   `#Preview`s (`InputFieldView`, `DateFieldView`, …) and by `DynamicFormView` section\n"
    "   previews. The catalog is the twelve registration fields.\n"
    "7. **Gallery.** `JackpotPreviewPanel.swift` is the JackpotUI sheet for registration shell\n"
    "   (text field, checklist, dropdown, date, checkbox, progress, Next / Sign Up / Previous).\n"
    "8. **FormNavigationBar.** Host shell on `DynamicFormView`: Previous (`.jackpot(.secondary)`)\n"
    "   on section 2, Next (`.jackpot`) while a later section exists, Sign Up (`.jackpot`) on\n"
    "   the last section."
)
table(
    ["`fieldType`", "Where it renders"],
    [
        ["Input", "Registration JSON + Gallery + `FormPreview` field previews"],
        ["Dropdown", "Registration JSON + Gallery + `DropdownFieldView` previews"],
        ["Checkbox", "Registration JSON + Gallery + `CheckboxFieldView` previews"],
    ],
)
rule()

# ---------------------------------------------------------------- PR 1

text("## PR 1 — JackpotUI")
text(
    "The design system, with no knowledge of forms. Components take a value and a binding; the theme\n"
    "and the per-field configuration travel through the environment, so no component carries styling\n"
    "parameters. Only the pieces registration and its preview harness render are listed below."
)
text("### Colour tokens")
text(
    "Locked `JackpotColors` set. Same hex is one `Palette` entry — roles that share a value point\n"
    "at it. There is no `link` token; that Android role is `accent`."
)
table(
    ["Token", "Light", "Dark", "Role"],
    [
        ["`surface`", "#FFFFFF", "#131316", "Form / page background, Previous button fill (Android `formBackground`)"],
        ["`fieldBackground`", "#F0F0F2", "#202126", "Field fill, disabled Next / Sign Up, checklist (also Android dialog `background`)"],
        ["`fieldBorder`", "#E1E2E6", "#3E3E48", "Hairline, progress track, Previous button"],
        ["`fieldBorderFocused`", "#E1E1E5", "#E1E1E5", "Focus ring. Shared `Palette.emphasis` hex"],
        ["`fieldBorderInvalid`", "#DF0000", "#FF6B6B", "Invalid ring — same value as `error`"],
        ["`textPrimary`", "#2F2F37", "#E1E1E5", "Titles and values (Android `titleText` / Text Priority)"],
        ["`textSecondary`", "#565A63", "#E1E1E5", "Labels and placeholders"],
        ["`textOnAccent`", "#FFFFFF", "#FFFFFF", "Label on `accentFill`"],
        ["`accent`", "#0060EC", "#4D8FFF", "Tint, selected shell (Android `link`)"],
        ["`accentFill`", "#0060EC", "#0060EC", "Primary button fill"],
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

swift_literal(
    "JackpotKit/Package.swift",
    """// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
    ],
    targets: [
        .target(name: "JackpotUI"),
        .testTarget(name: "JackpotUITests", dependencies: ["JackpotUI"]),
    ]
)
""",
)

files(
    [
        (
            "JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift",
            "Adaptive light/dark palette. Hexes are the locked token table above; `Palette.emphasis`\n"
            "is the shared #E1E1E5 so focused border and dark text are one value, not aliases.",
            registration_theme,
        ),
        (
            "JackpotKit/Sources/JackpotUI/Theme/JackpotEnvironment.swift",
            "`JackpotFieldConfiguration` is what keeps the field views parameter-free: a caller sets\n"
            "`jackpotFieldState`/`jackpotFieldError` once and every field below reads it.",
            registration_environment,
        ),
        "JackpotKit/Sources/JackpotUI/Theme/JackpotStyling.swift",
        (
            "JackpotKit/Sources/JackpotUI/Styles/JackpotButtonStyle.swift",
            "`.jackpot` is Next / Sign Up: `accentFill` + `textOnAccent` when enabled, field fill when\n"
            "disabled. `.jackpot(.secondary)` is Previous: `surface` fill, `fieldBorder` hairline,\n"
            "`textPrimary` label.",
            registration_button_style,
        ),
        (
            "JackpotKit/Sources/JackpotUI/Styles/JackpotToggleStyle.swift",
            "Registration checkboxes use `.jackpotCheckbox`.",
            registration_toggle_style,
        ),
        "JackpotKit/Sources/JackpotUI/Styles/JackpotProgressViewStyle.swift",
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotFieldChrome.swift",
            "The shared background, the in-field floating label, and `JackpotLabeledField` — date\n"
            "keeps the above-field label; Input / Dropdown / Checkbox use it for the error row.",
            registration_field_chrome,
        ),
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotFieldKind.swift",
            "Keyboard / autofill kinds applied with `jackpotField(_:)`. Registration uses text, name,\n"
            "email, phone, number, and new-password.",
            registration_field_kind,
        ),
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotTextField.swift",
            "In-field label floats on focus or when the field has a value. Prefix cell and\n"
            "secure reveal stay as they were.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotDropdown.swift",
            "In-field label floats when a value is selected.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotDateField.swift",
            "The `Calender` input type: a read-only field presenting a graphical picker in a sheet.\n"
            "`DateFieldView` wraps it in `JackpotLabeledField` so the label stays above the control.",
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
            "JackpotKit/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift",
            "The panel wraps a preview in the themed surface. Resume **Gallery** for registration\n"
            "shell (Input / Dropdown / Checkbox / date / FormNavigationBar buttons).",
        ),
        "JackpotKit/Tests/JackpotUITests/JackpotThemeTests.swift",
    ]
)

bash(TEST_CMD)
rule()
text("### ▶ Create PR — JackpotUI")
text("`JackpotUITests: Executed 13 tests, with 0 failures`")
text(
    "Open `JackpotPreviewPanel.swift` and resume the **Gallery** preview. Then check the\n"
    "registration field previews on `JackpotTextField`, `JackpotDropdown`, `JackpotDateField`,\n"
    "and `JackpotChecklist`."
)
rule()

# ---------------------------------------------------------------- PR 2

text("## PR 2 — JackpotForms")
text(
    "Three modules pointing one way: `JackpotFormsDomain` (types and rules, no I/O),\n"
    "`JackpotFormsData` (wire shapes and the bundled stub), `JackpotFormsUI` (the engine and the\n"
    "renderer). Nothing here knows how a form is fetched — the engine only ever sees\n"
    "`FormRepository`, which is what lets PR 3 swap the stub for the network without touching it.\n"
    "The catalog is the registration schema: Input, Dropdown, and Checkbox."
)

bash(
    "mkdir -p JackpotKit/Sources/{JackpotFormsDomain,JackpotFormsData}\n"
    "mkdir -p JackpotKit/Sources/JackpotFormsUI/{Fields,Demo,Resources}\n"
    "mkdir -p JackpotKit/Tests/JackpotFormsTests/Fixtures"
)

swift_literal(
    "JackpotKit/Package.swift",
    """        .library(
            name: "JackpotForms",
            targets: ["JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI"]
        ),

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
""",
    suffix=" — add to `products:` and `targets:`",
)

files(
    [
        (
            "JackpotKit/Sources/JackpotFormsDomain/FormName.swift",
            "`.registration` is the live form. `.kitchenSink` is the bundled registration-fields\n"
            "preview schema — same twelve fields, loaded by Canvas and the sandbox.",
        ),
        "JackpotKit/Sources/JackpotFormsDomain/FormValue.swift",
        (
            "JackpotKit/Sources/JackpotFormsDomain/FormField.swift",
            "Registration constructs Input, Dropdown, and Checkbox (plus `InputType.calendar` for DOB).",
            registration_form_field,
        ),
        "JackpotKit/Sources/JackpotFormsDomain/Form.swift",
        "JackpotKit/Sources/JackpotFormsDomain/FormSubmitResult.swift",
        "JackpotKit/Sources/JackpotFormsDomain/PasswordPolicy.swift",
        (
            "JackpotKit/Sources/JackpotFormsDomain/RegexResolving.swift",
            "How a dropdown changes another field's rule: the schema names a pattern, this resolves it.",
        ),
        "JackpotKit/Sources/JackpotFormsDomain/FieldValidator.swift",
        "JackpotKit/Sources/JackpotFormsDomain/FormLoadError.swift",
        "JackpotKit/Sources/JackpotFormsDomain/FormLocalizing.swift",
        "JackpotKit/Sources/JackpotFormsDomain/FormRepository.swift",
        (
            "JackpotKit/Sources/JackpotFormsData/FormDTO.swift",
            None,
            registration_form_dto,
        ),
        (
            "JackpotKit/Sources/JackpotFormsData/FormMapper.swift",
            None,
            registration_form_mapper,
        ),
        "JackpotKit/Sources/JackpotFormsData/StubFormRepository.swift",
    ]
)

bash(
    "cp registration.json JackpotKit/Sources/JackpotFormsUI/Resources/registration.json\n"
    "cp kitchenSink.json  JackpotKit/Sources/JackpotFormsUI/Resources/kitchenSink.json\n"
    "cp JackpotKit/Sources/JackpotFormsUI/Resources/registration.json \\\n"
    "   JackpotKit/Tests/JackpotFormsTests/Fixtures/registration.json",
    note="`registration.json` is the CRM's response saved verbatim — 12 fields over two sections.\n"
    "`kitchenSink.json` is the bundled registration-fields preview of those same twelve fields\n"
    "(Input / Dropdown / Checkbox only). `JackpotFormsUI` processes both as resources. The\n"
    "fixture mirror lets the suites load registration from their own `Bundle.module`.",
)

files(
    [
        "JackpotKit/Sources/JackpotFormsUI/FormDependencies.swift",
        (
            "JackpotKit/Sources/JackpotFormsUI/DynamicFormModel.swift",
            "The engine. `advance()` / `goBack()` / `submit()` are what Next, Previous, and Sign Up\n"
            "call. `touched` is why an untouched field stays silent until Next, and\n"
            "`applyRegexDependencies` is how selecting Passport relaxes the SA-ID rule on a\n"
            "different field.",
            registration_form_model,
        ),
        (
            "JackpotKit/Sources/JackpotFormsUI/Demo/PreviewFixtures.swift",
            "Hand-built `FormPreview` fixtures. `registration` mirrors the CRM schema — the twelve\n"
            "registration fields.",
            registration_preview_fixtures,
        ),
        (
            "JackpotKit/Sources/JackpotFormsUI/Fields/FieldRenderer.swift",
            "The switch is the whole contract. Registration hits `.input` (Calender →\n"
            "`DateFieldView`), `.dropdown`, and `.checkbox`.",
            registration_field_renderer,
        ),
        (
            "JackpotKit/Sources/JackpotFormsUI/Fields/InputFieldView.swift",
            None,
            registration_input_field,
        ),
        "JackpotKit/Sources/JackpotFormsUI/Fields/DropdownFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Fields/DateFieldView.swift",
        (
            "JackpotKit/Sources/JackpotFormsUI/Fields/CheckboxFieldView.swift",
            "`receivePromotionalInformation` and `terms`.",
            registration_checkbox_field,
        ),
        (
            "JackpotKit/Sources/JackpotFormsUI/DynamicFormView.swift",
            "`FormNavigationBar` is the Next / Previous / Sign Up shell. That is how step 1 becomes\n"
            "step 2. `RegistrationView` just hosts this view.",
        ),
        (
            "JackpotKit/Sources/JackpotFormsUI/Demo/PreviewSupport.swift",
            "Registration copy table, plus `FormPreviewData.bundledForms` (registration + registration-fields preview).",
        ),
        (
            "JackpotKit/Sources/JackpotFormsUI/Demo/FormSandboxView.swift",
            "The review harness: pick Registration or Registration fields and submit into a sheet.\n"
            "`RegistrationSandbox` in the app target wraps this.",
        ),
        "JackpotKit/Tests/JackpotFormsTests/FormDecodingTests.swift",
        (
            "JackpotKit/Tests/JackpotFormsTests/FieldValidatorTests.swift",
            None,
            registration_validator_tests,
        ),
        (
            "JackpotKit/Tests/JackpotFormsTests/DynamicFormModelTests.swift",
            "The behaviour a user experiences: untouched fields stay silent, Next reveals every error at\n"
            "once, section gating, submit blocked while invalid, and the payload keyed by\n"
            "`fieldIdentifier`.",
        ),
    ]
)

bash(TEST_CMD)
rule()
text("### ▶ Create PR — JackpotForms")
text("`JackpotFormsTests: Executed 49 tests, with 0 failures`")
text(
    "Open `DynamicFormView.swift` and resume the registration whole-form previews. Open\n"
    "`JackpotForms/Previews.swift` and resume **Registration fields — from JSON**."
)
rule()

# ---------------------------------------------------------------- PR 3

text("## PR 3 — JackpotNetworking + the live repository")
text(
    "The transport, then the repository built on it. `JackpotFormsUI` is untouched in this PR — that\n"
    "is the point of the protocol. `JackpotForms` arrives as the composition target: it is the only\n"
    "module that sees both the network and the UI, so it is the only one that has to change when the\n"
    "wiring does."
)

bash(
    "mkdir -p JackpotKit/Sources/{JackpotNetworking,JackpotLocalization,JackpotFormsRemote,JackpotForms}\n"
    "mkdir -p JackpotKit/Tests/{JackpotNetworkingTests,JackpotLocalizationTests}"
)

swift_literal(
    "JackpotKit/Package.swift",
    """        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),

        .target(name: "JackpotNetworking"),
        .target(name: "JackpotLocalization"),
        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),
        .testTarget(name: "JackpotLocalizationTests", dependencies: ["JackpotLocalization"]),

        .target(
            name: "JackpotFormsRemote",
            dependencies: ["JackpotFormsDomain", "JackpotFormsData", "JackpotNetworking"]
        ),
        .target(
            name: "JackpotForms",
            dependencies: [
                "JackpotFormsDomain",
                "JackpotFormsData",
                "JackpotFormsUI",
                "JackpotFormsRemote",
                "JackpotLocalization",
                "JackpotNetworking",
            ]
        ),
""",
    suffix=" — add to `products:` and `targets:`",
    note="`JackpotFormsRemote` and `JackpotForms` join the `JackpotForms` library product, and\n"
    "`JackpotFormsTests` gains all four new targets as dependencies.",
)

files(
    [
        "JackpotKit/Sources/JackpotNetworking/HTTPMethod.swift",
        "JackpotKit/Sources/JackpotNetworking/HTTPClient.swift",
        "JackpotKit/Sources/JackpotNetworking/APIEnvironment.swift",
        "JackpotKit/Sources/JackpotNetworking/APIEndpoint.swift",
        "JackpotKit/Sources/JackpotNetworking/APIError.swift",
        "JackpotKit/Sources/JackpotNetworking/RequestInterceptor.swift",
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
    ]
)

bash(TEST_CMD, note="`JackpotNetworkingTests: Executed 34 tests`. Now the repository.")

files(
    [
        (
            "JackpotKit/Sources/JackpotLocalization/Translations.swift",
            "The session's localisation table. Two lookups matter: keys are tried region-suffixed first\n"
            "(`terms-jza` before `terms`), and API error codes are keys too, which is what lets a server\n"
            "error come back in the user's language.",
        ),
        "JackpotKit/Sources/JackpotFormsRemote/CRMEnvironment.swift",
        "JackpotKit/Sources/JackpotFormsRemote/FormEndpoints.swift",
        (
            "JackpotKit/Sources/JackpotFormsRemote/FormErrorMapper.swift",
            "The boundary that decides what the user reads. `JackpotFormsUI` cannot see `APIError`, so\n"
            "anything not translated here becomes a generic failure on screen.",
        ),
        "JackpotKit/Sources/JackpotFormsRemote/RemoteFormRepository.swift",
        "JackpotKit/Sources/JackpotForms/TranslationsLocalizer.swift",
        (
            "JackpotKit/Sources/JackpotForms/JackpotForms.swift",
            "The composition root: `.mock` for previews (bundled registration + registration-fields),\n"
            "`.live` for the app. `FormSandboxView.mocked()` is the preview harness.",
        ),
        (
            "JackpotKit/Sources/JackpotForms/Previews.swift",
            "JSON-backed previews: registration (loading / offline / 404) and\n"
            "`DynamicFormView(formName: .kitchenSink)` — **Registration fields — from JSON**.",
        ),
        "JackpotKit/Tests/JackpotLocalizationTests/TranslationsTests.swift",
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
text("### ▶ Create PR — JackpotNetworking + live repository")
text(
    "`JackpotNetworkingTests: Executed 34 tests, with 0 failures`\n"
    "`JackpotLocalizationTests: Executed 16 tests, with 0 failures`\n"
    "`JackpotFormsTests: Executed 81 tests, with 0 failures`"
)
rule()

# ---------------------------------------------------------------- PR 4

text("## PR 4 — JackpotRegistration")
text(
    "The feature: a registration service, the screen that drives the two-page form, and the\n"
    "`UIHostingController` the existing popup container can hold as-is."
)

bash(
    "mkdir -p JackpotKit/Sources/JackpotRegistration\n"
    "mkdir -p JackpotKit/Tests/JackpotRegistrationTests"
)

swift_literal(
    "JackpotKit/Package.swift",
    """        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),

        .target(
            name: "JackpotRegistration",
            dependencies: [
                "JackpotUI",
                "JackpotForms",
                "JackpotFormsDomain",
                "JackpotFormsUI",
                "JackpotNetworking",
            ]
        ),
        .testTarget(
            name: "JackpotRegistrationTests",
            dependencies: [
                "JackpotRegistration",
                "JackpotFormsDomain",
                "JackpotForms",
                "JackpotNetworking",
            ]
        ),
""",
    suffix=" — add to `products:` and `targets:`",
)

files(
    [
        "JackpotKit/Sources/JackpotRegistration/RegistrationService.swift",
        (
            "JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift",
            "`RegistrationView` hosts `DynamicFormView(formName: .registration)`. Next / Previous /\n"
            "Sign Up live in `FormNavigationBar`.",
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
text("`JackpotRegistrationTests: Executed 9 tests, with 0 failures`")
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
""",
    note="`ClosureLocalizer` is the migration seam. The app's `getTranslation` returns the key itself on\n"
    "a miss; mapping that back to `nil` is what lets the engine fall through to humanised copy instead\n"
    "of rendering a raw key.",
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

FORBIDDEN = (
    r"\.jackpot\(\.tertiary\)",
    r"case tertiary",
    r"Prominence\.tertiary",
    r"case \.tertiary",
    r"JackpotCardButtonStyle",
    r"jackpotSwitch",
    r"JackpotDivider",
    r"ToggleFieldView",
    r"RadioOption",
    r"FieldRadioDTO",
    r"fieldRadioGroup",
    r"radioOptions",
    r"WelcomeOffer",
    r"TextAreaFieldView",
    r"JackpotTextArea",
    r"RecaptchaPlaceholderView",
    r"SignaturePad",
    r"jackpotIsSelected",
    r"jackpotSelected",
    r"### Out of scope",
    r"tertiary",
)
for pattern in FORBIDDEN:
    if re.search(pattern, markdown, re.IGNORECASE):
        sys.exit(f"playbook still contains {pattern!r}")

with open(OUT, "w") as f:
    f.write(markdown)
print(f"wrote {OUT}: {markdown.count(chr(10))} lines, {step} steps")

if "--pdf" in sys.argv:
    from weasyprint import HTML

    page = render_html()
    HTML(string=page, base_url=ROOT).write_pdf(OUT_PDF)
    print(f"wrote {OUT_PDF}: {os.path.getsize(OUT_PDF) / 1_048_576:.1f} MB")
