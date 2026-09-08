# Delivery Plan — PR Sequence

Five PRs. The feature is built **entirely in packages**, demoable at every step, and the app
changes once — in the last PR, which swaps the current flow for the package and deletes the old
one. No feature flags; the app has none and this plan doesn't introduce any.

**Principles**

- **UI first, to show progress.** PR 1 is visible components. PR 3 renders the real captured
  schema and, in the same module, fetches the live one. PR 4 is the complete registration
  feature running on a device from the sandbox.
- **Mock before live.** The forms engine ships with a `FormRepository` protocol and a
  bundled-JSON implementation. The live one is the same module's `Remote/` folder and replaces
  the stub at one line in composition.
- **The app is touched once.** Everything up to PR 5 is additive package code nobody calls.
  PR 5 is a swap plus a delete.
- **Localisation last.** The feature ships on the existing `getTranslation`, wrapped. The
  migration off it is a separate follow-up — see [ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md).

---

## Overview

| # | PR | Modules | Demoable as | Tests |
|---|---|---|---|---|
| 1 | **`JackpotUI`** — design system | JackpotUI | the gallery preview: every component, every state | 20 |
| 2 | **`JackpotNetworking`** + `Translations` | JackpotNetworking, JackpotLocalization | `RemoteApiClient` against a stubbed transport | 50 |
| 3 | **`JackpotForms`** — the engine, stub and live | JackpotForms | the sandbox rendering the captured registration schema; `.live()` fetching the real one | 83 |
| 4 | **`JackpotRegistration`** — the feature, complete | JackpotRegistration | the full registration flow, mock service, on a device | 11 |
| 5 | **Replace the current flow** | app | registration live in the app; old sign-up gone | — |
| — | App-data follow-up | JackpotAppData, JackpotLocalization (store) + app | | 29 |

```
JackpotUI ──► JackpotNetworking + Translations ──► JackpotForms (stub + live) ──► JackpotRegistration ──► app swap
```

164 tests through PR 5, 193 with the follow-up. Everything lives in one local package,
`JackpotKit`; each row above is a module inside it, not a package of its own. The build order,
file by file, is [BUILD-PLAYBOOK.md](BUILD-PLAYBOOK.md).

Every PR up to 4 is package-only. Reviewers can pull the branch and see the result without the
app building at all.

---

## PR 1 · `JackpotUI` — the design system

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

## PR 2 · `JackpotNetworking` + `Translations`

- **`JackpotNetworking`** — `HTTPClient`, `APIEndpoint`, `APIError`, interceptors,
  `RemoteApiClient`. 200 / 400 / 401 / 500 with `unexpectedStatus` for anything infrastructure
  returns. 34 tests.
- **`JackpotLocalization`** — `Translations` only for now: the table, region-suffixed lookup, and
  error codes as keys. 16 tests. `TranslationsStore` and `TranslationsRepository` in the same
  module are the follow-up.

**Review:** `RemoteApiClientTests` (the retry policy) and the `APIProblem.code`-is-an-`Int` fix.

## PR 3 · `JackpotForms` — the engine

One module, four folders pointing one way.

| Folder | Holds |
|---|---|
| `Domain` | `FormSchema`, `FormField`, `FormName`, `FieldValidator`, `PasswordPolicy`, `FormLoadError`, `ClosureLocalizer`, the `FormRepository` / `FormLocalizing` protocols |
| `Data` | wire DTOs and the mapper (internal), `StubFormRepository`, `BundledForms` (the captured `registration.json`), the placeholder copy table |
| `UI` | `DynamicFormModel`, `DynamicFormContent`, `FormNavigationBar`, `DynamicFormView` (the two stacked), `FormDependencies` (+ `.mock()`), one thin field view per type binding the model to a `JackpotUI` component |
| `Remote` | `RemoteFormRepository`, endpoints, `FormErrorMapper`, `TranslationsLocalizer`, `.live()` |

The engine's defaults are generic — no cross-field regex links, no date cap. Registration's
rules are added by PR 4.

**Review:** `FieldRenderer.swift` (the CRM↔app contract), `FieldValidator.swift` (untrusted
regexes), `DynamicFormModel.swift` (touched state, section gating, ID-type → ID-number),
`FormEndpoints.swift` (HTTP 200 is not success). 83 tests.

## PR 4 · `JackpotRegistration` — the complete feature

The registration flow as a module. The app's entire integration surface is one view controller
and one dependencies struct.

| File | Holds |
|---|---|
| `RegistrationFeature.swift` | `RegistrationDependencies` (`.mock(localizer:)` for demos; applies the ID-type link and the 18-year date cap), `RegistrationView` — the pages inside `JackpotPanel`, the login row and navigation in its footer, with `onClose` and `onLogin` |
| `RegistrationPanelController.swift` | a `UIHostingController` sized for the legacy popup container |
| `RegistrationService.swift` | the protocol, `MockRegistrationService`, `RemoteRegistrationService`, `RegistrationError` |

The feature reads **nothing** from the app. The one thing it needs from the legacy world — the
current `getTranslation` — arrives as a `FormLocalizing` the app constructs in PR 5.

**Review:** run the previews. The full flow, both pages, success and the duplicate-mobile
failure path, with no app and no backend. 11 tests.

## PR 5 · Replace the current flow

The only PR that touches the app. Three parts:

**1. Wrap the existing translation function** (~8 lines):

```swift
// TRANSITIONAL. Deleted by the localisation follow-up.
let legacyLocalizer = ClosureLocalizer { key in
    let value = getTranslation(Key: key)
    return value == key ? nil : value      // getTranslation returns the key on a miss
}
```

That last line matters: the engine uses `nil` to mean "unresolved" so it can fall back to
humanised copy. Without it a missing string renders as `username`.

**2. Present the package where the old popup was** (~10 lines):

```swift
let controller = RegistrationPanelController(
    dependencies: RegistrationDependencies(
        forms: .live(baseURL: configURL, localizer: legacyLocalizer),
        service: MockRegistrationService()        // → RemoteRegistrationService once the endpoint is confirmed
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

**3. Delete the old flow:** `registrationPopup`, `flowOneViewController`, `flowTwoViewController`,
their nibs, their `GlobalData` handles.

Net negative. The diff is small enough to review in one sitting and revert in one commit.

---

## Localisation follow-up — sequenced last

Everything from ADR-0001 that touches copy. After PR 5, deliberately: it changes the mechanism
behind every string in the app and has no dependency on registration shipping.

Adds `JackpotAppData` (section-wise bootstrap ingestion — the `ConfigData` decode fix — and
`RemoteTranslationsRepository`) and the rest of `JackpotLocalization` (`TranslationsStore`),
then: `getTranslation` becomes a shim (app-wide performance fix, zero call-site changes,
deprecation warnings as the burn-down list); the registration `ClosureLocalizer` is replaced
with `TranslationsLocalizer` and error codes start resolving to localised copy; call sites burn
down by count. 29 tests.

---

## Sequencing notes

**What's demoable when.** After PR 1, components. After PR 3, the real schema rendering. After
PR 4, the entire feature on a device from the sandbox. The app hasn't changed yet.

**Useful stopping point.** After PR 4 the app is untouched and nothing is lost. After PR 5 the
old flow is gone and there is no going back without a revert — which is fine, because PR 5 is
one commit.

**What must not be dropped.** The delete in PR 5. Landing the swap without the delete leaves two
sign-up flows in the tree.
