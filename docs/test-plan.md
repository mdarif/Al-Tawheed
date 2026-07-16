# Test plan — the gaps that matter

Companion to [testing.md](testing.md) (which is *how to run* the suite). This is
*what is missing and why*, ranked. It is a living backlog: close an item, delete
it from here, and leave the landmine in [gotchas.md](gotchas.md).

## How this is prioritized

**Not by coverage %.** The suite is at 418 tests and the gaps are not where the
percentage is lowest. Every item below is ranked by:

> *Has this class of bug actually shipped in this repo?* × *what does it cost
> when it does?*

That ranking comes from mining `docs/gotchas.md`, the ADRs, and every `fix(`
commit. The four classes that actually recur here are:

1. **i18n numeral/script + chrome-locale** — ~10 fixes, and a decision that has
   swung **three times**, each swing shipping a real regression. Now the
   best-tested area in the app.
2. **Book content corruption** — 3 fixes touching 170+ text sites, including two
   that *inverted the meaning of scripture*. **Effectively unguarded.**
3. **Test-harness fidelity** — the repo's own meta-bug (below).
4. **Release/CI toolchain** — one-shot latent traps, doc-only.

### The meta-bug to design against

This repo's tests have a documented habit of **being written around bugs instead
of catching them**. Four recorded instances:

- `respects a previously saved selection` asserted only `hasSelectedSeries`,
  never `currentSeries.id` — the exact field that was wrong (`deea15a`).
- `_RtlProbe` **reimplemented** the provider's logic instead of testing it, then
  drifted (it omitted Arabic), so "Arabic is RTL" passed with production broken.
- `remote_content_service_test` covered the pure `decideCacheStrategy` while the
  actual fetch/retry path had **zero** coverage — that path was the 2.3.0
  fresh-install outage.
- `book_service_test`'s Urdu assertions were a deliberate temporary concession
  that outlived its reason by three commits (below).

**Therefore, a rule for every test added from this list: prove it fails without
the fix.** Two tests in the last session were confirmed that way (the manifest
cold-start, the mirrored brackets) and both would otherwise have been vacuous.

---

## P0 — unguarded, high-stakes

### 1. Book content integrity ⭐ the single highest-value gap

**Status today:** `test/book_service_test.dart` asserts the **Arabic** book
strictly (67 chapters, `ch-01`…`ch-67`, non-empty title+text for every chapter).
For **Urdu** it asserts exactly two things: `chapters` is non-empty, and
`chapters.first.text` is non-empty.

> If `book_tawheed-ur.json` silently lost 60 of its 67 chapters, or every chapter
> after the first went blank, **the suite stays green.**

Its comment still reads *"a placeholder copy of the Arabic matn until the clean
Urdu text lands"* — false since `bb33dc3`. The weak assertions were a temporary
concession; the content swap happened and nobody tightened them.

**Why this is P0 and not P2:** this file is scripture, it is 339 KB of *hand*
transcription (the source PDF's Nastaliq text layer is corrupted — see gotchas —
so every chapter was read by eye), and its history is:
- **168** print-verified corrections across all 67 chapters (`bb33dc3`)
- ch-62 dropped `نہیں`, **inverting** "will *not* be trusted"
- ch-60 lost `میں`, inventing a non-existent "Sunan Ibn Daylami"
- 3 verses rendered with no Arabic and no citation (`73ca16b`), from three
  stacked causes: the assembler discarding trailing `[سورہ …]`, ranges split on
  the Arabic comma `،`, and **homoglyphs** — `ar.json` uses Arabic kaf `ك` where
  the Urdu print uses keheh `ک`, so `العنکبوت` never matched `العنكبوت`.

**And the tooling that caught all of it no longer exists.** It lived outside the
repo (`~/kat-urdu-work/`); the commits cite a `urdu_qa.md` policy log that was
never committed. Same pattern as the builder script gotchas admits lives in
`/tmp`. Today the āyah-pairing/citation QA **cannot be re-run**.

| # | Test | Guards |
|---|---|---|
| 1.1 | Port the Arabic strictness to Urdu verbatim: 67 chapters, ids `ch-01`…`ch-67` contiguous, no dupes, non-empty `title`+`text` | The vacuous-assertion hole. Verified the file passes this today |
| 1.2 | Markup well-formedness per chapter: `﴾`/`﴿` balanced and correctly ordered, `[`/`]` balanced, `«`/`»` balanced | `73ca16b` (dropped citations); the reader's parser silently renders unbalanced runs as plain text |
| 1.3 | Every `﴾verse﴿` run is followed by a `[citation]` run | `73ca16b` — the exact defect |
| 1.4 | **Homoglyph guard**: citations normalise `ک`→`ك`, `ی`→`ي` before comparison; ranges split on `،` as well as `,` | `73ca16b` root cause #2 and #3 |
| 1.5 | **Cross-edition parity**: both books 67 chapters; per-chapter āyah citation sets match between `ar` and `ur` | The *whole* reason the ch-18/al-Qasas omission was found. Nothing checks it now |
| 1.6 | `_isMasailHeading` run against **real** content: exactly one heading per chapter, never matching a numbered `مسئلہ` item | Shipped rule with only synthetic fixtures. The web repo's regex already misses ch-06 and ch-36 |
| 1.7 | Chapter-count + id-list snapshot, so a bad regen is loud rather than silent | The assembler has corrupted this file once already (the tashkeel regex) |

