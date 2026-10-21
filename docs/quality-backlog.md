# Quality backlog

The current quality truth for active docs: what is verified, what is still open,
and what was accepted. Completed maintenance work is in
[maintenance-roadmap.md](plans/maintenance-roadmap.md); the information
architecture program is in the [IA user-journey roadmap](plans/ia-user-journey-roadmap.md).

## Verified shipped safeguards

Current as of the 2.4.2 release candidate (2026-10-21):

- **Test suite:** `make test` gives **1780 passed, 2 skipped**. `make test-tooling`
  gives **175 tests**. Both run in `flutter-ci.yml`, and `make test` runs in the
  release `quality` job.
- **Content integrity:** both bundled book editions are checked for chapter
  continuity, numbering, non-empty content, balanced markup, citation shape and
  Urdu ayah truncation (`test/book_content_integrity_test.dart`).
- **Localization:** all four ARB files have matching keys and placeholders
  (`test/arb_parity_test.dart`).
- **Remote content:** catalog, app config, feature flags, announcements and the
  series manifest use cached stale-while-revalidate loading. A cold offline launch
  reports that content needs a connection instead of showing a spinner.
- **Offline playback:** connectivity is observable and its first real check is
  awaited before restored downloads are attempted. Local playback, blocked
  streaming, next-part guards, progress, cancellation, durable queue intent across
  process death, edition-switch-safe queueing, corrupt or missing-file recovery and
  the Offline Library are covered by focused tests.
- **Upgrade from 2.4.1, in process:** `test/upgrade_from_2_4_1_test.dart` seeds the
  2.4.1 preferences and download layout and proves they read back identically under
  the 2.4.2 providers. The real process-restart check is the owner-run Step 1b in
  [release-runbook.md](release-runbook.md).
- **Layout overflow:** `test/overflow_smoke_test.dart` renders every user-facing
  screen in all four chrome locales at text scale 1.0 and 2.0 on a 360x640 phone,
  with real Urdu and Arabic chapter titles, and fails on any `RenderFlex` overflow.
- **Player reliability:** `PlayerNotifier` consumes the narrow `AudioPlayback`
  interface. Its tests drive real transitions: resume boundaries, sources,
  buffering and reconnect, backend errors and retry, completion, deletion, queue
  policy, persistence and stale callbacks.
- **Navigation (2.4.2):** four bottom-nav tabs: Lectures, Read, Library, Settings.
  Read holds the Book and Study pages, selected through `/read?tab=` (Study completion
  goes to `Read › Study`). Library has a plain title and Bookmarks and Downloads
  tabs. Settings has Reading, About and Our other apps. The ⋮ overflow menu is gone.
  Route guards enforce the edition's capabilities.
- **Lecture search and class grid (2.4.2, B1c):** local search over lecture
  metadata with a class grid and a Go to class action, multi-script matching for
  Arabic, Urdu, Roman Urdu and English. Covered by `test/lecture_search_test.dart`,
  `test/lecture_search_screen_test.dart` and `test/class_grid_test.dart`.
- **Reader text size (2.4.2):** a text-size slider in Settings › Reading and an
  "Aa" control in the reader share one value.
- **Release tooling:** the version computation, the release commit and the atomic
  push are covered by `test/tool/`. The workflow tests check the job graph, the dry-run
  gating and the secret scoping structurally.
- **Design accessibility:** secondary text uses semantic theme roles with WCAG AA
  contrast in both themes. The book reader exposes clean line semantics and covers
  2.0 text scaling. See [design-system.md](design-system.md),
  `test/app_theme_test.dart` and `test/book_reader_screen_test.dart`.
- **Goldens:** three golden masters of the book chapter list (Urdu and Arabic
  editions, light and dark themes). They run tagged and skipped by default: in CI on macOS only
  (`flutter-golden.yml`) and locally with `make test-goldens`. They are not part of
  the release gate.
- **Patrol:** reported, not gated, for 2.4.2 (owner decision). See
  [testing.md](testing.md).

## Open work

