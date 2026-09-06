#!/usr/bin/env python3
"""Rebuild docs/BUILD-PLAYBOOK.md (and .pdf) from the files actually on disk.

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
            file_step(item[0], note=item[1])
        else:
            file_step(item)


def rule():
    blocks.append(("hr", None))


# ---------------------------------------------------------------- header

text("# Build Playbook")
text(
    "Create the files in the order given. Run the commands where they appear. Open a PR where\n"
    "marked. Every file is reproduced in full, so a step is done when the file matches."
)
text(
    "`JackpotKit` is one package; each folder under `Sources/` is a module, and later PRs append\n"
    "targets to the same manifest. The whole suite runs in a simulator via\n"
    "`xcodebuild -scheme JackpotKit-Package` — there is no macOS destination, because `JackpotUI`\n"
    "imports `UIKit`."
)
text("**152 tests** through PR 5. The follow-up section takes it to 181.")
rule()

# ---------------------------------------------------------------- PR 1

text("## PR 1 — JackpotUI")
text(
    "The design system, with no knowledge of forms. Components take a value and a binding; the theme\n"
    "and the per-field configuration travel through the environment, so no component carries styling\n"
    "parameters."
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
        "JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift",
        (
            "JackpotKit/Sources/JackpotUI/Theme/JackpotEnvironment.swift",
            "`JackpotFieldConfiguration` is what keeps the field views parameter-free: a caller sets\n"
            "`jackpotFieldState`/`jackpotFieldError` once and every field below reads it.",
        ),
        "JackpotKit/Sources/JackpotUI/Theme/JackpotStyling.swift",
        "JackpotKit/Sources/JackpotUI/Styles/JackpotButtonStyle.swift",
        "JackpotKit/Sources/JackpotUI/Styles/JackpotToggleStyle.swift",
        "JackpotKit/Sources/JackpotUI/Styles/JackpotProgressViewStyle.swift",
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotFieldChrome.swift",
            "The shared background and the label/error row every field sits in.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotFieldKind.swift",
            "One value per input type the registration schema asks for, applied with `jackpotField(_:)`.",
        ),
        "JackpotKit/Sources/JackpotUI/Fields/JackpotTextField.swift",
        "JackpotKit/Sources/JackpotUI/Fields/JackpotTextArea.swift",
        "JackpotKit/Sources/JackpotUI/Fields/JackpotDropdown.swift",
        "JackpotKit/Sources/JackpotUI/Fields/JackpotRadioGroup.swift",
        (
            "JackpotKit/Sources/JackpotUI/Fields/JackpotDateField.swift",
            "The `Calender` input type: a read-only field presenting a graphical picker in a sheet.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotChecklist.swift",
            "The live password-rules panel.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotErrorView.swift",
            "Shown when a form fails to load.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Components/JackpotLockedOverlay.swift",
            "Dims and un-hits content gated behind something else — the Welcome offer picker, until the\n"
            "fields above it validate.",
        ),
        (
            "JackpotKit/Sources/JackpotUI/Preview/JackpotPreviewPanel.swift",
            "The panel wraps a preview in the themed surface; the gallery is how you check the components\n"
            "without running the app.",
        ),
        "JackpotKit/Tests/JackpotUITests/JackpotThemeTests.swift",
    ]
)

bash(TEST_CMD)
rule()
text("### ▶ Create PR — JackpotUI")
text("`JackpotUITests: Executed 13 tests, with 0 failures`")
text("Open `JackpotPreviewPanel.swift` and resume the **Gallery** preview.")
rule()

# ---------------------------------------------------------------- PR 2

text("## PR 2 — JackpotForms")
text(
    "Three modules pointing one way: `JackpotFormsDomain` (types and rules, no I/O),\n"
    "`JackpotFormsData` (wire shapes and the bundled stub), `JackpotFormsUI` (the engine and the\n"
    "renderer). Nothing here knows how a form is fetched — the engine only ever sees\n"
    "`FormRepository`, which is what lets PR 3 swap the stub for the network without touching it."
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
        "JackpotKit/Sources/JackpotFormsDomain/FormName.swift",
        "JackpotKit/Sources/JackpotFormsDomain/FormValue.swift",
        "JackpotKit/Sources/JackpotFormsDomain/FormField.swift",
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
        "JackpotKit/Sources/JackpotFormsData/FormDTO.swift",
        "JackpotKit/Sources/JackpotFormsData/FormMapper.swift",
        "JackpotKit/Sources/JackpotFormsData/StubFormRepository.swift",
    ]
)

bash(
    "cp registration.json JackpotKit/Sources/JackpotFormsUI/Resources/registration.json\n"
    "cp kitchenSink.json  JackpotKit/Sources/JackpotFormsUI/Resources/kitchenSink.json\n"
    "cp JackpotKit/Sources/JackpotFormsUI/Resources/registration.json \\\n"
    "   JackpotKit/Tests/JackpotFormsTests/Fixtures/registration.json",
    note="`registration.json` is the CRM's response saved verbatim — 12 fields over two sections;\n"
    "`kitchenSink.json` exercises the field types the real schema doesn't use. `JackpotFormsUI`\n"
    "processes both as resources. The mirror under `Fixtures/` lets the suites load the schema from\n"
    "their own `Bundle.module` instead of reaching into another target's.",
)

files(
    [
        "JackpotKit/Sources/JackpotFormsUI/FormDependencies.swift",
        (
            "JackpotKit/Sources/JackpotFormsUI/DynamicFormModel.swift",
            "The engine. Two things here are worth reading closely: `touched` is why an untouched field\n"
            "stays silent until Next, and `applyRegexDependencies` is how selecting Passport relaxes the\n"
            "SA-ID rule on a different field.",
        ),
        "JackpotKit/Sources/JackpotFormsUI/Demo/PreviewFixtures.swift",
        (
            "JackpotKit/Sources/JackpotFormsUI/Fields/FieldRenderer.swift",
            "The switch below is the whole contract between the form builder and the app.",
        ),
        "JackpotKit/Sources/JackpotFormsUI/Fields/InputFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Fields/TextAreaFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Fields/DropdownFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Fields/RadioGroupFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Fields/DateFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Fields/CheckboxFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Fields/WelcomeOfferFieldView.swift",
        "JackpotKit/Sources/JackpotFormsUI/DynamicFormView.swift",
        "JackpotKit/Sources/JackpotFormsUI/Demo/PreviewSupport.swift",
        "JackpotKit/Sources/JackpotFormsUI/Demo/FormSandboxView.swift",
        "JackpotKit/Tests/JackpotFormsTests/FormDecodingTests.swift",
        "JackpotKit/Tests/JackpotFormsTests/FieldValidatorTests.swift",
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
text("`JackpotFormsTests: Executed 48 tests, with 0 failures`")
text("Open `DynamicFormView.swift` and resume the whole-form previews.")
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
        (
            "JackpotKit/Sources/JackpotNetworking/ConditionalRequest.swift",
            "`ETag`/`Last-Modified` handling. Nothing in this PR sends a conditional request; it is here\n"
            "because `APIError` and the client have to agree on what a 304 means, and the follow-up\n"
            "app-data loader is built on it.",
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
            "The composition root: `.mock` for previews and the sandbox, `.live` for the app.",
        ),
        "JackpotKit/Sources/JackpotForms/Previews.swift",
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
    "`JackpotFormsTests: Executed 80 tests, with 0 failures`"
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
        "JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift",
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

# ---------------------------------------------------------------- follow-up

text("## Follow-up — app-data and the translations store")
text(
    "Not one of the five, and not reproduced here. `JackpotAppData` and the rest of\n"
    "`JackpotLocalization` are already in the package:"
)
text(
    "- `AppData.swift` — `AppDataResponse` decodes the once-per-session bootstrap payload one section\n"
    "  at a time, so a malformed `sportsbook` block cannot cost you the translations.\n"
    "- `AppDataCache.swift`, `AppDataLoader.swift` — stale-while-revalidate over `ETag`, which is why\n"
    "  `ConditionalRequest.swift` exists in PR 3.\n"
    "- `TranslationsRepository.swift`, `TranslationsStore.swift` — fetching the table and holding it for\n"
    "  the session. This is the pair that makes `JackpotLocalization` depend on `JackpotNetworking` and\n"
    "  `JackpotAppData`; PR 3 only needs `Translations.swift`, which depends on neither."
)
text(
    "Adopting them turns `getTranslation` into a shim over `Translations` and replaces the\n"
    "`ClosureLocalizer` above with `TranslationsLocalizer`, at which point `.live(translations:)`\n"
    "replaces `.live(localizer:)` and the seam is gone. See `docs/OPEN-QUESTIONS.md` and\n"
    "`docs/adr/0001-app-data-decoding-and-configuration-decomposition.md`."
)
text(
    "`JackpotAppDataTests: Executed 23 tests` · `JackpotLocalizationTests: Executed 22 tests`\n"
    "(the 16 above plus 6 for the store) — **181 in total**."
)

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
