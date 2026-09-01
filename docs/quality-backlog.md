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
- **Offline playback:** connectivity is observable; local playback, blocked
  streaming, next-part guards, download progress, cancellation, and the Offline
  Library are implemented and covered by focused tests.
- **Player reliability:** `PlayerNotifier` consumes the narrow `AudioPlayback`
  interface implemented by `TawheedAudioHandler`. Its direct tests drive real
  notifier transitions for resume boundaries, sources, buffering/reconnect,
  backend errors and retry, completion, deletion, queue policy, persistence,
  and stale callbacks without a platform audio backend.
- **Navigation:** tabs come from `SeriesConfig.hasBook` and
  `SeriesConfig.hasStudyMode`; route guards enforce the same capabilities.
- **Release evidence:** the current baseline is **582 passing unit/widget
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
- Persist and resume queued/chapter download jobs across process death; current
  download jobs are in memory only.
- Capture and review a physical-device profile-mode performance baseline;
  emulator smoke timings are not a substitute.
- Configure a local release signing store/key so the release APK gate can package
  a signed artifact; debug APK packaging is green.

| Priority | Follow-up | Owner phase |
|---|---|---|
| P1 | ✅ Complete — stable E2E keys, separated validation/screenshots, truthful Patrol discovery gate, and documented Android compatibility limits. | [P1](plans/maintenance-roadmap.md#p1--stable-e2e-and-truthful-release-gate) |
| P2 | ✅ Complete — atomic `.part` audio downloads with integrity/transfer/cancellation failure types. Process-death queue persistence remains open above. | [P2](plans/maintenance-roadmap.md#p2--verified-atomic-audio-downloads) |
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
