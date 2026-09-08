# Launch Performance — Config Caching

The bootstrap call is on the critical path of every launch and the app currently waits for it.

```
GET https://config.jpc.africa/cron/app-data/JZA/IOS/synapse/en-US?api-version=1.0
cache-control: public, max-age=300 · last-modified: … · content-encoding: br · server: cloudflare
```

---

## The two things worth getting right first

### `max-age=300` is a CDN knob, not a launch policy

Five minutes is a sensible edge-cache TTL. As a *client* policy it is close to useless: app
launches are usually hours apart, so honouring it means a full fetch on essentially every cold
start. `URLCache` honours it automatically, which is why "just turn on URLCache" doesn't help
here.

The client should keep the last good payload **indefinitely** and decide separately how stale is
too stale. Those are different questions and the response header only answers the first.

### Stale config is not uniformly safe

This is the part that decides the design, and it isn't a technical call.

| Section | If it's a day old |
|---|---|
| `locales` | wrong copy; self-corrects on next launch; harmless |
| `redirects` | a dead link |
| `sitemaps` | navigation offers a removed vertical, or misses a new one |
| `wmsconfig` — feature flags, verticals, licence | **a game or provider disabled for compliance still appears** |

"Cache the config" sounds obviously right until that last row. Whatever number goes in
`maxStale` is owned by whoever owns the compliance answer, not by us. The default is 12 hours
and is deliberately conservative.

---

## Strategy comparison

| | Removes launch latency | Effort | Notes |
|---|---|---|---|
| **Stale-while-revalidate from disk** | **yes, from launch 2 onward** | low | recommended |
| Conditional GET (`If-Modified-Since` / `ETag`) | no — still a round trip | low | halves the payload cost of revalidation; complements SWR |
| `URLCache` with default policy | no | none | expires after 5 minutes |
| `URLCache` + `.returnCacheDataElseLoad` | yes | none | but you never get fresh config; unusable |
| Bundled seed payload | yes, including first launch | medium | ships stale config; **safe for `locales` only** |
| Prefetch at `didFinishLaunching` | partially | low | worth doing regardless — overlaps the fetch with UI construction |
| Ask backend to split the payload | maybe | high | only worth raising if `locales` dominates the size |

### Recommended: stale-while-revalidate + conditional GET

```
first ever launch   no cache      → skeleton, one round trip, cache it
every launch after  cache hit     → render at zero latency, revalidate in background
config changed      cache hit     → render at zero latency, background 200, UI updates in place
offline             cache hit     → render at zero latency, revalidation fails and is ignored
cache > maxStale    treated as no cache → skeleton, wait
```

The skeleton then appears on the **first launch only**, not on every launch.

---

## What's implemented

### `JackpotNetworking` — conditional requests

```swift
let result = try await apiClient.requestConditional(endpoint, validators: stored)
// → .notModified            (304, empty body)
// → .fresh(Data, HTTPValidators?)
```

`HTTPValidators` captures `ETag` and `Last-Modified` from a response and sends them back as
`If-None-Match` / `If-Modified-Since`. The response we've seen carries `last-modified`; if the
service also emits `etag`, that's used in preference.

### `JackpotAppData` — cache and loader

```swift
let loader = AppDataLoader(
    apiClient: client,
    cache: FileAppDataCache(),
    policy: .default                 // refreshAfter: 0, maxStale: 12h
)

// On launch, before any UI:
if let snapshot = await loader.cached(region: "JZA", tenant: "synapse", locale: "en-US") {
    apply(snapshot.response)          // zero latency
} else {
    showLaunchSkeleton()              // first launch, or beyond maxStale
    apply(try await loader.load(region: "JZA", tenant: "synapse", locale: "en-US").response)
}

// Always, in the background:
Task { if let fresh = try? await loader.refresh(...) { apply(fresh.response) } }
```

`AppDataSnapshot.origin` tells you where the payload came from (`.none` / `.cache(age:)` /
`.network`) — that's the signal for whether to show a skeleton, and it's what you'd log to
measure the hit rate in the field.

Two behaviours worth knowing:

- **A 304 re-stamps the cache.** The entry ages from the last time we *confirmed* it, not the
  last time the content changed — otherwise a config nobody edits for a fortnight falls out of
  the staleness budget while being perfectly current.
- **A failed revalidation is swallowed.** Config is not worth blocking a launch for when a good
  payload is already on disk. `FileAppDataCache` writes atomically, so a half-written payload
  can't survive to the next launch.

12 tests, including offline, malformed cache, and beyond-`maxStale`.

### The launch skeleton — not implemented

`JackpotUI` has no launch skeleton yet; the package carries only what registration draws. When
the app adopts `AppDataLoader`, draw the actual shell — header, verticals strip, content, bottom
bar — as placeholders, so nothing shifts when config lands. A generic spinner is less work and
worse: content jumping in from nothing reads as slower than it is. Keep any shimmer slow and
low-contrast, and hold it still under Reduce Motion.

---

## Not implemented — decisions needed first

**Bundled seed payload.** Would remove the skeleton from first launch too. Safe for `locales`
(worst case, a missing string renders humanised); risky for `sitemaps` and `wmsconfig`, which
could reference screens or flags that no longer exist. Because `AppDataResponse` is already
section-wise, seeding *only* `locales` is possible and is the version I'd suggest.

**Prefetch at `didFinishLaunching`.** Worth doing regardless of caching — fire the request
before UI construction rather than after. Needs to happen in the app target.

**Backend split.** Only worth raising once you know the payload size and what share is `locales`.

---

## Measure before and after

The design removes one round trip from every launch after the first. Whether that's 150ms or
2s depends on your numbers, which I don't have:

1. **Payload size** — `curl -s -H 'Accept-Encoding: br' <url> | wc -c`, compressed and not.
2. **Time-to-first-byte and total**, on cellular, at p50 and p95 — `cf-cache-status: MISS` in the
   captured response means that one didn't hit the edge.
3. **Time from `didFinishLaunching` to first interactive frame**, today.
4. After shipping: log `AppDataSnapshot.origin` — a low `.cache` rate means `maxStale` is too
   tight or the key is fragmenting.

Item 4 matters most. Everything above assumes launches are hours apart; if a meaningful share
are minutes apart, the numbers change and so might the policy.
