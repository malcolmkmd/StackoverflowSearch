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

`Remote/` joins `JackpotForms`: `FormEndpoints` (the cron URLs, the submit body, and
`FormSubmitParser`, which treats HTTP 200 with `isSuccessful: false` as a failure and a body
that is not the envelope as a rejection), `FormErrorMapper` (the boundary that keeps the
server's wording), `RemoteFormRepository`, and `.live(baseURL:localizer:)`. `JackpotForms`
and its tests gain `JackpotNetworking` in the manifest.

## What changes in the app

**Added** (~35 lines, two files):

```swift
// Sources/Features/Registration/LegacyTranslationLocalizer.swift
// Deleted at step 5, when the app adopts JackpotLocalization and Translations.formLocalizer takes over.
struct LegacyTranslationLocalizer: FormLocalizing {
    func string(forKey key: String) -> String? {
        let value = getTranslation(Key: key)
        return value == key ? nil : value      // getTranslation returns the key on a miss
    }
}
```

```swift
// Sources/Features/Registration/RegistrationPresenter.swift
func presentRegistration() {
    let controller = RegistrationPanelController(
        dependencies: RegistrationDependencies(
            forms: .live(baseURL: configBaseURL, localizer: LegacyTranslationLocalizer())
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

## Why `LegacyTranslationLocalizer` looks like that

`getTranslation` returns the **key itself** when it has no translation. The form engine's
`FormLocalizing` uses `nil` to mean "unresolved", so it can fall back to humanised copy
(`"dateOfBirth"` → `"Date Of Birth"`). Without mapping key-on-miss back to `nil`, a missing
string renders as the raw key. `testKeyOnMissMappedToNilFallsBackToHumanisedCopy` in
`JackpotRegistrationTests` pins that contract.

It is the *only* new code that references the legacy world, and step 5 deletes the file.

## What's provisional

The submit goes live with the fetch: `.live` posts through `RemoteFormRepository.submitForm`,
whose envelope handling is tested against captured responses but not yet exercised end to end —
see [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md). `.mock()` keeps the faked submit for a build
without the backend.

---

## Testing

The package suites are green — 193 tests:

```bash
cd JackpotKit
xcodebuild -scheme JackpotKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`JackpotUITests` 20 · `JackpotFormsTests` 79 · `JackpotNetworkingTests` 34 ·
`JackpotLocalizationTests` 22 · `JackpotRegistrationTests` 15 · `JackpotAppDataTests` 23

Manual, on a device: open sign-up from the header and from the bottom bar; complete both pages;
confirm section gating, the ID-type → ID-number rule change, the password checklist, and that
the duplicate-mobile failure (`0000000000` against the mock) surfaces under the fields
without clearing the form. Confirm every label reads as it did — that's
`LegacyTranslationLocalizer` doing its job.

## Review guide

1. The two new files. `LegacyTranslationLocalizer.swift` is the only one that references
   `getTranslation`; the presenter references nothing but `JackpotRegistration`.
2. The deletions. Grep for `registrationPopup`, `flowOne`, `flowTwo` — zero hits expected.
3. Nothing else in the app diff. If there is, it belongs in another step.
