# Delivery Plan — Six Steps

The feature is built **entirely in packages** and demoable at every step. The app changes once,
at step 4, which swaps the current flow for the package and deletes the old one. Steps 5 and 6
are the localisation and app-data migrations from
[ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md); registration does
not wait for them. No feature flags; the app has none and this plan doesn't introduce any.

**Principles**

- **UI first, to show progress.** Step 1 is visible components. Step 2 is the whole Sign Up
  sheet on the captured schema, with no backend.
- **Mock before live.** The engine ships with a `FormRepository` protocol and a bundled-JSON
  implementation. The live one arrives at step 4 and replaces the stub at one line in
  composition.
- **The app is touched once.** Steps 1 to 3 are additive package code nobody calls. Step 4 is
  a swap plus a delete.
- **Localisation last.** The feature ships on the existing `getTranslation`, wrapped. The
  migration off it is step 5, and it changes nothing about registration.

The build order, file by file, is [BUILD-PLAYBOOK.md](BUILD-PLAYBOOK.md).

---

## Overview

| # | Step | Modules | Demoable as | Tests |
|---|---|---|---|---|
| 1 | **`JackpotUI`** — design system | JackpotUI | the gallery preview: every component, every state | 20 |
| 2 | **`JackpotForms` on the bundled schema** + **`JackpotRegistration`** | JackpotForms, JackpotRegistration | the Sign Up sheet, both pages, mock service | 55 |
| 3 | **`JackpotNetworking`** | JackpotNetworking | `RemoteApiClient` against a stubbed transport | 34 |
| 4 | **Connect forms to the network; replace the flow in the app** | JackpotForms/Remote + app | registration live in the app, copy from `getTranslation` | 21 |
| 5 | **Fix translations** | JackpotLocalization | `getTranslation` becomes a shim over the store; registration untouched | 18 |
| 6 | **Fix app data** | JackpotAppData | config served from disk on launch, revalidated behind it | 23 |

```
JackpotUI ──► JackpotForms + JackpotRegistration (stub) ──► JackpotNetworking ──► live + app swap ──► translations ──► app data
```

171 tests through step 6. Everything lives in one local package, `JackpotKit`; each row above
is a module inside it, not a package of its own. The manifest is built up step by step in the
playbook, and the generator checks its final step against `Package.swift`.

---

## Step 1 · `JackpotUI` — the design system

Components only. No data, no networking, no notion of a form. Everything is driven by
`Binding`s and plain values, so any feature can use it and every component previews alone.
Field data — title, kind, prefix — is an initialiser argument; the environment carries only what
cascades: the theme, a button's loading state, the shared focus value.

| Component | Replaces |
|---|---|
| `JackpotTheme` · `.jackpotTheme()` | ad-hoc colours per nib |
| `JackpotButtonStyle` | gold/blue buttons redrawn per screen |
| `JackpotTextField` — floating label, prefix cell, secure reveal, focus ring | the `+27` mobile field, password field |
| `JackpotDropdown`, `JackpotDateField` | |
| `JackpotCheckboxToggleStyle` | the T&C and promotions checkboxes |
| `JackpotChecklist` — progress bar + tickable rows | the Password Validity panel |
| `.jackpotFieldError(_:)` | per-screen red borders and captions |
| `JackpotProgressViewStyle`, `JackpotErrorView` | |
| `JackpotPanel` — title, close button, content, footer band | the Sign Up popup shell |
| `JackpotLinkRow` | the "Already have an account? Login" row |
| `.jackpotPopup(isPresented:)` | the popup container, for SwiftUI hosts |

Only what registration draws. The theme, the style protocols and `FieldRenderer`'s switch are
the extension points; the next component is designed against the next real schema.

**Review:** open the gallery preview in `JackpotPreviewPanel.swift`. 20 tests.

## Step 2 · `JackpotForms` on the bundled schema, and `JackpotRegistration`

The engine, with no network: one module, three folders pointing one way.

| Folder | Holds |
|---|---|
| `Domain` | `FormSchema`, `FormField` (with `accepts(_:overrideRegex:)`), `FormName`, `FormValue`, `FormSubmitResult`, `FormError`, the `FormRepository` protocol |
| `Data` | the wire DTOs, each mapping to its domain value (internal); `StubFormRepository`, serving the captured `registration.json` |
| `UI` | `DynamicFormModel`, `DynamicFormContent`, `FormNavigationBar`, `FormDependencies` (+ `.mock()` and the placeholder copy), `FieldRenderer` binding the model to the `JackpotUI` components, `InputFieldView` for text entry |

