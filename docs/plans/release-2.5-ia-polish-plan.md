# Release 2.5 — IA polish, discovery, and Settings consolidation

**Status:** Revision 3 — **accepted for execution** (2026-10-21). Codex
(gpt-5.6-sol) review NEEDS_REVISION → recheck PASS_WITH_CHANGES; all findings
from both rounds incorporated (see §Review record). Owner decisions Q1–Q5
recorded in §Owner decisions.
**Builds on:** [ia-user-journey-roadmap.md](ia-user-journey-roadmap.md) (Release A done; B1a/B1b done; B1c open)
**Mock:** Design canvas "Lecture Search & Chapter Jump" (11 boards; artboard
sources in the session scratchpad, mirrored as described in §Design below)
**Target branch:** `develop` → release via the existing release workflow

## Why

Nothing since 2.4.1 (2026-07-28) has shipped: 85 commits of Release A work
(Read tab, Library tab, durable downloads, safe edition switching) sit on
`develop`. Owner review of the running app found the Library/Read surfaces
unsatisfying (oversized hero, button-like toggle, "0 saved" vs "Bookmarks"
naming, duplicate entry points), and asked for three additions before
shipping: lecture search/chapter jump (B1c), Read options moved into
Settings (Al Quran Reader pattern), and an "Our other apps" section. This plan
ships all of it as **one release** — the Release B boundary of the IA roadmap.

## Outcomes

1. Every collection has exactly one home: Bookmarks and Downloads live only in
   Library; preferences live only in Settings; per-chapter actions stay in the
   reader. The legacy `/bookmarks` and `/offline-library` route **names** stay
   (Player and the offline sheet push them, and P0 proves Player→Back), but
   they become adapters that render the same Library widget with the matching
   tab preselected — never a separate collection screen. Active in-shell
   links (offline banner, offline sheet "Manage downloads") select
   `/library?tab=downloads` instead.
2. Library and Read share one header pattern: plain title + underline tabs.
   No hero avatar, no stats chip, no full-width button toggles.
3. A user can reach any lecture or class from Lectures in ≤2 taps without
   scrolling (Search, Jump to class).
4. Settings gains Reading (text size), About, and Our other apps; the shell
   overflow (⋮) menu is deleted.
5. One word per concept in all four locales: "Bookmarks" (not "Saved"),
   "Downloads" (not "Offline library").

## Design (mock boards)

| # | Board | Decision it encodes |
|---|---|---|
| 1 | Lectures | One new app-bar action before the bell: Search |
| 2 | Search, empty | Full-screen route pushed in the Lectures branch (nav bar stays); example query chips; **"Go to class" grid** (5 columns, part counts, finished / continue-here) when the edition has chapters |
| 3 | Search, results | Sections "Classes" (→ scroll Lectures to that chapter header) and "Lectures" (→ play + push Player); whole-token highlight; result count is a live region; "12" → 7 results incl. lecture 12 |
| 4 | No matches | Distinct from unavailable; shows edition totals; Clear / Browse classes |
| 5 | Catalogue unavailable | Offline + no cache: Retry, Open downloads in Library |
| 6 | Urdu chrome, RTL, dark | "12" matches "۱۲"; Nastaliq line-height; mirrored chevrons |
| 7 | Arabic edition | No chapters → no Classes section, no grid; ordinal words are substring matches ("الثالث" → 3, 13, 23…) |
| 8 | Read before/after | Shell ⋮ removed from Read/Study (Bookmarks dup, About, Share app relocated) |
| 9 | Settings | New **Reading** (text-size stepper + book-font preview; pinch and a reader "Aa" shortcut write the same value), **About** (About, Share app, Contact/Rate/YouTube), **Our other apps** (Android only); Downloads keeps only Wi-Fi-only |
| 10 | Library (chosen) | Title + underline tabs "Bookmarks 3 / Downloads 5"; one tap to content |
| 11 | Read | Same header as Library: "Read" + book subtitle, tabs Book / Study, Continue reading card |

### Search semantics (B1c)

- Local, in-memory over the already-loaded catalogue; no network, no index
  persistence. Catalogue sizes are 50 (Urdu) and 91 (Arabic) lectures.
