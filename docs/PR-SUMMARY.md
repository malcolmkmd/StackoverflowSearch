# Step 4 · Connect the forms to the network and replace the registration flow

Adds `JackpotForms/Remote` — the live repository behind the same protocol the stub implements —
then swaps the nib-backed sign-up popup for `JackpotRegistration` and deletes the old flow. The
only step in the sequence that touches the app target.

Part of a sequence — see [PR-STRATEGY.md](PR-STRATEGY.md). Steps 1 to 3 landed `JackpotUI`,
`JackpotForms` on the bundled schema, `JackpotRegistration` and `JackpotNetworking` inside
`JackpotKit`, called by nobody. This step calls them.

| | |
|---|---|
| **Depends on** | step 3 (`JackpotNetworking`) |
| **Followed by** | step 5, translations ([ADR-0001](adr/0001-app-data-decoding-and-configuration-decomposition.md)) |
| **Net** | −1,200 lines |

---

## What changes in the package

`Remote/` joins `JackpotForms`: `FormEndpoints` (the cron paths, the submit request and the
envelope) and `RemoteFormRepository` (the fetch; the submit, which treats HTTP 200 with
`isSuccessful: false` as a failure and a body that is not the envelope as a rejection; the
boundary that keeps the server's wording; and `.live(baseURL:translate:)`). `JackpotForms`
and its tests gain `JackpotNetworking` in the manifest.

## What changes in the app

**Added** (~25 lines, one file):

```swift
// Sources/Features/Registration/RegistrationPresenter.swift
func presentRegistration() {
    let controller = RegistrationPanelController(
        dependencies: RegistrationDependencies(
            forms: .live(baseURL: configBaseURL, translate: { getTranslation(Key: $0) })
        ),
        onClose: { [weak self] in self?.popupContainer.dismiss() },
        onLogin: { [weak self] in self?.popupContainer.dismiss(); self?.presentLogin() }
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

## Why `translate` is a bare closure

`getTranslation` returns the **key itself** when it has no translation, and so does the form
engine's `translate`: a key in, its text out, the key on a miss. The two contracts match, so
the app passes `{ getTranslation(Key: $0) }` and nothing adapts anything. A missing string
renders as its key, visible in QA. `testUntranslatedKeysRenderAsThemselves` in
`JackpotFormsTests` pins that contract.

The presenter is the *only* new code that references the legacy world, and it stays as it is
at step 5, when `getTranslation` becomes a shim over the store.

## What's provisional

The submit goes live with the fetch: `.live` posts through `RemoteFormRepository.submitForm`,
whose envelope handling is tested against captured responses but not yet exercised end to end —
see [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md). `.mock()` keeps the faked submit for a build
without the backend.

---

## Testing

The package suites are green — 171 tests:

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`JackpotUITests` 20 · `JackpotFormsTests` 73 · `JackpotNetworkingTests` 34 ·
`JackpotLocalizationTests` 18 · `JackpotRegistrationTests` 3 · `JackpotAppDataTests` 23

Manual, on a device: open sign-up from the header and from the bottom bar; complete both pages;
confirm section gating, the ID-type → ID-number rule change, the password checklist, and that
the duplicate-mobile failure (`0000000000` against the mock) surfaces under the fields
without clearing the form. Confirm every label reads as it did — that's `getTranslation`
plugged straight in.

## Review guide

1. The new file. The presenter references nothing but `JackpotRegistration` and, in one
   closure, `getTranslation`.
2. The deletions. Grep for `registrationPopup`, `flowOne`, `flowTwo` — zero hits expected.
3. Nothing else in the app diff. If there is, it belongs in another step.
