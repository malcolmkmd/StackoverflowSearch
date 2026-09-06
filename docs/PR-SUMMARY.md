# PR 5 · Replace the registration flow with `JackpotRegistration`

Swaps the nib-backed sign-up popup for the `JackpotRegistration` module and deletes the old
flow. The only PR in the sequence that touches the app target.

Part of a sequence — see [PR-STRATEGY.md](PR-STRATEGY.md). PRs 1–4 landed `JackpotUI`,
`JackpotForms`, `JackpotNetworking` and `JackpotRegistration` inside `JackpotKit`, called by
nobody. This PR calls them.

| | |
|---|---|
| **Depends on** | PR 4 (`JackpotRegistration`) |
| **Followed by** | localisation follow-up ([ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md)) |
| **Net** | −1,200 lines |

---

## What changes in the app

**Added** (~20 lines, one file):

```swift
// Sources/Features/Registration/RegistrationPresenter.swift

// TRANSITIONAL. Deleted by the localisation follow-up, when the app adopts
// JackpotLocalization and this becomes a TranslationsLocalizer.
private let legacyLocalizer = ClosureLocalizer { key in
    let value = getTranslation(Key: key)
    return value == key ? nil : value      // getTranslation returns the key on a miss
}

func presentRegistration() {
    let controller = RegistrationPanelController(
        dependencies: RegistrationDependencies(
            forms: .live(baseURL: configBaseURL, localizer: legacyLocalizer),
            service: MockRegistrationService()   // → RemoteRegistrationService once the endpoint is confirmed
        )
    ) { [weak self] result in
        self?.routeAfterRegistration(result)
    }
    addChild(controller)
    popupContainer.show(controller.view)
    controller.didMove(toParent: self)
}
```

**Removed:**

- `RegistrationViewController` + `RegistrationViewController.xib`
- `FlowOneViewController`, `FlowTwoViewController` + nibs
- `GlobalData.registrationPopup`, `.flowOneViewController`, `.flowTwoViewController`
- The `NavigationHandler` branches that reached them

**Unchanged:** everything else. No other screen, no other `GlobalData` member, no localisation.

---

## Why the localizer wrapper looks like that

`getTranslation` returns the **key itself** when it has no translation. The form engine's
`FormLocalizing` uses `nil` to mean "unresolved", so it can fall back to humanised copy
(`"dateOfBirth"` → `"Date Of Birth"`). Without mapping key-on-miss back to `nil`, a missing
string renders as the raw key. `testClosureLocalizerMapsKeyOnMissToNil` in `JackpotRegistration`
covers exactly this.

The wrapper is the *only* new code that references the legacy world, and it's deleted by the
follow-up.

## What's provisional

`MockRegistrationService` is wired rather than `RemoteRegistrationService` because the
registration POST's path, body and response shape are **not confirmed** — see
[OPEN-QUESTIONS.md](OPEN-QUESTIONS.md). `RemoteRegistrationService` exists, compiles and is one
line to swap in; its
`RegisterRequest` is a best guess to be corrected with the backend. Shipping this PR with the
mock service means the *screen* is live and validated end to end while the *submit* still
needs the contract — which is the honest state of things.

---

## Testing

The package suites are unchanged and green — 152 tests:

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`JackpotUITests` 13 · `JackpotFormsTests` 80 · `JackpotNetworkingTests` 34 ·
`JackpotLocalizationTests` 16 · `JackpotRegistrationTests` 9

Manual, on a device: open sign-up from the header and from the bottom bar; complete both pages;
confirm section gating, the ID-type → ID-number rule change, the password checklist, and that
the duplicate-mobile failure (`0000000000` against the mock) surfaces above the Sign Up button
without clearing the form. Confirm every label reads as it did — that's the `getTranslation`
wrapper doing its job.

## Review guide

1. The one new file. It should be ~20 lines and reference nothing but the two modules and
   `getTranslation`.
2. The deletions. Grep for `registrationPopup`, `flowOne`, `flowTwo` — zero hits expected.
3. Nothing else in the diff. If there is, it belongs in another PR.