- Matches **every** title field of a lecture/chapter (`en`, `ur`, `roman`,
  `ar`) regardless of UI language; results render in the UI's resolved title.
- Normalisation: case-fold; strip harakat/tatweel; unify ي/ی, ك/ک, ہ/ھ→ه
  (Urdu/Persian forms only — **Arabic ة is preserved**, it is a distinct
  letter); أ/إ/آ→ا; map ASCII, Arabic-Indic (٠-٩) and Extended Arabic-Indic
  (۰-۹) digits to one form; collapse whitespace and "—"/"-" separators.
- Tokenise the **original** string, compare normalised tokens, and highlight
  the whole original token span. Never map normalised character offsets back
  onto source text (harakat stripping shifts offsets and would split Arabic
  ligatures).
- Numeric tokens match numerically (`2` ≡ `02` ≡ `۰۲`) as whole tokens — `1`
  never matches `12`. A bare number matches chapter numbers, numbers inside
  titles, **and** the global lecture number shown on the badge. So "12" in the
  Urdu edition returns Class 12, its five parts, **and** lecture 12 (Class 05 —
  Part 01): 7 results (board 3). Qualified queries narrow it:
  "class 12"/"dars 12"/"درس ۱۲" → chapter-number only; "part 2"/"hissa 2"/
  "حصہ ۲" → part-number only.
- Non-numeric tokens are substring matches; multiple tokens AND together.
  Arabic ordinals are **substring** matches ("الثالث" hits 3, 13, 23…), not
  ordinal-to-number conversion.
- Ordering: chapter hits first, then lectures in catalogue order.
- "Go to class" contract: Search pops with the chosen chapter ID; Lectures owns
  a `ScrollController` and chapter-addressable slivers (one `SliverList` per
  chapter, or keyed headers with an index map) so it can `animateTo` a header
  that has not been built yet. The current single flat lazy `SliverList`
  ([lecture_list_screen.dart:146](../../lib/screens/lecture_list_screen.dart))
  cannot do this and is restructured in P5b.
- States: idle, results, no-results, catalogue-unavailable (offline/no cache),
  catalogue-error. "No results" must never render when the catalogue is
  missing (BLK-03 rule carried over).

### "Our other apps"