The engine's defaults are generic — no cross-field regex links, no date cap. Registration's
rules come with the feature, in the same step:

| File | Holds |
|---|---|
| `RegistrationFeature.swift` | `RegistrationDependencies` (`.mock()` for demos; applies the ID-type link and the 18-year date cap), `RegistrationView` — the pages inside `JackpotPanel`, the login row and navigation in its footer, with `onClose`, `onLogin` and `onComplete`; `RegistrationResult` is `FormSubmitResult` under the app's name |
| `RegistrationPanelController.swift` | a `UIHostingController` sized for the legacy popup container |

**Review:** `FieldRenderer.swift` (the CRM↔app contract), `FormField.swift` (`accepts`, untrusted
regexes), `DynamicFormModel.swift` (touched state, section gating, ID-type → ID-number), then
the previews in `JackpotRegistration/Previews.swift`: the full flow, both pages, success and
the duplicate-mobile failure path, with no app and no backend. 55 tests.

## Step 3 · `JackpotNetworking`

`HTTPClient`, `APIEndpoint`, `APIError`, interceptors, `RemoteApiClient`. 200 / 400 / 401 / 500
with `unexpectedStatus` for anything infrastructure returns. Nothing here needs translations:
the app keeps `getTranslation`.

**Review:** `RemoteApiClientTests` (the retry policy) and the `APIProblem.code`-is-an-`Int` fix.
34 tests.

## Step 4 · Connect the forms to the network, and replace the flow in the app

`JackpotForms/Remote` — `RemoteFormRepository` (fetch, submit, the error boundary, `.live()`)
and the endpoints. The engine and the sheet are untouched; `.mock()` becomes
`.live(baseURL:translate:)` at one call site, and `translate` is the app's existing
`getTranslation` passed as a closure: a key in, its text out, the key itself on a miss. No
adapter type. Then the only change to the app, in two parts:

**1. Present the package where the old popup was** (~14 lines):

```swift
let controller = RegistrationPanelController(
    dependencies: RegistrationDependencies(
        forms: .live(baseURL: configURL, translate: { getTranslation(Key: $0) })
    ),
    onClose: { popupContainer.dismiss() },
    onLogin: { popupContainer.dismiss(); presentLogin() }
) { result in
    // route to OTP / login / home
}
addChild(controller)
popupContainer.show(controller.view)
controller.didMove(toParent: self)
```

**2. Delete the old flow:** `registrationPopup`, `flowOneViewController`, `flowTwoViewController`,
their nibs, their `GlobalData` handles.

Net negative. The diff is small enough to review in one sitting and revert in one commit.

**Review:** `RemoteFormRepository.swift` (HTTP 200 is not success; `userFacing`) and the app diff. 21 tests.

## Step 5 · Fix translations

ADR-0001 phase 2. `JackpotLocalization` — `Translations` (the table, normalised once;
region-suffixed lookup), `TranslationsRepository`, `TranslationsStore`.
In the app: `getTranslation` becomes a shim over the store (app-wide performance fix, zero
call-site changes, deprecation warnings as the burn-down list). Registration needs no change:
the closure it was given at step 4 now reads the store. 18 tests.

## Step 6 · Fix app data

ADR-0001 phase 1 and [LAUNCH-PERFORMANCE](LAUNCH-PERFORMANCE.md). `JackpotAppData` —
`AppDataResponse` (section-wise ingestion, the `ConfigData` decode fix), `FileAppDataCache`,
`AppDataLoader` (stale-while-revalidate), `RemoteTranslationsRepository` feeding the store from
the same payload. In the app: bootstrap from the loader, cache first. 23 tests.

---

## Sequencing notes

**What's demoable when.** After step 1, components. After step 2, the entire sheet on a device
from this repository's sandbox. After step 4, registration live in the app. Steps 5 and 6
change nothing visible to a registering user.

**Useful stopping point.** After step 3 the app is untouched and nothing is lost. After step 4
the old flow is gone and there is no going back without a revert — which is fine, because step
4 is one commit.

**What must not be dropped.** The delete in step 4. Landing the swap without the delete leaves
two sign-up flows in the tree.
