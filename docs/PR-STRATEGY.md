# Delivery Plan — PR Sequence

Five PRs. The feature is built **entirely in packages**, demoable at every step, and the app
changes once — in the last PR, which swaps the current flow for the package and deletes the old
one. No feature flags; the app has none and this plan doesn't introduce any.

**Principles**

- **UI first, to show progress.** PR 1 is visible components. PR 2 renders the real captured
  schema. PR 4 is the complete registration feature running on a device from the sandbox.
- **Mock before live.** The forms package ships with a `FormRepository` protocol and a
  bundled-JSON implementation. The live one arrives with networking and replaces it at one line
  in composition.
- **The app is touched once.** Everything up to PR 5 is additive package code nobody calls.
  PR 5 is a swap plus a delete.
- **Localisation last.** The feature ships on the existing `getTranslation`, wrapped. The
  migration off it is a separate follow-up — see [ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md).

---

## Overview

| # | PR | Package | Demoable as | Size |
|---|---|---|---|---|
| 1 | **`JackpotUI`** — design system | JackpotUI | the gallery preview: every component, every state | ~900 |
| 2 | **`JackpotForms`** — engine on mock data | JackpotForms | the sandbox rendering the captured registration schema | ~3,000 |
| 3 | **`JackpotCore`** networking + live repository | JackpotCore, JackpotForms/Remote | `.live()` fetching the real schema | ~1,300 |
| 4 | **`JackpotRegistration`** — the feature, complete | JackpotRegistration | the full registration flow, mock service, on a device | ~350 |
| 5 | **Replace the current flow** | app | registration live in the app; old sign-up gone | −1,200 |
| — | Localisation follow-up | JackpotCore (AppData, Localization) + app | | ~1,000 |

```
JackpotUI ──► JackpotForms (mock) ──► JackpotCore + Remote (live) ──► JackpotRegistration ──► app swap
```

Every PR up to 4 is package-only. Reviewers can pull the branch and see the result without the
app building at all.

---

## PR 1 · `JackpotUI` — the design system

Components only. No data, no networking, no notion of a form. Everything is driven by
`Binding`s and plain values, so any feature can use it and every component previews alone.

| Component | Replaces |
|---|---|
| `JackpotTheme` · `.jackpotTheme()` | ad-hoc colours per nib |
| `JackpotButton` / `JackpotButtonStyle` | gold/blue buttons redrawn per screen |
| `JackpotTextField` — prefix cell, secure reveal, focus ring, invalid border | the `+27` mobile field, password field |
| `JackpotTextArea`, `JackpotDropdown`, `JackpotDateField` | |
| `JackpotCheckbox`, `JackpotToggleRow`, `JackpotRadioGroup` | Account Settings toggles, T&C checkbox |
| `JackpotChecklist` — progress bar + tickable rows | the Password Validity panel |
| `JackpotSelectableCard` + `.jackpotLocked(_:message:)` | welcome-offer tiles; provider and payment grids |
| `JackpotProgressBar`, `JackpotSkeleton`, `JackpotErrorView`, `JackpotLabeledField` | |

**Review:** open the gallery preview in `JackpotPreviewPanel.swift`.

## PR 2 · `JackpotForms` — the engine, on mock data

Four targets, **no networking dependency anywhere**.

| Target | Holds |
|---|---|
| `JackpotFormsDomain` | `FormSchema`, `FormField`, `FormName`, `FieldValidator`, `PasswordPolicy`, `FormLoadError`, `ClosureLocalizer`, the `FormRepository` / `FormLocalizing` protocols |
| `JackpotFormsData` | DTOs, `FormMapper`, `StubFormRepository` (serves the captured `registration.json`) |
| `JackpotFormsUI` | `DynamicFormModel`, `DynamicFormView`, one thin field view per type binding the model to a `JackpotUI` component |
| `JackpotForms` | composition — `.mock()`, `FormSandboxView.mocked()` |

**Review:** `FieldRenderer.swift` (the CRM↔app contract), `FieldValidator.swift` (untrusted
regexes), `DynamicFormModel.swift` (touched state, section gating, ID-type → ID-number). 55 tests.

## PR 3 · `JackpotCore` networking + the live repository

- **`JackpotCore` / `JackpotNetworking`** — `HTTPClient`, `APIEndpoint`, `APIError`,
  interceptors, `RemoteApiClient`. 200 / 400 / 401 / 500 with `unexpectedStatus` for anything
  infrastructure returns. 34 tests.
- **`JackpotFormsRemote`** — `RemoteFormRepository`, endpoints, `CRMEnvironment`,
  `FormErrorMapper`, and `.live()` in composition. The only forms target that touches networking.

`JackpotAppData` and `JackpotLocalization` are **not** here — they're the follow-up.

**Review:** `RemoteApiClientTests` and the `APIProblem.code`-is-an-`Int` fix.

## PR 4 · `JackpotRegistration` — the complete feature

The registration flow as a package. The app's entire integration surface is one view
controller and one dependencies struct.

| File | Holds |
|---|---|
| `RegistrationFeature.swift` | `RegistrationDependencies` (`.mock(localizer:)` for demos), `RegistrationView` |
| `RegistrationPanelController.swift` | a `UIHostingController` sized for the legacy popup container |
| `RegistrationService.swift` | the protocol, `MockRegistrationService`, `RemoteRegistrationService` (endpoint provisional — open question #5), `RegistrationError` |

The feature reads **nothing** from the app. The one thing it needs from the legacy world — the
current `getTranslation` — arrives as a `FormLocalizing` the app constructs in PR 5.

**Review:** run the previews. The full flow, both pages, success and the duplicate-mobile
failure path, with no app and no backend. 5 tests.

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
    )
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

Adds `JackpotAppData` (section-wise bootstrap ingestion — the `ConfigData` decode fix) and
`JackpotLocalization` (`Translations`, `TranslationsStore`), then: `getTranslation` becomes a
shim (app-wide performance fix, zero call-site changes, deprecation warnings as the burn-down
list); the registration `ClosureLocalizer` is replaced with `TranslationsLocalizer` and error
codes start resolving to localised copy; call sites burn down by count.

---

## Sequencing notes

**What's demoable when.** After PR 1, components. After PR 2, the real schema rendering. After
PR 4, the entire feature on a device from the sandbox. The app hasn't changed yet.

**Useful stopping point.** After PR 4 the app is untouched and nothing is lost. After PR 5 the
old flow is gone and there is no going back without a revert — which is fine, because PR 5 is
one commit.

**What must not be dropped.** The delete in PR 5. Landing the swap without the delete leaves two
sign-up flows in the tree.
