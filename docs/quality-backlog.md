# Quality backlog

Canonical snapshot of maintenance work for the current multi-series app. The
completed maintenance sequence remains in
[maintenance-roadmap.md](plans/maintenance-roadmap.md); the complete multi-release
information architecture program is sequenced in the
[IA user-journey roadmap](plans/ia-user-journey-roadmap.md). This page records
the quality truth that active docs should use.

## Verified shipped safeguards

- **Content integrity:** both bundled book editions are checked for chapter
  continuity, numbering, non-empty content, balanced markup, citation shape,
  and Urdu ayah truncation. See `test/book_content_integrity_test.dart`.
  The external print/ayah-pairing validator is a future reproducibility
  candidate; it is not currently scheduled.
- **Localization:** all four ARB files have matching keys and placeholders.
  See `test/arb_parity_test.dart`.
- **Remote content:** catalog, app config, feature flags, announcements, and
  the series manifest use cached stale-while-revalidate loading. A cold offline
  launch reports that content needs a connection instead of showing a spinner.
- **Offline playback:** connectivity is observable and its first real check
  is awaited (`ConnectivityProvider.ready`) before restored downloads are
  ever attempted; local playback, blocked streaming, next-part guards,
  download progress, cancellation, durable individual/chapter queue intent
  across process death, edition-switch-safe queueing, corrupt/missing-file
  recovery rows, and the Offline Library are implemented and covered by
  focused tests.
- **Player reliability:** `PlayerNotifier` consumes the narrow `AudioPlayback`
  interface implemented by `TawheedAudioHandler`. Its direct tests drive real
  notifier transitions for resume boundaries, sources, buffering/reconnect,
  backend errors and retry, completion, deletion, queue policy, persistence,
  and stale callbacks without a platform audio backend.
- **Navigation:** Lectures/Read/Library/Settings tabs come from
  `SeriesConfig.hasBook`/`hasStudyMode` (Read merges Book and Study behind
  one destination with an in-screen toggle); route guards enforce the same
  capabilities.
- **Release evidence:** the current baseline is **616 passing unit/widget
  tests**, with two intentional skips, plus **16 release-tool tests**. Three
  goldens pass. Android integration and orientation suites pass. Patrol reports
  **5 passing, 0 failing, and 1 intentional skip** on the stock Android
  emulator. The three-scenario emulator performance smoke also passes. Goldens
  remain macOS-only and skipped by default; live CDN contract tests are tagged
  and run separately.
- **Design accessibility:** secondary text now uses semantic theme roles with
  WCAG AA contrast in both themes; the book reader exposes clean line semantics
  (ornate print punctuation is visual only) and covers 2.0 text scaling. See
  [design-system.md](design-system.md), `test/app_theme_test.dart`, and
  `test/book_reader_screen_test.dart`.

## Open work

- Execute the Claude Opus PASS-reviewed IA/user-journey roadmap. It covers
  stateful navigation, a stable Library destination, truthful offline
  collections, safe edition switching, contextual notification permission,
  discovery/continuity, and data-backed Book/Study/audio hand-offs.
- Capture and review a physical-device profile-mode performance baseline;
  emulator smoke timings are not a substitute.
- B1c (deferred): lecture/chapter search and a chapter jump affordance from
  Lectures, per the roadmap's B1 "Search/jump" journey row. B1a (reading
  resume, cross-edition leak fix, stale-route recovery) and B1b (Player-entry
  consistency proof) are done; search is deliberately not scoped in detail
  yet — it's genuinely greenfield (no existing `TextEditingController`/search
  pattern anywhere in `lib/`) and touches Arabic/Urdu/Roman Urdu/English
  multi-script matching, worth iterating live with screenshots rather than
  speccing blind. Pick up as its own pass when ready.
- C1 build-side work is done: `Chapter.bookChapterId` (ADR-0003), the
  `content_mapping_validator.dart` service, and the repeatable
  `tool/validate_content_mapping.dart` CLI gate are shipped and tested,
  including the cross-edition "wrong book" case. **C1's external gate is
  still open** and is content curation, not code — Mohammad Arif (named
  Release C content owner) needs to decide the real `bookChapterId` mapping
  for every chapter in both editions, publish it to the CDN `catalog.json`,
  and validate it with the new CLI tool before C2 (the Book/Study/audio
  hand-off UI) can start.
