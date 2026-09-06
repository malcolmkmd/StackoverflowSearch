# ADR-0001 · App-Data Decoding and Configuration Decomposition

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-09-05 |
| **Supersedes** | — |
| **Affects** | `ConfigData`, `GlobalData`, `getTranslation(Key:regional:)`, all config consumers |
| **Related** | [PR-STRATEGY.md](../PR-STRATEGY.md) · registration rewrite (ships ahead of this — see *Scope Boundary*) |

---

## 1. Context & Root Cause

The app bootstraps from a single request made once per session:

```
GET https://config.jpc.africa/cron/app-data/{region}/IOS/{tenant}/{locale}?api-version=1.0
```

The response is an envelope of six unrelated sections, each owned by a different part of the
app:

```json
{ "appsettings": …, "wmsconfig": …, "registration": …,
  "redirects": …, "sitemaps": …, "locales": … }
```

It is currently decoded into one model, `ConfigData`, and stored on
`GlobalData.sharedData.configData`. Three defects follow from that.

### 1.1 Decoding fragility — a correctness bug, not a style issue

```swift
struct ConfigData: Codable {
    let locale: [String: String]                    // non-optional
    // …every other section is optional

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.locale       = try container.decode([String: String].self, forKey: .locale)
        self.wmsConfig    = try container.decodeIfPresent(WMSConfig.self,    forKey: .wmsConfig)
        self.appsettings  = try container.decodeIfPresent(WMSConfig.self,    forKey: .appsettings)
        self.redirects    = try container.decodeIfPresent([Redirect].self,   forKey: .redirects)
        self.sitemaps     = try container.decodeIfPresent(Sitemaps.self,     forKey: .sitemaps)
        self.registration = try container.decodeIfPresent(Registration.self, forKey: .registration)
    }
}
```

`locale` is the only section decoded with non-optional `decode`. If the CMS returns
`"locales": null` or omits the key, `init(from:)` throws and **the entire configuration is
lost** — including `wmsconfig`, `sitemaps`, `redirects`, `appsettings` and `registration`, none
of which have any relationship to copy.

This is not theoretical. A captured production response for `JZA/IOS/synapse/en-US` returned
`null` for five of the six sections. The five that happened to be null are the five declared
optional. The sixth is one CMS edit away from a total configuration failure at launch.

**Blast radius:** navigation (sitemaps), feature flags and region metadata (wmsconfig),
deep-link handling (redirects), and registration configuration all fail together, for a reason
unrelated to any of them.

### 1.2 God-object coupling

One model binds six domains. Every feature needing a slice of configuration adds a property to
`ConfigData`, which means:

- No section can be extracted into a module without taking the other five with it.
- A schema change in one domain forces recompilation and re-review across all of them.
- The type only grows; there is no mechanism by which it shrinks.

### 1.3 Ambient global state

Consumers read configuration through `GlobalData.sharedData.configData`. Consequences:

- **Untestable.** A screen cannot be exercised without mutating process-wide state.
- **Un-previewable.** SwiftUI previews cannot supply fixtures.
- **No isolation.** Test ordering becomes significant; there is no second configuration.

The localisation helper is the clearest instance:

```swift
func getTranslation(Key: String, regional: Bool = false) -> String {
    let region = GlobalData.shareData.AppSetupData.wmsNavigationRegionCode.lowercased()
    let locale = GlobalData.shareData.configData?.locale
    let lowercasedLocale = locale?.reduce(into: [String: String]()) { result, pair in
        result[pair.key.lowercased()] = pair.value        // rebuilt on EVERY call
    } ?? [:]
    return lowercasedLocale[regionalKey] ?? lowercasedLocale[normalizedKey] ?? Key
}
```

Besides the two global reads, this rebuilds the entire lowercased table on every lookup. The
table has hundreds of entries; a screen reading thirty strings performs thirty full rebuilds
per render pass.

---

## 2. Key Architectural Decisions

### D1 · Ingest raw `Data`; do not decode into a root model

`ApiClient` gains `requestData(_:)`. The bootstrap response is fetched as bytes, not as a typed
root object.

**Rationale.** A typed root necessarily couples the fate of every section to the strictest
field in the model. Deferring the decode is what makes per-section independence possible.

### D2 · Split the payload by top-level key (`AppDataResponse`)

```swift
public struct AppDataResponse: Sendable, Equatable {
    private let sections: [String: Data]

    public init(data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppDataError.notAnObject
        }
        sections = object.reduce(into: [:]) { result, pair in
            guard !(pair.value is NSNull) else { return }          // null == absent
            guard let data = try? JSONSerialization.data(withJSONObject: pair.value,
                                                        options: [.fragmentsAllowed]) else { return }
            result[pair.key] = data
        }
    }

    /// Never throws. One feature's malformed section must not break another's.
    public func section<T: Decodable>(_ key: String, as type: T.Type = T.self,
                                      decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = sections[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// Diagnostic: which sections actually arrived.
    public var presentSections: [String] { sections.keys.sorted() }
}
```