- **Release C content mapping (owner).** The C1 build side is done
  (`Chapter.bookChapterId` per ADR-0003, the validator service, and
  `tool/validate_content_mapping.dart`). The external gate is content, not code:
  the named Release C content owner (Mohammad Arif) decides the `bookChapterId`
  mapping for every chapter in both editions, publishes it to the CDN
  `catalog.json`, and validates it with the CLI. C2 (Book, Study and audio
  hand-offs) waits on this.
- **Physical-device performance baseline.** Capture a profile-mode baseline on a
  real device (`make perf DEVICE=<id>`, `MODE=full`). Emulator smoke timings are
  not a substitute.
- **Patrol notification-shade test on API 34.** Known and non-blocking. It is
  reported, not gated, for 2.4.2.
- **Arabic and Urdu translations of new strings need a native-speaker read.** All
  new strings are in all four ARB locales, and the parity test passes, but the
  wording has not been reviewed by a native speaker.
- **iOS "Our other apps" is hidden.** The section shows only on Android today
  (`lib/widgets/settings/other_apps_section.dart`). It stays hidden on iOS until
  the App Store IDs for the listed apps exist.

- **Edition switcher test gap (A3).** No dedicated widget test for switching
  edition while offline or for a manifest-fetch failure mid-switch. Low
  priority: `catalog_provider_test.dart` covers the underlying offline and
  stale-cache handling, just not from this entry point.
- **Notification-permission recovery has no Settings deep link (A4).** Text
  instructions only, and no "permanently denied" state:
  `flutter_local_notifications` cannot tell the two apart or open system
  Settings without a `permission_handler`-class dependency. Revisit if users
  report the instructions are not enough.

### Accepted trade-offs

These are known and accepted. They are not open work.

- **Library does not reset its Bookmarks/Downloads tab on Back (A1).** The tab
  is view state, not a route, so Back always returns to Lectures. Revisit only
  if users want tab-aware Back.

- **`release_git.py assert-build` can pass vacuously.** It cross-checks
  `output-metadata.json` from AGP against the release version. If AGP moves or
  renames that file, the check finds nothing, prints a notice and passes. The
  pubspec read-back still checks the version.
- **Workflow-structure tests identify state-changing jobs by name.** The dry-run
  test uses a hard-coded list (`GATED_ON_DRY_RUN` in
  `test/tool/test_workflows.py`). A new state-changing job is not caught
  automatically. It must be added to that list.

## Priority status (maintenance roadmap)

| Priority | Follow-up | Owner phase |
|---|---|---|
| P1 | ✅ Complete: stable E2E keys, separated validation and screenshots, truthful Patrol discovery gate, documented Android compatibility limits. | [P1](plans/maintenance-roadmap.md#p1--stable-e2e-and-truthful-release-gate) |
| P2 | ✅ Complete: atomic `.part` audio downloads with integrity, transfer and cancellation failure types, and durable queue persistence across process death. | [P2](plans/maintenance-roadmap.md#p2--verified-atomic-audio-downloads) |
| P3 | ✅ Complete: injectable player seam and direct coverage of load, recovery, queue, deletion, persistence and stale-callback paths. | [P3](plans/maintenance-roadmap.md#p3--player-reliability) |
| P4 | ✅ Complete for the delivered scope: semantic status colours, accessibility and large-text coverage, component vocabulary, and the initial multi-script goldens. | [P4](plans/maintenance-roadmap.md#p4--design-accessibility-and-goldens) |
| P5 | 🟡 Partial: cold-start automation and local navigation policy are complete. Physical-device performance evidence is open (see above). | [P5](plans/maintenance-roadmap.md#p5--performance-and-navigation-policy) |

## Documentation rules

- Do not describe Home or Daily Benefit as a current navigation surface. The shell
  exposes Lectures, Read (Book and Study, when the edition has them), Library and
  Settings.
- Do not describe the offline plan as a future feature. It is shipped, with
  physical-device QA still open.
- Do not revive the deferred remote tab-list proposal; see
  [todo-feature-flag-navigation.md](todo-feature-flag-navigation.md).
- Historical release notes remain unchanged, even when they contain old counts or
  feature wording.