- Configure a local release signing store/key so the release APK gate can package
  a signed artifact; debug APK packaging is green.
- A1's legacy-route regression test (`/player` → `/bookmarks`/`/offline-library`
  → Back) runs against a substitute router, not `createAppRouter`; it does not
  yet prove the production root-navigator topology preserves `PlayerNotifier`
  state. Close this with A5T's integration-harness work.
- A1's Library screen does not reset its Saved/Downloads segment on Back —
  Back always returns straight to Lectures regardless of the selected segment.
  This is a deliberate simplification (the segment is view state, not a route),
  revisit only if user feedback wants segment-aware Back.
- A2's inline download button (`download_button.dart`) only offers Retry for
  a `failed` download, no way to cancel/discard the durable queue entry —
  unlike the Library's unavailable-row UI, which offers both Retry and
  Remove. Add a cancel/delete action to the failed-state button to match.
- A3's edition switcher lacks a dedicated widget test for switching while
  offline and for a manifest-fetch failure mid-switch (catalog loading's
  existing offline/stale-cache handling is exercised elsewhere, but not from
  this specific entry point). Low priority — the underlying behavior is
  already covered by `catalog_provider_test.dart`.
- A4's notification-permission recovery has no in-app Settings deep link
  (text instructions only) and no "permanently denied" distinction —
  `flutter_local_notifications` alone can't tell denied from permanently
  denied, or open system Settings; that needs a `permission_handler`-class
  dependency this app doesn't otherwise carry. Revisit if real users report
  the manual-instructions recovery is insufficient.
- A5's local Patrol gate cannot currently produce a clean automated pass on
  either device available on this machine: the real phone (Oppo CPH2767) is
  Android 16/API 36, where Patrol 4.4.0 discovers `Total: 0` tests (a known
  CLI/API-36 incompatibility, documented in `testing.md`); the only remaining
  API 35 AVD is tablet-form (`Nexus_7` — the phone-form AVDs on this machine
  drifted to API 36, see `gotchas.md`), and its airplane-mode native
  automation is flaky enough that native/Arabic-suite runs land around 4-9 of
  11 passing rather than consistently green. `integration_test/app_test.dart`
  (the Flutter-side validation gate) is solid on both. Closing this needs
  either a working API 35 phone AVD, a Patrol CLI update that fixes API 36
  discovery, or a real device on API ≤35 — none available right now.

| Priority | Follow-up | Owner phase |
|---|---|---|
| P1 | ✅ Complete — stable E2E keys, separated validation/screenshots, truthful Patrol discovery gate, and documented Android compatibility limits. | [P1](plans/maintenance-roadmap.md#p1--stable-e2e-and-truthful-release-gate) |
| P2 | ✅ Complete — atomic `.part` audio downloads with integrity/transfer/cancellation failure types, plus durable queue persistence across process death (A2). | [P2](plans/maintenance-roadmap.md#p2--verified-atomic-audio-downloads) |
| P3 | ✅ Complete — injectable player seam and direct coverage of load, recovery, queue, deletion, persistence, and stale-callback paths. | [P3](plans/maintenance-roadmap.md#p3--player-reliability) |
| P4 | ✅ Complete for the delivered scope — semantic status colors, accessibility/large-text coverage, component vocabulary, and the initial multi-script goldens. | [P4](plans/maintenance-roadmap.md#p4--design-accessibility-and-goldens) |
| P5 | 🟡 Partial — cold-start automation and local navigation policy are complete; physical-device performance evidence remains open. | [P5](plans/maintenance-roadmap.md#p5--performance-and-navigation-policy) |

## Documentation rules

- Do not describe Home or Daily Benefit as a current navigation surface; the
  shell currently exposes Lectures, optional Book/Study, and Settings.
- Do not describe the offline plan as a future feature: it is shipped, with
  physical-device QA still open.
- Do not revive the deferred remote tab-list proposal; see
  [todo-feature-flag-navigation.md](todo-feature-flag-navigation.md).
- Historical release notes remain unchanged, even when they contain old
  counts or feature wording.