One network call, N independent decodes. A malformed `wmsconfig` returns `nil` for
`wmsconfig` only; a null `locales` costs the strings and nothing else.

**Rationale.** Failure is isolated to the section that failed. Unknown sections — the CMS adds
them without an app release — are ignored rather than fatal, and remain visible via
`presentSections`.

### D2a · Ingestion lives in its own target (`JackpotAppData`), separate from localisation

`AppDataRequest` and `AppDataResponse` ship in `JackpotAppData`; `Translations` and its store ship in
`JackpotLocalization`, which depends on it.

**Rationale.** Reading the bootstrap payload is not a localisation concern — every feature reads
its own section from it. Bundling the two would also have forced the localisation migration to
ship at the same time as the configuration fix, which the delivery plan deliberately separates:
the config fix is early and contained, the localisation migration is last and wide.

### D3 · Section ownership is per feature; there is no shared root model

Each feature decodes the slice it owns from the same `AppDataResponse`:

| Section | Owner |
|---|---|
| `locales` | `JackpotLocalization` |
| `wmsconfig`, `appsettings` | App settings |
| `sitemaps` | Navigation |
| `redirects` | Deep linking |
| `registration` | Sign-up |

**Rationale.** This is the structural fix for §1.2. No type accumulates fields from six domains,
and a section can be moved into a module without disturbing the others.

### D4 · Protocol-backed services replace free functions and global reads

```swift
public protocol TranslationsRepository: Sendable {
    func translations(region: String, tenant: String, locale: String) async throws -> Translations
}

public struct Translations: Sendable, Equatable {   // value type — injectable, comparable
    public func string(forKey key: String, regional: Bool = true) -> String?
    public func message(forErrorCode code: Int) -> String?
}

@MainActor public final class TranslationsStore: ObservableObject {   // session-scoped owner
    @Published public private(set) var translations: Translations
    public func load(region:tenant:locale:)      // coalesced
    public func adopt(_ translations: Translations)   // migration seam — see M1
}
```

The table is normalised **once**, at construction, eliminating the per-lookup rebuild in §1.3.

**Rationale.** A protocol seam makes consumers testable and previewable. A value type makes a
second table possible — for tests, previews, and locale switching — which a global forbids.

### D5 · A composition root replaces the singleton

Services are constructed in an `AppContainer` at launch and passed through initializers. No
type reaches for ambient state.

**Rationale.** Explicit dependencies are visible in the type signature and substitutable in
tests. This is the precondition for D3 to hold over time: without it, features re-acquire
configuration globally and section ownership erodes.

### D6 · Leniency is bounded by diagnostics

`section(_:as:)` returning `nil` converts a loud failure into a quiet one. To prevent that
becoming an invisible outage:

- `presentSections` is logged at bootstrap.
- A DEBUG assertion fires when a section the current build depends on is absent.
- Section decoding failures are reported to telemetry with the section key.

**Rationale.** Isolating failure is only an improvement if the failure is still observable.

### D7 · Registration ships on the existing `getTranslation` — deliberate scope boundary

The registration rewrite lands **before** this migration and uses the current global helper via
a single adapter. See *Scope Boundary* below.

---

## 3. Impact / Risk Analysis

### 3.1 Impact

| Area | Before | After |
|---|---|---|
| Config resilience | one bad section loses all six | failure isolated to the section |
| Null `locales` | total configuration failure at launch | strings degrade to keys; other five load |
| Translation lookup | O(table) rebuild per call | O(1); table normalised once |
| Testability | global mutation required | initializer injection |
| Modularity | `ConfigData` blocks extraction | sections extractable independently |
| Diagnostics | decode failure is opaque | `presentSections` + per-section telemetry |

### 3.2 Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | **Leniency masks a real breakage.** A section that silently fails to decode looks the same as one the CMS never sent. | Medium | D6: bootstrap logging, DEBUG assertion, telemetry on decode failure. Ship these with Phase 1, not after. |
| R2 | **Behavioural drift during bridging.** Phase 1 reconstructs `ConfigData` from `AppDataResponse`; a mismatch changes what legacy call sites see. | Medium | Bridge is a pure function over the same bytes. Snapshot-test the bridged `ConfigData` against captured production payloads before merge. |
| R3 | **`getTranslation` region semantics.** The legacy helper applies the region suffix only when `regional: true`; `Translations` defaults to region-first. | Medium | The Phase 2 shim passes `regional:` through as given. Existing call sites return byte-identical strings. New code opts into the better default explicitly. |
| R4 | **Registration inherits the O(table) lookup cost** (see Scope Boundary). | Low–Medium | The form performs ~36 lookups per render pass. Optional one-line mitigation available now; fully resolved by Phase 2. |
| R5 | **Two region sources.** `WMSConfig.regionCode` and `AppSetupData.wmsNavigationRegionCode` both exist. | Low | Confirm they cannot diverge; if they can, pick one as authoritative in `AppContainer` and record it here. |
| R6 | **Partial migration stalls.** Phases 3–4 are long-tail work that can be deprioritised indefinitely, leaving two idioms in place. | Medium | `@available(*, deprecated)` on the shim makes remaining call sites compiler warnings. Ratchet the warning count in CI so it can only fall. |
| R7 | **`JSONSerialization` round-trip cost.** Splitting re-serialises each section. | Low | One call per session; payload is ~100 KB. Measured cost is immaterial against the network round trip. |

