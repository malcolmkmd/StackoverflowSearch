# JackpotKit Audit

| | |
|---|---|
| **Date** | 2026-09-07 |
| **Commit** | `bdcc93e` (main) |
| **Scope** | `JackpotKit/` only. Every source file, every test, `docs/`, and `scripts/build-playbook.py`. |
| **Toolchain** | Xcode 27.0, Swift 6.4, iPhone 17 Pro simulator |
| **Suite** | `xcodebuild -scheme JackpotKit-Package test`: **187 tests, 0 failures**, 0 warnings from package sources |

> **Outcome (same day).** Findings 1–5, 7, 9 and 10 were applied in full and finding 6 in part
> (registration's rules moved out of the engine; the `jpc-reg` key conventions stay where they
> are, as the CRM contract). Finding 8 was decided in favour of keeping the iOS 15 floor. The package now has six modules (`JackpotForms` merged from five),
> `DynamicFormView` has one initialiser, field data lives on `init`, registration's rules live in
> `JackpotRegistration`, an undecodable submit body is rejected, and the playbook is generated
> from the files verbatim. The findings below describe the code as it was at `bdcc93e`.

Judged against four goals: ship the registration form, leave a foundation other components can build on, expose a composable design-system API, and keep the Swift simple. Plus one constraint: the build playbook should cover the types registration needs and nothing else.

---

## Verdict

**Registration works end to end and is well tested.** The schema decodes, the two-section wizard pages, validation is touched-state aware, the ID-type dropdown rewrites the ID-number rule, the password checklist ticks, the submit envelope is parsed with the HTTP-200-but-failed case handled, and errors keep the server's wording. The remaining gap is integration into the target app (PR 5), which lives outside this repo.

**The foundation is sound.** Theme tokens through the environment, key-path styling modifiers, `ButtonStyle`/`ToggleStyle`/`ProgressViewStyle` conformances, `JackpotFieldKind`, the `FormRepository`/`FormLocalizing` seams, and `FieldType.unknown` resilience are the right shapes and worth keeping.

**Three things work against "simple" and against the playbook constraint:**

1. About 450 lines of source (18 files) are components and field types no bundled schema uses. The playbook hides them with 321 lines of regex rewrites, so the playbook documents code that is not in the repo.
2. Ten modules for one feature. Call sites import four or five of them, the public surface is ~540 `public` declarations, and the module boundary is the stated reason for a 169-line hand-built duplicate of `registration.json`.
3. Machinery the target may not need: an iOS 15 floor with untested availability branches, and a ~60-line environment-injection dance so `DynamicFormView` can take two arguments instead of three.

None of these are bugs. One correctness issue was found (finding 7). Everything else is scope and shape.

---

## What to keep

These are the foundation. Do not lose them while trimming.

- **Token model.** [JackpotTheme.swift](../JackpotKit/Sources/JackpotUI/Theme/JackpotTheme.swift): `JackpotTheme` = `colors` + `sizes` + `typography`, `with { }` for one-off variants, `Palette` holding each hex exactly once, adaptive colours resolved through `UIColor` traits so `preferredColorScheme` overrides work. The contrast tests in [JackpotThemeTests.swift](../JackpotKit/Tests/JackpotUITests/JackpotThemeTests.swift) pin both the locked hexes and WCAG ratios.
- **Key-path styling.** `.jackpotTextStyle(\.label, color: \.textSecondary)`, `.jackpotBackground(\.fieldBackground, in: shape)`, `padding(.sm)`, `VStack(spacing: .sm)`. Readable at the call site, theme-aware, no magic numbers.
- **Style conformances with statics.** `.buttonStyle(.jackpot)`, `.toggleStyle(.jackpotCheckbox)`, `.progressViewStyle(.jackpotBar)`. Idiomatic SwiftUI, previews alone, and the "a `ButtonStyle` is not a `View`" body-struct trick is correct.
- **`JackpotFieldKind`.** Keyboard, content type, capitalisation and autocorrection as one value with named presets.
- **Domain seams.** `FormRepository`, `FormLocalizing`, `RegexResolving`, `PasswordPolicyProviding`. Stub and live repositories are driven through the same protocol in tests.
- **Resilience decisions.** `FieldType.unknown` + `unsupportedFields`, malformed server regex treated as no constraint, `FormName` as a `RawRepresentable` struct rather than an enum, explicit `regexDependencies` instead of positional inference.
- **Error path.** `APIError` → `FormLoadError` → `RegistrationError` keeps the server's message and the localised error-code copy all the way to the screen.
- **Test style.** Behaviour-named, schema-driven, reads as a spec.

