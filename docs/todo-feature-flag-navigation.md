# Deferred Task — Centralize Per-Series Navigation in Feature Flags

**Status:** Not started — deliberately deferred to avoid risk to the live app.
**Raised:** 2026-06-18
**Owner:** TBD

## Why this is parked

The footer navigation and per-series capabilities currently live in **two
places**, which makes the Urdu/Arabic split harder to reason about:

| Concern | Where it lives today |
|---|---|
| Which tabs a series shows | Derived in [`lib/screens/shell_screen.dart`](../lib/screens/shell_screen.dart) from `series.hasBook` / `series.hasStudyMode` |
| Per-series capabilities | `series.json` (`hasStudyMode`, `hasBook`) in the content repo |
| Global feature toggles | `feature-flags.json` → `features` |
| Route guards | [`lib/app.dart`](../lib/app.dart) redirects on `currentSeries.hasBook` / `hasStudyMode` |

Because the current behaviour ships in production and the multi-series flow is
live, we chose **not** to refactor navigation now. The immediate ask (a
remotely-toggleable series switcher) was solved with the lighter-weight
`seriesSwitcher` feature flag instead — see below.

## What was done now (the safe slice)

- Added a `seriesSwitcher` boolean to `feature-flags.json` → `features`
  (default **off**). It gates only the Settings "Series" switcher UI; multi-series
  resolution is still governed by the experimental `multiSeries` flag.
- No change to how footer tabs are computed — they remain driven by
  `series.json`'s `hasBook` / `hasStudyMode`.

> **Interim workaround for "add a Book tab to the Urdu series":** set
> `hasBook: true` for `tawheed-ur` in `series.json` and publish the Urdu book
> content. The Book tab and `/book` route already key off `series.hasBook`, so no
> app release is required. The refactor below is only about *centralizing* that
> control, not unblocking it.

## The deferred work

Goal: make footer navigation **declaratively controllable from
`feature-flags.json`**, per series, so capabilities have a single source of
truth and a Book tab (or any future tab) can be turned on without touching two
files.

Proposed schema (per-series tab list — preferred option from design review):

```json
"series": {
  "tawheed-ur": { "tabs": ["lectures", "study", "home", "settings"] },
  "tawheed-ar": { "tabs": ["lectures", "book", "home", "settings"] }
}
```

### Implementation sketch

1. **Model** — add a `SeriesNavConfig` (parsed from `feature-flags.json`'s
   `series` block) mapping series id → ordered tab list. Fall back to today's
   derived list (`_tabsFor`) when the block is absent, so partial/missing config
   never breaks navigation.
2. **shell_screen.dart** — replace `_tabsFor(series)` with a lookup against the
   nav config, defaulting to the derived list.
3. **Route guards (app.dart)** — keep `/book` and `/study` redirect guards, but
   source the "is this tab allowed" decision from the same nav config so a
   hidden tab can't be deep-linked into.
4. **Deduplicate** — once nav is config-driven, decide whether `hasBook` /
   `hasStudyMode` stay in `series.json` purely as *content-availability* signals
   or are removed in favour of the flag block. (They still gate whether content
   exists, so likely keep them but stop deriving nav from them.)
5. **Migration safety** — ship the nav config additively first (app reads it if
   present, ignores it if not), verify in staging, then publish the
   `series` block. Never remove the fallback path.

### Test coverage to add

- Nav config present → tabs render exactly as listed, in order.
- Nav config absent → falls back to `hasBook`/`hasStudyMode`-derived tabs.
- A tab hidden by config cannot be reached via direct route (guard redirects).
- Urdu series with `book` tab enabled shows the Book tab and `/book` works.

## Acceptance criteria

- [ ] Footer tabs for each series are controlled entirely by `feature-flags.json`.
- [ ] Adding/removing a tab requires only a content-repo edit, no app release.
- [ ] Missing/partial config falls back to current behaviour (no regression).
- [ ] Route guards respect the same config (no deep-link bypass).
- [ ] Single source of truth documented; `onboarding-flows.md` updated if flows change.
