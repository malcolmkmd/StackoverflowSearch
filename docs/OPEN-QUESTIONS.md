# Open Questions

Everything the registration work assumed rather than knew. Grouped by who can answer it.

Each entry says what we assumed, what breaks if the assumption is wrong, and — where it exists —
the switch to flip once you have the answer.

**Nothing currently blocks PR 5.** Q1 and Q2 are deferred by decision — the app PR ships with
`MockRegistrationService` wired, so the screen is live and validated while the submit contract is
still being confirmed. Flipping to `RemoteRegistrationService` is one line.

**Highest value now: Q4b** — the passport pattern is the only invented value left in a
confirmed, regulated behaviour.

---

## A · Backend — the registration POST

### Q1 · What does the registration endpoint look like? ⏸ deferred

Path, request body shape, and response body shape.

- **Assumed:** `POST {base}/registration`, body is the flat `[String: String]` of field
  identifiers → values, response is `{ accountNumber, requiresOtp }`.
- **Why it matters:** `RemoteRegistrationService` compiles but is a guess. PR 5 ships with
  `MockRegistrationService` wired until this is answered, so the *screen* is live but the
  *submit* isn't.
- **Where:** `JackpotRegistration/RegistrationService.swift` → `RegisterRequest`, marked `TODO`.
- **Status:** deferred by decision. PR 5 ships with the mock service; swap is one line.

### Q2 · What happens after a successful registration? ⏸ deferred

Auto-login (does the response carry a session)? Straight to OTP? Back to Login?

- **Assumed:** `RegistrationResult(accountNumber:requiresOTP:)` and the app routes. A placeholder.
- **Why it matters:** it's the completion callback's entire contract, and it decides whether
  registration needs the session layer at all.
- **Where:** `RegistrationResult` in the same file.

### Q3 · Are the error `code` values a documented catalogue?

The app-data `locales` table has entries keyed by number — `6000328` → "Maximum OTP tries
reached…" — so codes are localisation keys. But is `code: 0` a real code, or "no specific code"?

- **Assumed:** codes are looked up in the locale table; unknown codes fall back to the
  envelope's `message`. `0` is treated as "no specific code".
- **Why it matters:** if `0` *is* meaningful, players get the wrong copy for the most common error.
- **Ask for:** the code list, or at least the registration-relevant ones (duplicate mobile,
  underage, blocked ID, etc.).

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

### Q4b · What is the actual passport regex? 🔴 highest priority

The schema references `passportNumberRegex` **by name** and never sends the pattern.
`idNumberRegex` is safe — it matches the `idNumber` field's own schema regex, `^[0-9]{13}$`.
**`passportNumberRegex` is invented by us.**

- **Currently:** `^[a-zA-Z0-9]{5,20}$`, chosen deliberately permissive.
- **Why loose on purpose:** the failure modes aren't symmetric. Too strict and a real passport
  is rejected client-side and the user *cannot register at all*. Too loose and the server
  rejects it, the user sees a message and retries. The server validates either way.
- **Ask:** where do the named regexes live — a config endpoint, a shared constants file, hard-coded
  in web? Send the pattern.
- **Where:** `RegexCatalog.jpcDefaults` in `JackpotFormsDomain/RegexResolving.swift`, flagged in
  source. The test asserts the *property* (accepts realistic passport shapes) rather than the
  literal, so replacing the pattern won't break it.

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

### Q12 · Which `regionCode` is authoritative?

Two exist: `WMSConfig.regionCode` and `AppSetupData.wmsNavigationRegionCode`. The legacy
`getTranslation` used the second.

- **Assumed:** they agree.
- **Why it matters:** the region drives the `-jza` suffix in translation lookup. If they can
  diverge, some copy resolves against the wrong region.

### Q13 · Where do the app-data URL parameters come from at runtime? ⚠️ partly answered

`…/cron/app-data/JZA/IOS/synapse/en-US?api-version=1.0`

- **`en-US` — ✅ answered: the locale is not user-selectable.** So the translation table is
  fetched once per session and never refetched, and no screen needs to re-render on a locale
  change. That removes a design constraint from `TranslationsStore` — it can stay a simple
  load-once store.
- **`synapse` — still open.** What is it? A tenant, a brand, a platform build? It's hard-coded in
  our call. Worth knowing whether it ever varies (a second brand on the same platform would
  change it).
- **`JZA` — presumed the region code**, same value as the `-jza` translation suffix. Confirm they
  are always the same value; see Q12.

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
  field order. (Q4 — but the passport *pattern* is still unknown, see Q4b.)
- ~~Is the locale user-selectable?~~ **No.** `TranslationsStore` loads once per session; no
  refetch, no re-render on switch.
- ~~Is the password strength panel used elsewhere?~~ Registration only — so deriving rules from
  the registration schema's regex is contained.
- ~~Is `code` a String or Int?~~ `Int`. Was typed `String?`, which meant `{"code": 0}` silently
  decoded to nil and every error message rendered empty.
- ~~Which status codes does the API use?~~ 200 / 400 / 401 / 500.