**Also: re-home the validator into the repo** as `tool/validate_book.py` (or Dart,
so it runs in `flutter test`), wired to `make test`. An out-of-repo QA harness is
not a guard — it is a memory of one. This is the one place in the app where
"error free" is not hyperbole: a dropped particle changes what the text *says*.

### 2. ARB 4-locale parity

All four locales are at **154/154** today — by discipline alone. `AGENTS.md` rule
#1 calls an English-only addition "a bug", `l10n.yaml` sets no
`untranslated-messages-file`, and **no test reads the ARB files**.

| # | Test | Guards |
|---|---|---|
| 2.1 | All 4 locales have identical key sets | Rule #1, mechanically |
| 2.2 | Per key, the **placeholder set matches** across locales | A locale missing `{duration}` silently drops data at runtime, and gen-l10n won't complain |
| 2.3 | No key has an empty string value | Silent blank labels |
| 2.4 | ICU plural/select syntax parses in every locale | `partsCount` uses `Intl.pluralLogic` in `ar` only |

Pure Dart, no device, milliseconds. Should gate every PR.

### 3. Delete the tests that lie

Not new coverage — removing false signal, which the meta-bug above says is this
repo's characteristic failure.

- **`test/unit_test.dart` — delete it.** Zero `package:myapp` imports. Its 5
  tests assert on a "Channel model", a "Video model", a YouTube URL, and
  `https://api.example.com` — none of which exist in this app. It is scaffolding
  from a template and contributes 5 of the 418.
- **`test/book_service_test.dart`** — fix the false comment as part of 1.1.
- **`make test-units`** runs `flutter test test/unit_tests.dart` (plural). That
  file does not exist; the target always fails.
- **`make format`** runs `flutter format .`, removed from the Flutter CLI.
- **`codecov.yml`** ignores `app_localizations_ur_roman.dart` and
  `generated_plugin_registrant.dart` — **neither exists** — and does *not* ignore
  `app_localizations_ar.dart`, which does. Arabic l10n boilerplate is dragging
  the number down.

---

## P1 — recurring classes, partial guards

### 4. Golden tests for the multi-script UI

**Zero today**, in an app whose bugs are overwhelmingly *visual*:

- Chapter badges drew **Persian-shaped** 4/5/6/7 (`194f7ef`). The codepoints were
  right; the **font** was wrong. Every codepoint assertion passed. Only rendering
  caught it — and only because the owner sent a screenshot.
- The colour key rendered `﴾…﴿` **mirrored**, because U+FD3E/U+FD3F are
  bidi-neutral and took the LTR sheet's direction.
- RTL padding/mirroring fixes (`3ae852d`, `54f2d48`, `f6b4ade`) are essentially
  unguarded.

This is the highest-leverage *new* layer. Proposed matrix — chrome
{`ar`, `en`, `ur`} × theme {light, dark}, over: lecture-list header, lecture
tile, book chapter list, **book reader** (a chapter exercising verse + citation +
hadith + masāʾil heading together), the colour key, player, About stats strip,
study dashboard.

Caveats, or this becomes a maintenance tax: pin goldens to **one** CI platform
(font rasterisation differs across OSes), commit the fonts, and treat
`--update-goldens` as a reviewed change, never a reflex.

### 5. Cold-start & first-frame ordering

`deea15a` is the cautionary tale: `currentSeries` resolved to the Urdu fallback
for the first frames while `_isLoading` was already `false`, so nothing waited.

| # | Test | Guards |
|---|---|---|
| 5.1 | Returning Arabic reader: correct edition on frame **one** | done (`series_provider_test`) |
| 5.2 | **No-flash**: pump exactly one frame (not `pumpAndSettle`) and assert Arabic chrome | `pumpAndSettle` hides precisely this class — it waits for the flash to finish |
| 5.3 | Fresh install, Arabic device → Arabic edition **and** Arabic chrome, picker never shown | The Middle East first-run promise. Half-covered (`series_provider_test` checks the edition, nothing checks chrome + picker together) |
| 5.4 | **`lib/app.dart`'s router graph** — 282 lines, **no test imports it**. Redirect matrix: onboarding vs `/choose-series` vs `/lectures`, deep links, `/bookmarks` | Every routing regression ships blind |

### 6. Remote-config contract tests (against the live CDN)