- Data hard-coded (like Al Quran Reader's `kOtherApps`), excluding this app:
  Al Quran — Read Offline (`com.almarfa.alquran`), As-Sunnah Search
  (`com.almarfa.assunnah`). Names/taglines from each app's Play listing.
- `https://play.google.com/store/apps/details?id=…` via the existing
  `safe_url_launcher` (https only); on failure, SnackBar with Copy link.
- Unlike Al Quran Reader, all strings go into all four ARB files.
- Icons: 128 px PNGs copied from Al Quran Reader's `assets/brand/other_apps/`
  (As-Sunnah) and its launcher icon (Al Quran).
- Not gated by `appLinks` (that flag is off in production and would hide it).
- Android-only links: the section is **hidden on iOS** until real App Store
  IDs exist (Q5).

## Phases

Runner policy (owner instruction): cheapest capable model. **Haiku** for
docs/inventory, **Sonnet** for test-first behaviour work, **Opus (main
session)** for integration, one review pass per phase, and merges. Each phase
runs in its own git worktree off `develop`. Every behaviour change is
red-first: the runner must show the failing test output, then green.
No runner commits; the main session reviews and commits.

| Phase | Title | Runner | Needs | Owns (exclusive) |
|---|---|---|---|---|
| P0 | Land download-button Retry+Remove and real-router legacy-route test | Opus (review/merge only) | — | `lib/widgets/download_button.dart`, `test/download_button_test.dart`, `test/shell_screen_test.dart`, `docs/quality-backlog.md` (2 bullets) — already implemented in worktree `agent-ab46f64a1dd55b49b` |
| P1 | Docs truth pass | Haiku | P0 | `AGENTS.md`, `docs/gotchas.md`, `docs/todo-feature-flag-navigation.md`, `docs/play-store-listing.md`, `docs/quality-backlog.md` (doc-rules section), `integration_test/screenshots_test.dart` (comment only) |
| P2 | Library IA (board 10) + shared tab header + legacy-route adapters | Sonnet | P0 | new `lib/widgets/section_tab_header.dart`, `lib/screens/library_screen.dart`, `lib/screens/bookmarks_screen.dart`, `lib/screens/offline_library_screen.dart`, `lib/widgets/offline_sheet.dart`, `lib/widgets/offline_status_banner.dart`, `lib/widgets/compact_toggle_chip.dart` (delete if unused), `lib/app.dart` (`/library?tab=`, adapter builders for `/bookmarks` & `/offline-library`), `lib/testing/widget_keys.dart`, ARB×4 + generated l10n, their tests incl. `test/shell_screen_test.dart` legacy-route cases |
| P3 | Read IA + remove shell ⋮ + **fix Study completion route** | Sonnet | P2 merged (`SectionTabHeader`, `app.dart` serial) | `lib/screens/read_screen.dart`, `lib/screens/study_screen.dart`, `lib/screens/book_chapter_list_screen.dart`, `lib/screens/study_class_complete_screen.dart`, `lib/widgets/app_overflow_menu.dart` (delete), `test/app_overflow_menu_test.dart` (delete), chapter-list golden + its test, `test/study_completion_navigation_test.dart`, `test/study_class_complete_screen_test.dart`, `test/study_screen_test.dart`, `lib/app.dart` (`/read?tab=study`), stale `BookChapterListScreen` mentions in provider docs. **No ARB changes.** |
| P4 | Settings: Reading, About, Our other apps, trimmed Downloads | Sonnet | P3 merged (ARB + `app.dart` serial) | `lib/screens/settings_screen.dart`, `lib/widgets/settings/*` (new `text_size_setting.dart`, `other_apps_section.dart`), new `lib/models/other_apps.dart`, `lib/providers/reading_provider.dart` (owns the 14–32 clamp + constants), `lib/screens/book_reader_screen.dart` (pinch uses provider constants; new "Aa" action), `test/book_reader_screen_test.dart`, `test/reading_provider_test.dart`, `assets/brand/other_apps/*`, `pubspec.yaml` (assets only), ARB×4 + generated l10n, `test/settings_screen_test.dart`, new tests |
| P5a | Search matcher (pure) | Sonnet | — (parallel with P2–P4; touches no shared file) | new `lib/utils/lecture_search.dart`, new `test/lecture_search_test.dart` |
| P5b | Search screen (class grid as idle state), Lectures restructure | Sonnet | P4 merged (ARB + `app.dart` serial), P5a | new `lib/screens/lecture_search_screen.dart`, new `lib/widgets/class_grid.dart`, `lib/screens/lecture_list_screen.dart` (ScrollController + chapter-addressable slivers), `lib/widgets/chapter_header.dart`, `lib/app.dart` (route), `lib/testing/widget_keys.dart`, ARB×4 + generated l10n, their tests |
| P6T | Release automation + **2.4.1 upgrade proof** | Sonnet | P5b | `integration_test/app_test.dart`, `integration_test/support/app_flow.dart`, new `integration_test/upgrade_from_2_4_1_test.dart` + fixture, `patrol_test/*` |
| P6D | Release docs + boundary review | Haiku (draft) → Opus (review) | P6T | `docs/onboarding-flows.md`, `docs/testing.md`, `docs/test-plan.md`, `docs/release-runbook.md`, roadmap status, release notes draft |
| P7 | Cut 2.4.2 | Opus, **owner-confirmed** | P6D | version bump, tag, `master` merge via existing release workflow |

Parallelism: P1, P2, P5a can run concurrently (disjoint files). Everything
that touches `lib/app.dart` or the ARB files is strictly serial:
**P2 → P3 → P4 → P5b**. Each rebases on the previous merge and regenerates
l10n, so generated `app_localizations*.dart` never conflicts.

### Phase acceptance (tests named are minimums)

- **P2:** widget tests — header has no hero/stats chip; tabs show counts;
  Downloads tab absent when `features.downloads` is off; tab state survives
  shell branch switch; empty-state copy for each tab; "Remove all downloads"
  lives in the Downloads tab with confirm; RTL + 2× text no overflow.
- **P2 (adapters):** with `createAppRouter`, `/player` → `/bookmarks` and
  `/player` → `/offline-library` render the Library widget on the right tab,
  keep `PlayerNotifier` state, and Back returns to Player; offline banner and
  offline-sheet links land on Library › Downloads.
- **P3:** **red first** — with `createAppRouter` (not a substitute router),
  finishing a Study class and tapping "Back to overview" lands on Read › Study;
  today it goes to the nonexistent `/study`. Then: no `AppOverflowMenu`
  anywhere (`find.byType` in Read/Study tests); Arabic edition shows Book with
  no tabs; Study-only edition shows Study with no tabs; `BookChapterListScreen`
  wrapper removed with its tests/golden/doc mentions (it is
  production-unreferenced).
- **P4:** `ReadingProvider` clamps 14–32 on set *and* on restore (a
  persisted out-of-range value is corrected); Settings stepper and reader pinch
  share the same constants and key (`book_font_size`); preview reflects size.
  About visible regardless of flags; Share visible with `appLinks=false,
  shareButton=true` and hidden with `shareButton=false`; Contact/Rate/YouTube
  still gated by `appLinks`; Other apps independent of `appLinks`, hidden on
  iOS (until App Store IDs exist), rows build https Play URLs, exclude this
  app's package, SnackBar + Copy link on launch failure; Downloads section has
  no Offline library / Clear rows; every new key in all 4 ARBs. Reader "Aa":
  the action opens the text-size sheet; its stepper writes the same
  `ReadingProvider` value as Settings and pinch (a change in one is visible in
  the others), persists, clamps at 14 and 32, and works in RTL and at 2× text.
- **All UI phases (a11y floor):** ≥48 dp semantic touch targets; dark glyphs
  on gold (white-on-#D4AF37 fails contrast); Nastaliq line-height 1.8–2.1 in
  every new row, chip and header; directional padding and mirrored chevrons;
  widget coverage at RTL and 2× text scale for every new surface.
- **P5a:** table-driven unit tests for each normalisation rule and every
  example in §Search semantics, incl. "12" vs "۱۲", "Hissa 2" vs "حصہ ۰۲",
  "الثالث" ordinal hits, empty/whitespace query, no false hit of "1" in "12"
  for numeric-equality mode.
- **P5b:** widget tests for all five states in LTR and RTL; Classes hit scrolls
  Lectures to the header; Lecture hit plays + pushes Player and Back returns to
  results with the query intact; idle state shows the class grid only when the
  edition has chapters (Arabic: hint text only); grid marks finished /
  in-progress from the progress provider; tapping a class scrolls Lectures to
  that header.
- **P6T:** integration rows "Search/jump", "Library tabs → play → Back",
  and "Study complete → overview"; Release A matrix re-run first. Upgrade
  proof for 2.4.1 → 2.4.2, in two parts, because `AudioService` initialises
  once per process (`integration_test/orientation_test.dart`), so a second
  `app.main()` cannot model a restart:
  1. *Migration durability (in-process):* seed 2.4.1-shaped preferences and
     download layout, construct the persistence layer and providers fresh, and
     prove edition/onboarding state, bookmarks, progress, font size, and the
     downloaded-lecture record are read correctly; tear down and rebuild the
     providers to prove a second read is identical.
  2. *Real process restart:* a separate cold-launch run (Patrol / `adb`
     force-stop + relaunch, documented as a local release-gate step given the
     known Patrol limits) proves downloaded playback after an actual restart.

## Release gate (unchanged from roadmap §Quality gates)

`make format-check && make analyze && make test`, then
`make integration-test`, `make orientation-test` on the stock emulator; Patrol
evidence stated truthfully (known API-36 limitation); release signing and
physical-device perf reported as external prerequisites, never as passes.

## Versioning

**2.4.2** (owner decision; see Q4). Both agents had recommended 2.5.0 because
of the new tab structure, new persisted state and Search; the release workflow
is run with a patch bump. The file name of this plan keeps "2.5" for history.

## Owner decisions (2026-10-21)

- **Q1 → Library option A** (board 10): title + underline tabs. The hub option is
  rejected. Read uses the same `SectionTabHeader`.
- **Q2 → Settings + reader shortcut.** Settings › Reading is canonical; the
  chapter reader gains an "Aa" app-bar action that opens a small sheet with the
  same stepper (same `ReadingProvider` value, same 14–32 clamp). P4 owns both;
  the sheet reuses `text_size_setting.dart`.
- **Q3 → One Search icon.** No separate Jump icon and no Jump sheet: the
  search screen's idle state shows the class grid (finished / continue-here
  states). The Jump sheet board is dropped; board 1 has one new icon; board 2 shows the grid.
  Arabic edition (no chapters) shows only the hint text in the idle state.
  P5b no longer creates `chapter_jump_sheet.dart`; the grid is a widget inside
  `lecture_search_screen.dart` (or `lib/widgets/class_grid.dart`).
- **Q4 → 2.4.2 (patch)**, owner's call, overriding the minor-version
  recommendation. The scope (new tabs, Search, new persisted state) is
  unchanged; the P6T 2.4.1→2.4.2 upgrade test is still mandatory.
- **Q5 → hide "Our other apps" on iOS** until real App Store IDs exist
  (default taken, owner did not object).

## Review record

Codex `gpt-5.6-sol`, read-only, 2026-10-21 — **NEEDS_REVISION** (5 High,
4 Medium). All incorporated:

| Sev | Finding | Resolution |
|---|---|---|
| High | Legacy routes still build separate collection screens; offline sheet pushes `/offline-library` | Outcome 1 + P2 adapters; P2 owns `offline_sheet.dart`, banner |
| High | "12" also matches lecture 12 → 7 results, not 6 | Explicit numeric contract + qualifiers; board 3 updated |
| High | Flat lazy `SliverList` can't scroll to an unbuilt chapter | "Go to class" contract; P5b restructures list, owns `chapter_header.dart` |
| High | P3 ownership incomplete (overflow test, golden, `app.dart`, Study completion) | P3 ownership expanded; `app.dart` serial P2→P3→P4→P5b |
| High | Study completion `context.go('/study')` — route doesn't exist in production router (verified: [study_class_complete_screen.dart:100,105](../../lib/screens/study_class_complete_screen.dart); tests use substitute routers that define `/study`) | P3 red-first fix via `/read?tab=study` |
| Med | ة/ه unification false positives; offset-based highlight unsafe | ة preserved; token-span highlighting |
| Med | Clamp private to reader; Share's `shareButton` gate untested | `ReadingProvider` owns clamp; P4 owns provider + flag-matrix tests |
| Med | Mock a11y: 36 px targets, white-on-gold, Nastaliq line-height 1, RTL root | A11y floor for all UI phases; mock corrected |
| Med | No automated 2.4.1 upgrade test | P6T upgrade fixture test |

Recheck (revision 2) — **PASS_WITH_CHANGES**: 7 of 9 resolved, 2 partial,
4 new (Medium ×3, Low ×1). Incorporated in revision 3: reader "Aa" ownership
and acceptance (`test/book_reader_screen_test.dart` added to P4); upgrade proof
split into in-process migration + real cold-launch restart, target corrected to
2.4.2; mock touch targets raised to 48 px on every active board and the Urdu
board's count corrected to ۷ (7); retired boards deleted; status/iOS wording
updated. Recheck confirmed patch versioning works: `pubspec.yaml` 2.4.1+20 →
`BUMP=patch` → 2.4.2+21 via `tool/compute_release_version.py`.

Codex's answers to Q1–Q5: tabs (A); Settings + a reader shortcut; one Search
icon with the class grid as its idle state; 2.5.0; hide Other apps on iOS.

## Risks

- Removing `/bookmarks` and `/offline-library` routes would break pushes from
  Player/offline sheet — **keep both routes** (now proven by P0's real-router
  test); only remove UI entry points that duplicate Library.
- ARB merge conflicts if serial order is ignored.
- Nastaliq line-height in the new tab header and search rows (tested at 2×).
- Search highlight on Arabic script must not split ligatures — highlight by
  whole token, not by character range, in RTL titles.