---

## Findings

Ranked by how much they cost against the stated goals.

### 1. The playbook documents code that does not exist · High

[build-playbook.py](../scripts/build-playbook.py) reads every source file from disk, then runs it through 15 `registration_*` transform functions (321 lines) that delete cases, structs, properties and comments before emitting. Its own docstring says "the document cannot drift from the code it documents". The transforms are drift by construction: a reader who follows the playbook produces a `FieldType` with four cases, a `FormField` without `radioOptions`, a `JackpotButtonStyle` without `.tertiary`, and so on. None of those files exist in the repo. The `FORBIDDEN` list at the end guards the *document* against mentioning the trimmed names instead of guarding the *code*.

Other drift the generator does not catch:

- Four hand-typed `Package.swift` snippets that do not match the real manifest (the playbook's `JackpotLocalization` target has no dependencies; the real one depends on `JackpotNetworking` and `JackpotAppData`).
- Notes referencing `JackpotFieldConfiguration`, `jackpotFieldState`, `jackpotFieldError`, `applyRegexDependencies` and a "graphical picker". None exist.
- Test counts: the playbook says `JackpotUITests` has 13 tests and `JackpotLocalizationTests` 16; the suite has 18 and 22. "153 tests through PR 5" is 187 on disk.
- [LAUNCH-PERFORMANCE.md](LAUNCH-PERFORMANCE.md) describes `JackpotLaunchSkeleton` and `.shimmering()`, which are not in the package.

**Why it matters.** The playbook's one job is to be a trustworthy build order. Every transform is a place it lies.

**Recommendation.** Make the code registration-only (finding 2), delete every `registration_*` transform and the `FORBIDDEN` list, and emit files verbatim. Generate the manifest snippet from the real `Package.swift` or show it once. Derive test counts from the last run or drop them. The generator shrinks by roughly a quarter and the claim in its docstring becomes true.

### 2. Speculative components nobody calls · High

Confirmed by grep: zero production references outside their own definition files.

| Whole files (258 lines) | Partial (about 190 lines) |
|---|---|
| `JackpotRadioGroup.swift` | `JackpotCardButtonStyle` + `.jackpotCard` (39 lines in `JackpotButtonStyle.swift`) |
| `JackpotTextArea.swift` | `JackpotButtonStyle.Prominence.tertiary` |
| `JackpotLockedOverlay.swift` | `JackpotToggleStyle.Appearance.switch` + `.jackpotSwitch` |
| `RadioGroupFieldView.swift` | `JackpotDivider` |
| `TextAreaFieldView.swift` | `jackpotIsSelected` / `.jackpotSelected()` environment key |
| `WelcomeOfferFieldView.swift` | `JackpotFieldKind.oneTimeCode` |
| | `JackpotSizes.textAreaMinHeight`, `.cardMinHeight` |
| | `FieldType` cases `button`, `radio`, `radioGroup`, `divider`, `textArea`, `recaptchaV2`, `recaptchaV3`, `toggle`, `welcomeOffer` and `isDecorative` |
| | `RadioOption`, `FormField.radioOptions`, `FieldRadioDTO`, the mapper branch |
| | `ToggleFieldView`, `RecaptchaPlaceholderView`, the `FieldRenderer` cases |
| | `FormPreview.notes`, `.contactMethod`, `.welcomeOffer` |
| | `FormField.name`, `FormField.textStyle` (decoded, stored, never read) |

The commit that scoped the preview schema to registration (`938a921`) says it in its own message: "keep unused CRM Swift in the package". That is the decision to revisit.

**Why it matters.** "Foundation for other components" is served by the token model, the style protocols and the `FieldRenderer` switch, not by shipping a radio group nobody has designed yet. Each speculative type is public API you now have to keep or break, and it is what forces finding 1. `FieldType.unknown` already guarantees that a new server type degrades gracefully; that is the extension point.

**Recommendation.** Delete the table above. `FieldType` becomes `input`, `dropdown`, `checkbox`, `unknown(String)`. Keep the pattern visible: a doc comment on `FieldRenderer` saying "new server type → new case here → new `XxxFieldView` binding a `JackpotUI` component". When the first non-registration form arrives, its components get designed against a real schema.

### 3. Ten modules for one feature · Medium-High

```
JackpotUI            JackpotNetworking
                     └─ JackpotAppData
                        └─ JackpotLocalization
JackpotFormsDomain
└─ JackpotFormsData
   └─ JackpotFormsRemote ─┐
└─ JackpotFormsUI ────────┼─ JackpotForms ─ JackpotRegistration
```

Costs that are visible in the code today:

- **Call sites import four or five modules.** [RegistrationSandbox.swift](../StackOverflowSearch/App/RegistrationSandbox.swift) imports `JackpotFormsData`, `JackpotFormsDomain`, `JackpotFormsUI`, `JackpotUI`. [RegistrationFeature.swift](../JackpotKit/Sources/JackpotRegistration/RegistrationFeature.swift) imports four. The app in PR 5 needs `JackpotFormsDomain` just for `ClosureLocalizer`.
- **A 169-line duplicate of the schema.** [PreviewFixtures.swift](../JackpotKit/Sources/JackpotFormsUI/Demo/PreviewFixtures.swift) hand-builds `FormPreview.registration` "because `JackpotFormsUI` does not depend on `JackpotFormsData`, so it has no decoder". It mirrors `registration.json` field by field and will drift from it.
- **A composition module that exists only because of the split.** [JackpotForms.swift](../JackpotKit/Sources/JackpotForms/JackpotForms.swift) holds `.mock()`, `.live()` and `TranslationsLocalizer`. They cannot live beside `FormDependencies` because `JackpotFormsUI` cannot see `StubFormRepository`.
- **Public surface.** `JackpotFormsDomain` 133 `public`, `JackpotFormsUI` 83, `JackpotFormsData` 14, `JackpotFormsRemote` 11. DTOs, the mapper, endpoints and the submit envelope are all public because another module has to reach them.
- **Registration transitively depends on the app-data cache.** `JackpotForms` → `JackpotLocalization` → `JackpotAppData` (for `RemoteTranslationsRepository` alone). 418 lines the playbook correctly calls "the follow-up" ship on the registration path.

**Recommendation.** Four modules.

| Module | Holds | Change |
|---|---|---|
| `JackpotUI` | design system | unchanged |
| `JackpotNetworking` | transport | unchanged |
| `JackpotForms` | Domain, Data, UI, Remote, composition as **folders** | merge five modules; DTOs, mapper, endpoints, parser, `FormSubmitBody` become `internal`; `.mock()` moves beside `FormDependencies`; `PreviewFixtures.swift` is deleted and previews decode the bundled JSON through the real mapper |
| `JackpotRegistration` | the feature | imports `JackpotForms` + `JackpotUI` |

`JackpotAppData` keeps the loader and cache and takes `RemoteTranslationsRepository` from `JackpotLocalization`, so `JackpotLocalization` depends on nothing but Foundation and the registration path no longer reaches app-data. What you give up is compile-time proof that UI code cannot touch a DTO. Folder layout plus `internal` and review is the trade a small team should make.

### 4. `DynamicFormView`'s environment-injection dance · Medium

[DynamicFormView.swift](../JackpotKit/Sources/JackpotFormsUI/DynamicFormView.swift) has two initialisers. The two-argument one cannot read `@Environment` in `init`, so it constructs the model with `UnavailableFormRepository()` and `isConfigured: false`, then `.task` calls `configureIfNeeded(with:)` guarded by `@State hasLoaded`. Supporting that: `FormDependenciesKey` with an asserting default, the `formDependencies` environment value and modifier, `UnavailableFormRepository` with `assertsWhenCalled`, and `DynamicFormModel.isConfigured` + `configureIfNeeded`. Roughly 60 lines so the call site can omit one argument.

The three-argument initialiser already exists and is what `RegistrationView` could use directly, since `RegistrationDependencies.forms` is in hand.

**Recommendation.** Keep `init(formName:dependencies:onSubmit:)` only. Delete the environment key, the modifier, `UnavailableFormRepository`, `isConfigured`, `configureIfNeeded` and `hasLoaded`; make `load()` a no-op when a schema is already loaded so re-appearance cannot wipe a half-filled form. Previews use `StubFormRepository(forms:delay: 0)`.

### 5. Field configuration flows through three channels · Medium (API design)

The same component is configured three ways:

- **Init parameters:** `JackpotTextField("Mobile", text: $mobile)`
- **`Self`-returning methods:** `.onEditingEnded { }`, `.onFocusChange { }`, `.onRetry { }`
- **Environment keys (11 in [JackpotEnvironment.swift](../JackpotKit/Sources/JackpotUI/Theme/JackpotEnvironment.swift)):** `jackpotFieldPrefix`, `jackpotFieldSuffix`, `jackpotSecureEntry`, `jackpotFieldLabel`, `jackpotFieldIdentity`, `jackpotSubmitLabel`, …

Environment values cascade. `.jackpotFieldPrefix("+27")` on a container prefixes every field below it. `jackpotSecureEntry` exists only because `.jackpotField(.newPassword)` is a modifier and the `SecureField`/`TextField` choice happens inside `body`. `jackpotFieldLabel` is set by `JackpotLabeledField` and read by `JackpotDateField` alone: a hidden contract between two components.

**Recommendation.** One rule: data on `init`, callbacks as `Self`-methods, environment for things that genuinely cascade (theme, validation message on a row, loading state on a button, the shared focus binding).

```swift
JackpotTextField("Mobile Number", text: $mobile, kind: .phoneNumber, prefix: "+27")
JackpotTextField("Password", text: $password, kind: .newPassword)
JackpotDateField("Date of Birth", placeholder: "Enter Date Of Birth", selection: $dob, in: ...cap)
```

That removes `jackpotFieldPrefix`, `jackpotFieldSuffix`, `jackpotSecureEntry`, `jackpotFieldLabel` and `jackpotIsSelected`. `jackpotField(_:)` as a modifier goes; `kind` is applied inside the field's body.

Two related smells in [JackpotFieldChrome.swift](../JackpotKit/Sources/JackpotUI/Fields/JackpotFieldChrome.swift):

- `JackpotLabeledField` is used with `label: nil` on Input, Dropdown and Checkbox now that labels float inside the control. It is really an error row. If `JackpotDateField` floats its label like the other two, this becomes a single `.jackpotError(_:)` modifier that draws the red ring and the caption, and the "above-field label on date, error shell elsewhere" explanation in the playbook disappears.
- The floating-label ZStack (top padding, `-16` offset, 0.15s animation) is duplicated in `JackpotTextField` and `JackpotDropdown`. `JackpotFloatingLabel` sets `.font` and `.environment(\.font)` to the same value and then also `scaleEffect(0.75)`, so the raised label shrinks twice. One `JackpotFloatingField` wrapper should own that layout.

### 6. Registration policy inside generic layers · Medium

`FormDependencies` is documented as "everything `DynamicFormView` needs", yet three of its seven members are registration rules with registration defaults:

- `regexDependencies = ["idNumberType": "idNumber"]`
- `maximumDateOfBirth` = 18 years ago
- `appliesOptionRegexToDependentField = true`, a Bool that exists so one test can turn the feature off

Elsewhere: `FormLocalizing.validationMessage(for:)` composes `jpc-reg-{id}-{key}` and `humanisedKey` strips `jpc-reg-` ([FormLocalizing.swift](../JackpotKit/Sources/JackpotFormsDomain/FormLocalizing.swift)); `Translations.message(forErrorCode:)` prefixes `jpc-reg-error.`; `RegexCatalog.jpcDefaults` is the validator's default; `InputFieldView.kind` maps the identifier `"username"` to a phone keyboard.

**Recommendation.** Defaults in the engine are empty: `regexDependencies: [:]`, `maximumDate: nil`, drop the Bool (empty links = feature off). `RegistrationDependencies` supplies the registration values. Gather the `jpc-reg-` conventions and the identifier→kind map into one clearly named place so the next form knows where to look, and the engine reads as generic.

### 7. An undecodable 200 body is treated as a successful submit · Medium (correctness)

[FormEndpoints.swift](../JackpotKit/Sources/JackpotFormsRemote/FormEndpoints.swift), `FormSubmitParser.parse`: if the body is not empty and does not decode as `FormSubmitEnvelope`, it returns `.accepted(FormSubmitResult())`. A WAF or gateway page served with status 200 registers the user in the app's eyes with no account id. An empty body is also accepted, which `testEmptyBodyIsAnAcceptedSubmit` codifies.

**Recommendation.** Undecodable → `.rejected(nil)` (surfaces as "We couldn't submit the form"). Confirm with the backend whether an empty 200 can ever mean success; if not, reject that too.

### 8. The iOS 15 floor · Decision needed

`Package.swift` declares `.iOS(.v15)`. The workbench app targets iOS 26.4, so none of the iOS 15 paths are exercised. Cost of the floor:

- `DynamicFormModel` and `TranslationsStore` are `ObservableObject` + `@Published` + Combine, with comments saying "because this package targets iOS 15".
- Three `#available(iOS 16.0, *)` branches (`presentationDetents`, `scrollContentBackground`, `sizingOptions`).
- `NavigationView`, `foregroundColor`, and the single-parameter `onChange(of:)` in four places, all deprecated.

If the target app's deployment target is iOS 17 or later: raise the floor, make the model `@Observable`, drop Combine, delete the branches. If it must stay at 15, keep the floor but bump `swift-tools-version` from 5.7 to at least 5.10, since `@Entry` needs that compiler and the manifest currently claims compatibility it does not have.

Either way, consider adding `swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]` (or Swift 6 mode) to the package. The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package builds with none, so the `Sendable` annotations are unchecked.

### 9. `kitchenSink.json` duplicates `registration.json` · Low

Normalised JSON diff: all twelve fields are identical. Only `formId`, `formCodeName`, `formTitle` and `formSubTitle` differ. The sandbox therefore offers the same form twice ("Sign Up" and "Registration fields"), the Canvas has a "Registration fields — from JSON" preview of the same form, and `FormName.kitchenSink`, `FormName.bundled` and `testKitchenSinkIsTheRegistrationFieldCatalog` exist to support it.

**Recommendation.** Delete the file, the name, the test and the second sandbox sample. `FormName.bundled` becomes `[.registration]`.

### 10. Smaller items · Low

- `RegistrationError.init(_ apiError: APIError)` has no production caller (the repository already maps to `FormLoadError`). It is why `JackpotRegistration` imports `JackpotNetworking`, and it carries the `// TODO: confirm code` for 1042. Delete it and the import.
- `RegistrationResult` mirrors `FormSubmitResult` member for member. Defensible as insulation; optional to collapse.
- No production caller for `FormRepository.form(id:)`, `FormSubmission.metadata`, `HTTPMethod.PUT/PATCH/DELETE`, `RequestBody.form`, or an `APIEndpoint.headers` override. Fine for a transport layer; worth knowing before adding more.
- [JackpotStyling.swift](../JackpotKit/Sources/JackpotUI/Theme/JackpotStyling.swift) overloads SwiftUI's `frame(width:height:)`, `shadow(radius:)` and the deprecated `cornerRadius(_:)` with `JackpotSpacing`. Sizes are rarely spacing values. Keep `padding` and the stack `spacing:` overloads; drop the other three.
- `JackpotPreviewPanel` is `public` inside `#if DEBUG`, so it vanishes from release builds of any importer.
- `DynamicFormModel.load()` is fire-and-forget, so tests poll with `Task.sleep`. An `async` `load()` lets tests `await` it and removes the timing dependence.
- `docs/BUILD-PLAYBOOK.pdf` (648 KB) is committed. Generate on demand or attach to releases; a regenerated binary on every playbook change will dominate repo size.
- [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) mentions `saveDraft`/`loadDraft` as reference-app stubs and describes field-order fallback for regex links; the code has no positional fallback (good), so that sentence is stale.

---

## Registration type inventory

What the playbook should list, module by module, after findings 2, 3 and 9. Everything in the current repo that is not on this list is a candidate for deletion.

**`JackpotUI`**

| Type | Role in registration |
|---|---|
| `JackpotTheme`, `JackpotColors`, `JackpotSizes`, `JackpotTypography`, `JackpotSpacing` | tokens |
| `.jackpotTheme()`, `.jackpotTextStyle()`, `.jackpotFont()`, `.jackpotForegroundStyle()`, `.jackpotBackground()`, `padding(JackpotSpacing)`, stack `spacing:` | styling |
| `JackpotFieldKind` (`text`, `givenName`, `familyName`, `email`, `phoneNumber`, `number`, `newPassword`) | keyboard / autofill |
| `JackpotTextField` | username, password, names, email, referral code, ID number |
| `JackpotDropdown`, `JackpotOption` | ID number type, source of funds |
| `JackpotDateField` | date of birth |
| `JackpotToggleStyle` (`.jackpotCheckbox`) | promotions opt-in, terms |
| `JackpotButtonStyle` (`.primary`, `.secondary`) | Next, Sign Up, Previous, Retry, Done |
| `JackpotBarProgressViewStyle` | section progress, password checklist |
| `JackpotChecklist`, `JackpotChecklistItem` | password rules |
| `JackpotErrorView` | load failure |
| `JackpotFieldBackground`, floating label, error row | field chrome |
| `jackpotTheme`, `jackpotValidationMessage`, `jackpotIsLoading`, `jackpotFocusedField`, `jackpotFieldIdentity`, `jackpotSubmitLabel` | environment |
| `JackpotPreviewPanel` | DEBUG previews |

**`JackpotForms`** (one module; folders Domain / Data / UI / Remote)

| Type | Role |
|---|---|
| `FormSchema`, `FormSection`, `FormRow`, `FormField`, `FieldType` (`input`, `dropdown`, `checkbox`, `unknown`), `InputType`, `DropdownOption` | schema |
| `FormValue`, `FormSubmission`, `FormSubmitResult`, `FormComplianceResult` | values in and out |
| `FormName` | `.registration` |
| `FieldValidator`, `ValidationResult`, `RegexResolving`, `RegexCatalog` | validation |
| `PasswordPolicyProviding`, `PasswordPolicy`, `PasswordRule` | checklist rules |
| `FormLocalizing`, `ComposedKeyLocalizer`, `ClosureLocalizer`, `TranslationsLocalizer` | copy |
| `FormRepository`, `FormLoadError`, `StubFormRepository`, `RemoteFormRepository` | fetch and submit |
| `FormDependencies` (+ `.mock()`, `.live()`) | composition |
| `DynamicFormModel`, `DynamicFormView`, `FieldRenderer`, `InputFieldView`, `DropdownFieldView`, `DateFieldView`, `CheckboxFieldView` | engine and renderer |
| `FormSandboxView` | on-device harness |
| internal: `FormDTO` family, `FormMapper`, `FormRequest`, `FormSubmitRequest`, `FormSubmitBody`, `FormSubmitParser`, `FormErrorMapper`, `APIEnvironment.cron` | wire |

**`JackpotNetworking`**: `APIEndpoint`, `APIEnvironment`, `HTTPMethod`, `RequestBody`, `HTTPClient`, `URLSessionHTTPClient`, `ApiClient`, `RemoteApiClient`, `APIError`, `APIProblem`, `RequestInterceptor`, `BearerTokenInterceptor`. (`HTTPValidators` and `requestConditional` belong to app-data.)

**`JackpotLocalization`**: `Translations`.

**`JackpotRegistration`**: `RegistrationDependencies`, `RegistrationView`, `RegistrationPanelController`, `RegistrationService`, `MockRegistrationService`, `RemoteRegistrationService`, `RegistrationResult`, `RegistrationError`.

---

## Suggested order

Each step leaves the suite green and is one reviewable PR.

1. **Trim to registration** (findings 2, 9, 10). Delete the speculative components, `kitchenSink.json`, the dead `RegistrationError` initialiser and the unread `FormField` members. Regenerate the playbook with every transform removed (finding 1). This is the step that makes the playbook true.
2. **Merge the forms modules** (finding 3). Folders keep the layering; `internal` hides the wire types; `PreviewFixtures.swift` goes. Move `RemoteTranslationsRepository` to `JackpotAppData`.
3. **One `DynamicFormView` initialiser** (finding 4). Delete the environment key and the placeholder repository.
4. **Field API pass** (finding 5). Data on `init`, five environment keys removed, one floating-field wrapper, `JackpotLabeledField` becomes an error modifier once the date field floats its label.
5. **Move registration policy out of the engine** (finding 6) and **reject undecodable submit bodies** (finding 7).
6. **Decide the iOS floor** (finding 8), then either adopt `@Observable` or bump the tools version and add strict concurrency to the package.