The app must survive content-repo mistakes; it has failed to twice already
(a malformed row killing a whole feed, `f51e6cd`). Live config *right now*
carries `publisherUrl: http://almarfa.co`, which `safe_url_launcher` refuses —
so the About "Powered by" link is **broken in production today**, and no test
noticed.

| # | Test | Guards |
|---|---|---|
| 6.1 | Live `series.json` parses; every entry declares `language`; `tawheed-ur` never sets `hasBook: true` | The `hasBook` client-default is doc-only; a manifest setting it strands older installs |
| 6.2 | Live `app_config.json` branding resolves non-empty for `en` and `ar` | The blank-label bug (caught in review, not by CI) |
| 6.3 | Every live URL is `https` (or `mailto`) per the allowlist | The live `http://` link, today |
| 6.4 | `AppConfig.contentBaseUrl` matches the manifest's `catalogUrl` hosts | ADR-0001: the base URL is **compiled in**; a CDN move needs an app release |

Run **nightly, not on PR** — network flake must not block merges.

---

## P2 — untested surfaces

Ranked by size × reachability, not by principle:

| Surface | Why it matters |
|---|---|
| `lib/screens/bookmarks_screen.dart` | **Never constructed in any test.** Live route (`app.dart:118`), reachable from the overflow menu |
| `lib/services/catalog_service.dart` | **0%.** The real catalog HTTP path — `catalog_provider_test` injects `_SpyCatalog` and bypasses it entirely. This is the same shape as the 2.3.0 outage: the pure logic was tested, the I/O wasn't |
| `lib/services/series_manifest_service.dart` | No direct test — and it just grew `cachedManifest()`, which now runs on **every** cold start |
| `lib/audio/player_notifier.dart` | 221 lines, ~50%, incidental only. The app's most stateful class |
| `lib/utils/study_session.dart` | 45 lines of pure business logic, zero tests |
| `lib/data/content_i18n_overlay.dart` | 167 lines, no test imports it |
| `lib/widgets/study/study_dashboard_card.dart` | 288 lines — the largest widget — reachable only through `study_screen_test.dart`'s 3 tests |
| `lib/services/download_notification_service.dart` | ~12%. Notification surface = user-visible |

---

## P3 — the "best UX in the industry" bar

### 7. Accessibility — **zero coverage, biggest gap against that bar**

Only **two** files in all of `lib/` even mention `Semantics`. No test uses
`meetsGuideline`, `bySemanticsLabel`, or any tap-target/contrast guideline.

| # | Test |
|---|---|
| 7.1 | `meetsGuideline(textContrastGuideline)` on every screen, **light and dark** — the brand gold on dark is the risk |
| 7.2 | `androidTapTargetGuideline` + `iOSTapTargetGuideline` — transport controls, download button, the 40×40 badges |
| 7.3 | `labeledTapTargetGuideline` — icon-only buttons (play/pause, ±10s, download, bookmark, overflow) are unlabelled today |
| 7.4 | Screen-reader pass: the seek bar must announce position/duration; `«»`/`﴾﴿` markup must not be read aloud as punctuation soup |

An audio app for a partially-sighted or elderly audience with unlabelled
transport controls is the most defensible "not industry-best" claim on this list.

### 8. Dynamic type / text scaling

No test varies `textScaler`. Nastaliq already has a tall line-box, and Urdu spells
units out (`۲۳ گھنٹے ۱۹ منٹ` vs `23h 19m`).

- 8.1 Key screens at `textScaler` 1.0 → 2.0, asserting no overflow. The About-strip
  test pins **width** at 320pt but not scale — half the risk.
- 8.2 Book reader at max scale + Nastaliq: no clipped diacritics.

### 9. Performance — zero today

- 9.1 `traceAction` on book-reader scroll (67 chapters, Nastaliq) and the
  91-lecture list; assert p90 frame budget.
- 9.2 Cold-start-to-interactive budget.

### 10. Offline/edge matrix (already strong — these are the holes)

Airplane mode **mid-download**; disk full; a corrupted partial file on resume;
clock skew vs cache TTL.

---

## Not worth doing

Stated so nobody "fixes" these later:

- **Chasing coverage %.** The gaps above are not where the number is lowest.
- **Testing generated l10n** (`app_localizations*.dart`) — regenerate, don't assert.
- **Unit-testing `theme_provider`** (11 lines) or `study_progress_label` (12).
- **Patrol in CI** — deliberately excluded, documented in the workflow header.
- **`MyApp` widget tests** — `AudioService` is a process singleton; that is why
  `LanguageProvider` holds the chrome-precedence logic instead of `app.dart`.

## CI gates — recommended changes

Today a PR into `develop` gets **only** analyze + unit/widget + debug build.
Integration runs on PRs into `master` and nightly; the Android emulator workflow
is explicitly non-blocking.

- **Add to every PR:** Book content validation (P0.1) and ARB parity (P0.2). Both
  are pure Dart, no device, ~instant.
- **Add nightly:** remote-config contract tests (P1.6).
- Leave integration on `master`/nightly. That split is sound.
