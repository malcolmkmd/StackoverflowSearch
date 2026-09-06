# Open Questions

Everything the registration work assumed rather than knew. Grouped by who can answer it.

Each entry says what we assumed, what breaks if the assumption is wrong, and — where it exists —
the switch to flip once you have the answer.

**Nothing currently blocks PR 5.** Q1, Q2 and Q4b are answered. `MockRegistrationService`
can stay for previews; `RemoteRegistrationService` maps the real submit envelope.

---

## A · Backend — the registration POST

### Q1 · What does the registration endpoint look like? ✅ answered

Path, request body shape, and response body shape.

- **Fetch** (by name *or* by id — same helper):
  `GET https://config.jpc.africa/cron/forms/jackpotcity/{wmsNavigationRegionCode}/{identifier}?api-version=2.0`
  The earlier `/crm/forms/...` ticket URL was wrong. Production `buildFormURL` is cron.
- **Submit:** `POST https://config.jpc.africa/cron/forms/submit` (no `api-version`).
  Body is `FormSubmission`: `form_id`, `form_name`, `submitted_at`, typed `fields`, optional `metadata`.
- **Response is not a boolean.** HTTP 200 with:
  `{ data, isSuccessful, error, metadata, httpStatusCode }`.
  The iOS `submitForm` that only looked for `"success"` would treat a failed create as OK.