### 3.3 Explicitly not addressed

- The remaining `GlobalData` responsibilities (view-controller registry, balance, inbox, session). Configuration only.
- The `*API` classes. New endpoints use `ApiClient`; existing ones convert on demand.
- Error-code localisation beyond forms. `Translations.message(forErrorCode:)` exists; adoption elsewhere is out of scope.

---

## 4. Migration Plan

Each phase is independently shippable. No phase requires a feature freeze.

### Phase 1 · Safe ingestion, bridged model *(1–2 days)*

1. Add `ApiClient.requestData(_:)`.
2. Introduce `AppDataResponse`; fetch bytes at bootstrap.
3. Reconstruct `ConfigData` from the split sections and assign to `GlobalData.sharedData.configData` as today.
4. Ship D6 diagnostics.

**Legacy call sites are untouched and behaviour is unchanged**, except that a null or malformed
section no longer destroys the rest of the configuration.

*Exit criteria:* snapshot tests pass against captured production payloads; bootstrap logs
`presentSections`; a synthetic `"locales": null` payload no longer loses `sitemaps`.

### Phase 2 · Hollow the singleton *(2–3 days)*

1. Stand up `AppContainer` with `TranslationsStore` and the config services.
2. `GlobalData.sharedData` becomes a forwarder to `AppContainer`; it holds no state of its own.
3. Reimplement the helper as a shim:

```swift
@available(*, deprecated, message: "Inject TranslationsStore; call translations(key)")
@MainActor
func getTranslation(Key: String, regional: Bool = false) -> String {
    // `regional` passed through as given (R3): existing call sites are byte-identical.
    AppContainer.shared.translations.translations(Key, regional: regional)
}
```

**This is the highest-leverage step.** The per-lookup table rebuild is eliminated for the entire
app in one merge, with zero call-site changes. The deprecation turns every remaining call site
into a compiler warning — a burn-down list generated by the compiler rather than maintained by
hand.

*Exit criteria:* translation-heavy screens measurably faster; warning count baselined and
ratcheted in CI.

### Phase 2a · Localisation migration is sequenced last

The `getTranslation` shim, and everything downstream of it, is the **final** track of work — see
[PR-STRATEGY.md](../PR-STRATEGY.md) §4.

**Rationale.** It changes the mechanism behind every string in the app: the widest blast radius
of any change here, and the one most likely to produce a subtle copy regression. There is no
dependency requiring it to precede anything else, so it goes last, alone, and reverts cleanly.

### Phase 3 · Call-site modernization *(ongoing)*

Refactor screens to accept injected dependencies, ranked by call-site count:

```bash
grep -rn "getTranslation(" --include=*.swift . | cut -d: -f1 | sort | uniq -c | sort -rn
```

Existing `*TranslationsKeys` enums are retained unchanged — call sites pass `key.rawValue` to
`Translations`. Only the lookup mechanism moves.

*Exit criteria:* deprecation warnings at zero.

### Phase 4 · Deletion *(1 day)*

Remove `GlobalData`, `ConfigData`, the shim and the bridge. Retire the CI warning ratchet.

*Exit criteria:* no references remain; both types deleted.

### Scope Boundary · Registration ships ahead of this work

The registration rewrite lands before Phase 2 and consumes the existing `getTranslation` through
one adapter:

```swift
/// TRANSITIONAL. Replaced by `TranslationsLocalizer` in Phase 2.
struct LegacyTranslationLocalizer: FormLocalizing {
    func string(forKey key: String) -> String? {
        let value = getTranslation(Key: key)
        // `getTranslation` returns the key itself on a miss. `FormLocalizing` uses nil to
        // signal "unresolved" so the engine can fall back to humanised copy — without this
        // mapping, a missing string renders as the raw key ("username") instead of a
        // readable label.
        return value == key ? nil : value
    }
}
```

**Rationale.** Decoupling the registration flow's delivery from a multi-phase configuration
migration. The coupling is one file, one protocol conformance, and is deleted in Phase 2.

**Accepted consequence (R4).** The form performs roughly 36 lookups per render pass (12 fields ×
label, placeholder, validation message), each triggering the O(table) rebuild. If this proves
material before Phase 2, snapshot the table once per form load rather than per lookup:

```swift
struct SnapshotLocalizer: FormLocalizing {
    private let table: [String: String]      // built once, at form load
    init() { table = GlobalData.shareData.configData?.locale ?? [:] }
    func string(forKey key: String) -> String? { table[key.lowercased()] }
}
```

That is a contained change to the adapter and does not pull Phase 2 forward.
