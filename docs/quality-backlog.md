# Quality backlog

Canonical snapshot of maintenance work for the current multi-series app. The
phased roadmap in [maintenance-roadmap.md](plans/maintenance-roadmap.md) owns
sequencing; this page records the quality truth that active docs should use.

## Verified shipped safeguards

- **Content integrity:** both bundled book editions are checked for chapter
  continuity, numbering, non-empty content, balanced markup, citation shape,
  and Urdu ayah truncation. See `test/book_content_integrity_test.dart`.
- **Localization:** all four ARB files have matching keys and placeholders.
  See `test/arb_parity_test.dart`.
- **Remote content:** catalog, app config, feature flags, announcements, and
  the series manifest use cached stale-while-revalidate loading. A cold offline
  launch reports that content needs a connection instead of showing a spinner.
- **Offline playback:** connectivity is observable; local playback, blocked
  streaming, next-part guards, download progress, cancellation, and the Offline
  Library are implemented and covered by focused tests.
- **Navigation:** tabs come from `SeriesConfig.hasBook` and
  `SeriesConfig.hasStudyMode`; route guards enforce the same capabilities.
- **Release evidence:** the current baseline is **511 passing unit/widget
  tests**, with two intentional skips. Goldens are macOS-only and skipped by
  default; live CDN contract tests are tagged and run separately.

## Open work

| Priority | Follow-up | Owner phase |
|---|---|---|
| P1 | Stable keys for high-value E2E controls; separate validation tests from screenshot generation; document Patrol/Android 16 discovery limits; make the release gate truthful. | [P1](plans/maintenance-roadmap.md#p1--stable-e2e-and-truthful-release-gate) |
| P2 | Atomic `.part` audio downloads with integrity/transfer/cancellation failure types. | [P2](plans/maintenance-roadmap.md#p2--verified-atomic-audio-downloads) |
| P3 | Injectable player seam and direct coverage for buffering, retry, completion, queue boundaries, local deletion, and disposal. | [P3](plans/maintenance-roadmap.md#p3--player-reliability) |
| P4 | Semantic status colors, accessibility/large-text coverage, component vocabulary, and broader multi-script goldens. | [P4](plans/maintenance-roadmap.md#p4--design-accessibility-and-goldens) |
| P5 | Physical-device performance baseline, cold-start measurement, and centralized local navigation capability checks. | [P5](plans/maintenance-roadmap.md#p5--performance-and-navigation-policy) |

## Documentation rules

- Do not describe Home or Daily Benefit as a current navigation surface; the
  shell currently exposes Lectures, optional Book/Study, and Settings.
- Do not describe the offline plan as a future feature: it is shipped, with
  physical-device QA and queue persistence still open.
- Do not revive the deferred remote tab-list proposal; see
  [todo-feature-flag-navigation.md](todo-feature-flag-navigation.md).
- Historical release notes remain unchanged, even when they contain old
  counts or feature wording.