- Drafts: `saveDraft` / `loadDraft` exist and are stubs (`true` / `nil`).
- **Assumed:** `submitted_at` encodes as ISO-8601 (the production encoder wasn't visible).

### Q2 · What happens after a successful registration? ✅ answered

- **Auto-login: yes.** `data.complianceResponse.accessToken` is a JWT (`_act-jwt-…`).
- **Account:** `data.accountId` (UUID), `data.message` `"User Created Successfully."`, `data.status` `"Success."`.
- **FICA is a second gate.** Success can still be partial:
  `partialRegistrationStatus: 1`, `complianceStatus` 512 vs `requiredComplianceStatus` 1,
  message `"Auto FICA Verification Failed, Manual Upload / Override…"`,
  locale key `jpc-partially-complete-profile`.
- **Failure is also HTTP 200:** `isSuccessful: false`, `error.code` / `displayCode` /
  `message`. Look up `jpc-reg-error.{code}` (e.g. 153008, 153006 invalid ID).
- **Where:** `FormSubmitResult`, `RemoteFormRepository.submitForm`, `RegistrationResult`.

### Q3 · Are the error `code` values a documented catalogue? ✅ answered (shape)

Codes are localisation keys. Registration errors live at `jpc-reg-error.{code}`
(153006, 153008, 132002, …). Bare numeric keys like `6000328` still exist for other
surfaces. Lookup tries the prefixed key first, then the bare number.

`code: 0` still hasn't shown up. Unknown codes fall back to `error.message`.

HTTP status is **not** the contract for this call — 200 + `isSuccessful: false` is a
failed registration.

---

## B · Backend / CRM — the form schema

### Q4 · Named regexes on dropdown options ✅ answered

> *"The user can select what they're entering, ID or passport — we should apply the correct regex."*

Confirmed: a **named** regex on a dropdown option overrides a *dependent* field's rule. Choosing
Passport relaxes `idNumber`'s `^[0-9]{13}$`. Literal patterns like `sourceOfFunds`'s
`"[a-zA-Z]"` describe the selection itself and do not redirect.

**What changed as a result.** The link was inferred from field order — "the field after the
dropdown". That works for the current schema but breaks silently if the CRM reorders rows or
inserts a field. On a regulated field that's the wrong failure mode, so the link is now declared:

```swift
FormDependencies(regexDependencies: ["idNumberType": "idNumber"])   // default
```

Field order is still the fallback for links nobody has told us about. Six tests cover it,
including that switching type revalidates without the user re-typing.

### Q4b · What is the actual passport regex? ✅ answered

Not a character-class regex. Length only: any 5–20 characters (`^.{5,20}$`), same idea as
the password field's `^(.){8,20}$`. The named key `passportNumberRegex` still redirects
onto `idNumber` when Passport is selected.

The 5–20 bounds are the ones we already used; say if the real min/max is tighter.

- **Where:** `RegexCatalog.jpcDefaults` in `JackpotFormsDomain/RegexResolving.swift`.

### Q5 · How is a validation message key composed?

Every field in the schema carries the **same** `"validationMessage": "regex"`, yet the web UI
shows per-field copy ("Enter in a valid ID number", "Please select your source of income.").

- **Assumed:** `jpc-reg-{fieldIdentifier}-{validationMessage}`, falling back to the bare key,
  then to humanised copy.
- **Why it matters:** wrong guess = every validation error shows a generic string.
- **Ask:** what key does web build to look these up?

### Q6 · Where do the password rules come from?

The schema gives password one regex, `^(.){8,20}$`. The UI shows **two independently ticking
rules** plus a bar.

- **Assumed:** we parse the `{8,20}` quantifier out of the regex to derive the two rules.
  Reproduces the design exactly for this form.
- **Why it matters:** if the CMS changes the pattern shape (say to require a digit), the
  checklist silently stops matching what's enforced.
- **Ask:** does web have a separate password-rules config, or does it parse the regex too?
- *Note:* confirmed this panel is registration-only, so the parsing approach is contained.

### Q7 · Where does the Welcome Offer come from?

`Welcome Offer` is in the form builder's field-type list and appears throughout the designs —
but there is **no `welcomeOffer` field in the registration schema**.

- **Assumed:** built schema-driven, so it renders if a future schema adds it.
- **Strong hypothesis:** `ConfigData.registration: Registration?` from app-data is the real home.
- **Ask:** what's in `ConfigData.registration`? Is that the offer list? (See also Q11.)

### Q8 · Are `isVisible: false` / `isReadOnly: true` ever used?

Neither appears in the registration schema. Both are implemented.

- **Ask:** are they used by other forms, and does `isVisible: false` mean "don't render" or
  "render disabled"? We assume don't render, and don't validate.

### Q9 · Are section titles ever meant to be displayed?

`formSectionTitle` is `"1"` and `"2"` — not user-facing copy.

- **Assumed:** section title/subtitle are not rendered; sections only drive paging.
- **Ask:** is that right, or should they be localisation keys like every other label?

### Q10 · Two schema regexes look wrong — deliberate?

| Field | Pattern | Behaviour |
|---|---|---|
| `receivePromotionalInformation` | `^true\|^false$` | Due to alternation precedence this is `(^true)\|(^false$)`, so it also matches `"truex"`. Probably meant `^(true\|false)$`. |
| `firstname` / `lastname` | `^[a-zA-Z][a-zA-Z\-\.'\s]{1,20}$` | Requires **at least 2 characters** — a one-letter name is rejected. |

- **Why it matters:** the first is harmless today (we only ever submit `"true"`/`"false"`). The
  second rejects real names.
- **Ask:** is the 2-character minimum intended?

---

## C · Backend — app-data / configuration

### Q11 · What is in `ConfigData.registration`?

The bootstrap response has a `registration` section we don't decode. Most likely home for the
welcome offers (Q7), possibly other registration configuration.

### Q12 · Which `regionCode` is authoritative? ✅ answered (for forms)

Production `buildFormURL` uses `AppSetupData.wmsNavigationRegionCode`. Pass that as
`FormDependencies.live(region:)`. `WMSConfig.regionCode` is a different field; don't mix them
for form URLs.

### Q13 · Where do the app-data URL parameters come from at runtime? ✅ answered

`https://config.jpc.africa/cron/app-data/JZA/IOS/jackpotcity/en-US?api-version=1.0`

- **`en-US` — not user-selectable.** Table loads once per session.
- **`jackpotcity` — the brand / tenant.** Not `synapse`. A second brand would change this path
  component; it is a parameter, default it to the brand.
- **`JZA` — `wmsNavigationRegionCode`** (see Q12).
- **`IOS` — platform.**
- **`cache-control: public, max-age=300`** on this response (Q15 for *forms* is still open).

### Q14 · Can `locales` ever be null?

The captured response returned `null` for five of six sections. `ConfigData` decodes `locale`
with non-optional `decode`, so a null here throws and loses **the entire configuration**.

- **Why it matters:** live bug — see [ADR-0001 §1.1](adr/0001-app-data-decoding-and-configuration-decomposition.md).
- **Ask:** is it guaranteed non-null? Either way the client should stop assuming it.

### Q15 · Is the form schema cacheable?

App-data returns `cache-control: public, max-age=300`.

- **Assumed:** fetch the form on each presentation, no caching.
- **Ask:** what caching headers does the forms endpoint return, and is a stale schema
  acceptable for a session?

---

## D · Product

### Q16 · Is reCAPTCHA used on registration?

It's in the builder's field-type list (v2 and v3) but not in the registration schema. We render
a placeholder.

- **If yes:** needs a site key and a WKWebView bridge — a chunk of work not currently scoped.

### Q17 · Is the 18+ date-picker cap correct?

The form's only age gate is the T&C checkbox ("I am over 18 years of age & I accept…"). We
additionally cap the date-of-birth picker at 18 years ago so an under-18 date can't be entered.

- **Ask:** is a hard cap right, or should an under-18 date be enterable and rejected with a
  message? (Regulatory question as much as a UX one.)

### Q18 · Should "Previous" preserve entered data?

We keep everything; going back and forward loses nothing.

- **Ask:** confirm that matches web.

---

## Answered

- ~~Do named option regexes drive a dependent field?~~ **Yes** — ID vs passport selects which
  rule `idNumber` validates against. Link now declared explicitly rather than inferred from
  field order. (Q4)
- ~~What is the passport rule?~~ Length only, `^.{5,20}$` — not alphanumeric. (Q4b)
- ~~Is the locale user-selectable?~~ **No.** `TranslationsStore` loads once per session; no
  refetch, no re-render on switch.
- ~~Is the password strength panel used elsewhere?~~ Registration only — so deriving rules from
  the registration schema's regex is contained.
- ~~Is `code` a String or Int?~~ `Int`. Was typed `String?`, which meant `{"code": 0}` silently
  decoded to nil and every error message rendered empty.
- ~~Which status codes does the API use?~~ **It depends.** Generic problem envelopes still
  use 200 / 400 / 401 / 500. Form submit uses HTTP 200 for *both* outcomes and puts the
  truth in `isSuccessful`.
- ~~What does the registration POST look like?~~ `POST /cron/forms/submit` with
  `FormSubmission`. Response is `{ data, isSuccessful, error }`, not a boolean. (Q1)
- ~~What happens after a successful registration?~~ Account id + JWT on
  `complianceResponse.accessToken`. FICA can still require a manual upload. (Q2)
- ~~Are error codes a catalogue?~~ Yes — `jpc-reg-error.{code}` for registration,
  bare numbers for others. (Q3)
- ~~Which regionCode is authoritative for forms?~~ `AppSetupData.wmsNavigationRegionCode`. (Q12)
- ~~What is the app-data tenant?~~ `jackpotcity`, not `synapse`. (Q13)
