# Information architecture and user-journey roadmap

**Status:** Claude Opus final PASS recheck completed on 1 September 2026
**Planning date:** 31 August 2026
**Target:** Complete IA program delivered through three independently shippable releases
**Execution manifest:** [ia-phases.yml](ia-phases.yml)
**Evidence base:** Current Flutter app, automated tests, durable project docs,
and a read-only comparison with the sibling Al Quran native app

## Outcome

Make the app feel like one coherent offline-first learning product rather than
several capable screens joined by incidental routes. A user should always know:

1. where to find and resume a lecture;
2. where their saved and downloaded content lives;
3. what changes when they switch content edition;
4. whether content is empty, unavailable, or merely not cached; and
5. how Book or Study relates to the audio, when a reliable relationship exists.

Each release is ready only when its journeys work on an Android emulator from a
clean install and after process restart, and focused unit/widget tests cover the
success and failure branches. The program is complete only after all three
release boundaries below have shipped or been explicitly re-planned.

## Product model

### Canonical navigation

```text
App shell
├── Lectures                         primary destination
│   ├── Search / chapter jump        actions, not tabs
│   ├── Continue listening
│   └── Player                       full-screen route + persistent mini-player
├── Book                             when the edition provides a book
│   └── Reader                       full-screen route
├── Study                            when the edition provides study mode
├── Library                          user-owned content, always available
│   ├── Saved
│   └── Downloads
└── Settings                         app and content-edition configuration
```

Rules:

- Lectures is always first and Settings always last.
- Library is a stable shell destination for every edition. It owns Saved and
  Downloads; those collections must not depend on Book or Study being present.
- Book and Study remain edition capabilities. Do not manufacture a tab for
  content the selected edition cannot serve.
- The current Urdu edition has both Book and Study, so it receives five
  destinations: Lectures, Book, Study, Library, Settings. Arabic receives four;
  a minimal audio-only edition receives three. Five is the accepted maximum and
  must be verified at narrow width, large text, and in RTL without truncation or
  overflow.
- Player and Reader remain immersive root routes. The mini-player remains
  visible across shell destinations while audio is active.
- Search is an action from Lectures, not another bottom-navigation tab.
- Android Back from a non-primary shell branch returns to Lectures. Back inside
  a branch pops that branch first. Branch scroll and navigation state survive
  tab changes.

### Canonical entry journeys

```text
Fresh, one available edition: Welcome → Lectures
Fresh, multiple editions:    Choose edition → one edition introduction → Lectures
Returning user:              restored edition → Lectures + Continue listening
```

There must not be two welcome/confirmation screens for one choice. “Content
edition” is the product concept; “Language” is insufficient because switching
also changes teacher, catalogue, available tabs, playback, and scoped progress.

## Scope and priorities

### Required program outcomes

| ID | Problem | Required outcome |
|---|---|---|
| BLK-01 | Shell branches lose context and Back behavior is unclear | Stateful branches preserve list/scroll state; Back returns to Lectures before exit |
| BLK-02 | Saved and downloads are hidden or reachable inconsistently | Library is a predictable shell destination for every edition |
| BLK-03 | Saved/Downloads can show “empty” when the catalogue is unavailable | Loading, empty, offline/no-cache, and error are distinct; persisted user-owned metadata remains visible |
| BLK-04 | Download actions follow different queue policies and Offline Library cannot start local playback | One request path queues consistently; downloaded rows play locally; queue state required by the travel promise survives restart |
| BLK-05 | Onboarding and edition switching can be surprising | One onboarding decision; switching is labelled, serialized, explained, and recoverable |
| BLK-06 | A saved edition missing from the remote manifest silently becomes Urdu | Preserve the saved edition identity and show retry/switch recovery; never substitute silently |
| BLK-07 | Notification permission is asked before context | Ask on first download with rationale and provide denied-permission recovery |
| BLK-08 | Critical journeys lack resilience-level automation | Core Android journeys pass locally and in the develop-PR emulator workflow |

### Discovery and continuity outcomes

| ID | Problem | Desired outcome |
|---|---|---|
| IMP-01 | A long lecture list has no focused discovery | Search lecture/chapter titles and jump to chapters, with localized no-result/error states |
| IMP-02 | Continue Listening waits before opening Player, unlike a lecture row | Every playback entry opens Player immediately and lets Player own loading/retry |
| IMP-03 | Reading continuity is unresolved | Adopt the approved resume policy and scope it by edition/book/chapter |
| IMP-04 | Invalid Book routes silently open the first chapter | Show a localized not-found state and a route back to the chapter list |
| IMP-05 | Offline status only informs | Offer a direct action to Library while offline |

### Connected-learning outcome

Book/Study-to-audio links belong to Release C, after a data-first phase. No
shipped edition currently provides a trustworthy mapping: Arabic lecture
`chapterId` values are empty, and Urdu `class-NN` study IDs do not match the
bundled book's `ch-NN` namespace. Never infer a relationship from display order
or translated title.

A data-first phase must own the catalogue schema, fixtures, CDN
publication/migration, validation, rollback, and named content owner. UI work may
begin only after production samples for every supported edition carry stable
edition + chapter/content IDs and validation rejects duplicates, missing targets,
wrong-edition IDs, and dangling references.

### Non-goals

- Copying Al Quran’s Prayer, Qibla, Tafsir, Mushaf pack, translation, Juz, or
  Page concepts.
- Adding search as a permanent tab.
- Making the bottom-tab list remotely configurable.
- Replacing the current provider/service architecture.
- Redesigning the visual system while navigation behavior is still changing.

## Decisions to close before implementation

The recommended answers below let work start without reopening the whole IA.
Any different choice should be recorded here or in an ADR before dependent code
lands.

| Gate | Decision | Status | Blocks |
|---|---|---|---|
| D1 — shell | Approve the capability-aware five-destination maximum and stateful branches | **Accepted** 2026-09-01 | A1 |
| D2 — reading resume | Resume the exact per-chapter scroll position and expose “Continue reading”; provide an explicit “start from top” action | **Accepted** 2026-09-01 | B1 |
| D3 — download durability | Persist individual and chapter queue intent across process death because offline preparation is a core promise | **Accepted** 2026-09-01 | A2 |
| D4 — content mapping | Require C1 data/schema publication with stable IDs and production validation before hand-off UI | **Accepted** 2026-09-01 | Release C |
| D5 — release boundaries | Ship only at the A, B, or C boundaries below after that boundary's full gate | **Accepted** 2026-09-01 | All releases |

Accountable Release C content owner: **Mohammad Arif** — owns catalogue review,
production sample sign-off, and rollback approval for C1's external gate.

## Delivery phases

The program is intentionally divided into independently useful release trains.
Write phases remain serial because navigation, ARB, and test-harness files
overlap:

```text
Release A — Trust and navigation
A0 → A1 → A2 → A3 → A4 → A5T → A5D → ship gate A

Release B — Discovery and continuity
B1 → B2T → B2D → ship gate B

Release C — Connected learning
C1 (schema/data/CDN) → C2 (UI) → C3T → C3D → ship gate C
```

Worktrees isolate changes and make review/rollback safe; they do not imply these
write phases can run in parallel. Cheaper background agents remain useful for
disjoint read-only audits, fixture inventories, and documentation checks.

### A0 — Contract and baseline

**Goal:** Freeze this IA contract, preserve baseline evidence, and prevent scope
drift before production edits.

**Deliverables**

- This roadmap and its executable ownership manifest.
- A baseline record from `make analyze`, `make test`, and the current Android
  integration suite before IA changes.
- Named release journeys and stable widget keys/fixtures where the current suite
  cannot express them.
- Product decisions D1–D5 recorded as accepted, changed, or deferred.
- An accountable human content owner is named for Release C catalogue review,
  publication evidence, and rollback approval.

**Exit:** Plan receives a read-only frontier review; corrections are integrated;
baseline failures, if any, are recorded rather than silently attributed to IA
work.

### A1 — Navigation foundation and Library destination

**Goal:** Make the shell predictable before changing the contents of journeys.

**Implementation**

- Migrate the shell to stateful indexed branches.
- Add Library to the local navigation policy for every edition.
- Preserve branch state and define Android Back behavior.
- Move new Saved and Downloads navigation under one Library screen. Retain the
  existing root-navigator `/bookmarks` and `/offline-library` compatibility
  routes during Release A; do not redirect or re-parent them because Player
  and Settings pushes currently rely on their root navigator semantics.
- Keep Player and Reader on the root navigator and prove the mini-player remains
  continuous across all shell branches.

**Acceptance**

- Urdu receives five ordered destinations, Arabic four, and a minimal edition
  three; each layout remains usable at narrow width, 2× text, and RTL.
- Switching tabs preserves lecture scroll position and nested Library state.
- Back pops a nested route, then returns from a non-Lectures tab to Lectures,
  then permits app exit.
- Saved and Downloads are reachable from Lectures in at most one tab switch.
- When the downloads feature is disabled, Library still owns Saved and exposes
  no dead or misleading Downloads segment.
- Capability guards still reject unavailable Book/Study routes.
- Tests cover both capability-on and capability-off branches, RTL labels,
  mini-player visibility, and repeated tab switching.
- Pushing legacy Saved/Offline routes from Player does not duplicate page keys,
  reset Player, or corrupt Back behavior. Any later redirect/re-parenting needs
  an ADR and this regression test first.

### A2 — Trustworthy Library and offline playback

**Goal:** Make user-owned content truthful and useful without a network.

**Implementation**

- Persist the minimum immutable lecture metadata needed to render saved and
  downloaded rows without a live catalogue.
- Model loading, genuine empty, offline/no-cache, stale cache, and generic error
  separately. Never derive “empty” from `catalog == null`.
- Make a downloaded row start the local source directly.
- Route every lecture/chapter download request through one queue policy.
- Persist queued work and restore or reconcile it safely after process restart.
- Keep download/remove/storage management in Library; playback stays in Player.

**Acceptance**

- Cold offline launch with valid local files shows titles and plays them.
- Bookmarks remain recognizable when the catalogue refresh fails.
- Bookmark metadata and saved state survive process restart independently of a
  successful catalogue refresh.
- Missing/corrupt local files do not appear playable and offer recovery.
- Duplicate taps do not create duplicate jobs; cancellation and retry are
  deterministic; edition switching cannot attach a job to the wrong edition.
- Tests cover success, empty, no-cache, stale cache, error, cancellation,
  restart, partial file, and local-playback branches.

### A3 — Onboarding and safe content-edition switching

**Goal:** Make edition selection one deliberate, recoverable decision.

**Implementation**

- Remove the duplicate welcome path for a fresh multi-edition install.
- Replace hard-coded chooser copy and add all new strings to all four ARB files.
- Rename the Settings concept to Content edition and preview the teacher,
  language, and capabilities that change.
- Serialize switching, show progress, and disable repeated selection.
- Explain that active playback stops and progress/download collections are
  edition-scoped.
- Treat a missing saved edition as an explicit state with Retry and Choose
  another edition; retain its saved ID until the user chooses otherwise.

**Acceptance**

- Fresh one- and multi-edition paths contain exactly one introduction/choice.
- Double taps cannot race two switches.
- Offline switch, manifest failure, removed edition, current-edition selection,
  and successful switch each have tested outcomes.
- The app never silently shows Urdu content for a missing Arabic selection.
- User-facing wording remains driven by the explicit UI locale and is never
  forked on the content edition at call sites. Layout direction may still use
  content direction where required; ADR-0002's wording rule does not prohibit
  legitimate Arabic/Urdu mirroring.

### A4 — Contextual permissions and recovery behavior

**Goal:** Close the remaining user-facing resilience gaps without mixing them
with the much larger automation/doc pass.

**Implementation**

- Move notification permission from startup to the first download action with
  localized rationale and Settings recovery after denial.
- Make the offline indicator open Library or expose an equivalent action.
- Map technical exceptions to localized recovery states; retain technical detail
  only in diagnostics.
- Add focused unit/widget coverage for granted, denied, permanently denied,
  offline, retry, feature-off, and RTL states.

**Exit:** Focused behavior tests and the normal phase gates pass. This is not
release evidence by itself.

### A5 — Release A automation, CI, documentation, and proof

**Goal:** Turn the eight Release A journey rows into a truthful, repeatable gate.

The manifest splits this into A5T (automation/CI, coding runner) and A5D
(documentation/boundary review, cheaper documentation runner) so file ownership
and review responsibility stay explicit.

**Implementation**

- Automate the eight core matrix rows below using integration tests for app
  state/routes and Patrol only where native controls are essential.
- Update the aggregate Patrol target so it discovers and runs both the native
  and Arabic-edition suites; a green command that omits one is not release
  evidence.
- Extend `make format-check` to cover `patrol_test/`.
- Trigger the Android-emulator integration workflow for pull requests into
  `develop` when app or journey-test paths change. Keep Patrol as an explicit
  local release gate because its airplane-mode/notification automation is not
  reliable enough for hosted emulators. Keep the macOS/iOS workflow manual to
  avoid the documented runner-cost regression.
- Update onboarding, testing, quality backlog, gotchas, and release docs to the
  implemented truth.

**Exit:** Release A unit/widget tests, local Android integration, local Patrol, and
the develop-PR Android emulator workflow are green with retained evidence.
Release signing and physical-device performance remain separately reported
prerequisites, not emulator passes.

### B1 — Discovery and continuity behavior

**Goal:** Let users find and resume content without scanning or waiting on an
apparently unresponsive screen.

**Implementation**

- Add focused lecture/chapter search and a chapter jump affordance from
  Lectures. Search is local over available catalogue metadata.
- Keep query, clear, loading/index-preparing, no-results, and error states
  explicit; handle Arabic and Urdu text without assuming Latin tokens.
- Make every playback entry push Player immediately, where loading/offline/error
  is rendered consistently.
- Implement the approved reading-resume policy and scope persisted positions by
  edition, book, and chapter.
- Reject stale/invalid Book routes with a localized recovery screen.

**Acceptance**

- A user can reach any chapter without traversing the full lecture list.
- Search works for representative Arabic, Urdu, Roman Urdu, and English labels;
  no-match differs from unavailable catalogue.
- Search, Library hand-off, no-result, not-found, empty, and error states are
  covered in both LTR and RTL layouts.
- Continue Listening, lecture rows, Saved, and Downloads enter the same Player
  state machine and back-stack behavior.
- Reading resume survives restart without leaking position across editions.
- Valid, stale, and empty-book routes have dedicated tests.

### B2 — Release B automation and documentation

**Goal:** Prove the Release B journeys through the real route, persistence, and
provider graph, then align durable docs.

The manifest splits this into B2T (automation) and B2D (documentation/boundary
review).

**Implementation**

- Add the Search/jump and Book route/resume rows from the journey matrix to the
  Android integration suite, including their recovery assertions.
- Add RTL emulator coverage for search results, no-results, reader not-found,
  and resume surfaces.
- Update testing, onboarding, quality backlog, gotchas, and release docs to the
  behavior shipped by B1.
- Run the complete Release A matrix before the two Release B rows; Release B
  must not regress navigation, offline, or edition switching.

**Exit:** Release A and B unit/widget coverage, local Android integration,
orientation, Patrol, and hosted develop-PR Android integration are green.

### C1 — Content identity schema and CDN publication

**Goal:** Create and publish the stable data contract required for trustworthy
Book/Study/audio relationships.

**Implementation**

- Record the content-identity decision in ADR-0003.
- Define backwards-compatible catalogue fields that map a lecture to a stable
  edition-scoped book chapter and, where applicable, study class.
- Add parser/validator tests and valid, unmapped, duplicate, dangling,
  wrong-edition, and legacy-v1 fixtures.
- Provide a repeatable validator for local fixtures and downloaded production
  catalogue samples.
- Have the named content owner prepare, review, publish, and verify the Arabic
  and Urdu CDN catalogues with a documented rollback path.
- Retain compatibility with catalogues that do not yet contain mappings; the app
  must omit cross-links rather than guess.

**External gate:** The content owner supplies reviewed production sample URLs,
validator output for every supported edition, publication timestamp/version,
and rollback confirmation. C2 cannot start from local fixtures alone.

### C2 — Connected-learning hand-offs

**Goal:** Connect Book, Study, and audio using only the verified C1 identity
contract.

**Implementation**

- Add Listen to this chapter from Book and Read/Study this chapter from the
  applicable companion surface.
- Choose the first incomplete mapped lecture, otherwise the first mapped
  lecture, and explain that choice accessibly.
- Preserve the originating reader/study context when returning from Player.
- Omit the control for legacy, missing, invalid, or feature-gated mappings.

**Acceptance**

- Mapped and unmapped branches work for Urdu, Arabic, and a minimal edition.
- Wrong-edition and dangling mappings never open unrelated content.
- Hand-off starts the correct queue and Back restores the exact originating
  chapter/session.
- Controls, errors, and absent states are covered in LTR, RTL, and at 2× text.

### C3 — Release C automation and documentation

**Goal:** Prove the complete connected-learning journey and leave schema/app/CDN
operations reproducible.

The manifest splits this into C3T (automation/live-contract proof) and C3D
(documentation/boundary review).

**Implementation**

- Add the Book/Study/audio mapping row to Android integration using verified
  mapped and intentionally unmapped fixtures.
- Add live-contract validation for published mapping fields without making CDN
  reachability part of ordinary unit tests.
- Rerun every Release A and B journey before the Release C journey.
- Update remote-content strategy, testing, quality backlog, gotchas, and release
  docs with schema compatibility, publication, monitoring, and rollback steps.

**Exit:** All A/B/C journeys and local quality gates are green, the develop-PR
Android workflow passes, production catalogue samples pass the mapping
validator, and external signing/physical-device prerequisites are reported
truthfully.

## Multi-release journey and automation matrix

Every row needs an automated success assertion and a meaningful failure/recovery
assertion. Widget tests may prove rendering details; the end-to-end column proves
that the real providers, persistence, routes, and platform channels cooperate.
Size estimates are relative automation effort: S is one deterministic app-state
scenario; M adds persistence/navigation setup; L adds multiple failure fixtures;
XL requires native controls, process restart, or cross-edition orchestration.

| Release | Journey | Size | Unit/widget proof | Android end-to-end proof |
|---|---|---:|---|---|
| A | Fresh multi-edition install | M | route guards, one-intro state machine, localized chooser | choose Arabic/Urdu → exactly one intro → correct Lectures shell |
| A | Returning user | S | persisted edition and welcome flags | relaunch → same edition, no welcome flash |
| A | Shell navigation | M | 3/4/5-destination capability matrix, branch state, Back policy | scroll Lectures → Library → Back/Lectures → scroll retained |
| A | Save a lecture | M | add/remove/idempotency, restart, empty and error states | save → relaunch → Library/Saved → play → unsave |
| A | Prepare offline | XL | queue/dedupe/cancel/restart/integrity | download → kill/relaunch → airplane mode → local playback |
| A | Cold offline/no catalogue | L | local metadata and no-cache state | retain local fixture, clear catalogue cache → Library remains truthful |
| A | Switch edition | XL | serialization, missing manifest entry, scoped state | switch while playing/downloading → warning/progress → correct shell or recovery |
| A | Notification denial | L | first-use prompt and denied/permanently-denied recovery | deny → download continues in-app → Settings recovery is reachable |
| B | Search/jump | M | multi-script normalization and state matrix | search/jump → open result → Player → Back restores result context |
| B | Book route/resume | L | valid/stale/empty IDs and scoped offsets | read/scroll → relaunch → resume; stale link → not-found recovery |
| C | Book/Study/audio mapping | L | schema validation and mapped/unmapped controls | mapped hand-off → correct audio → Back restores origin |

## Quality gates

Run at the end of every phase:

```sh
make format-check
make analyze
make test
```

`make test` includes `test/arb_parity_test.dart`, the existing executable guard
that all four ARB locales retain matching keys and placeholders.

Run on the stock Android emulator for every phase that changes navigation,
persistence, playback, permissions, or platform behavior:

```sh
make integration-test DEVICE=<id>
make orientation-test DEVICE=<id>
make patrol-test DEVICE=<id>
```

At every A, B, and C release boundary:

```sh
make ci
make perf-smoke DEVICE=<id>
```

On a machine with release signing configured, build and verify the actual
candidate on-device:

```sh
make release-apk DEVICE=<id>
make verify-apk DEVICE=<id>
```

The physical-device `make perf-test DEVICE=<id>` threshold run remains a
separate hardware gate; emulator smoke proves harness execution, not real-device
frame-time performance. Missing release signing or a physical device must be
reported as an external release prerequisite, never converted into a passing IA
check.

Release evidence must state the release boundary, device ID/API level, exact command, exit code,
passing/skipped counts, and artifact/log location. A green `make test` is the
floor: changed behavior needs focused assertions for happy, gated, empty,
offline, and error branches. No skipped test may represent a required journey.

## Dispatch and review protocol

- Execute from [ia-phases.yml](ia-phases.yml), one isolated worktree per phase.
- A runner owns production files and their tests together. Do not split tests
  away from the behavior they prove.
- Phases that share `lib/app.dart`, ARB files, or integration harnesses are
  intentionally serialized. Parallelism is reserved for disjoint read-only
  audits, fixture preparation, and review.
- Use the cheaper background runner for routine documentation/test-fixture work
  and the coding runner for behavioral changes. Every phase receives a separate
  frontier code review before merge.
- Frontier review is read-only and evidence-based. The implementing runner owns
  fixes so reviewers never create hidden file collisions.
- Merge only into `develop`, in dependency order, after the phase gates pass.
  Cut releases only at the A, B, or C boundary through the existing release
  workflow; do not tag or push to `master` from an IA worktree.

## Review record

- Repository evidence and the Al Quran transfer analysis were completed on
  31 August 2026.
- The first authenticated read-only Claude Opus review returned
  `NEEDS_REVISION`: 3 Critical, 3 High, 5 Medium, and 5 Low findings. It verified
  the underlying IA diagnosis and required a data-first mapping phase, smaller
  automation phases, truthful device/signing gates, explicit 5-destination Urdu
  coverage, and collision-safe ownership.
- This revision incorporates those findings and expands the work into complete
  Release A/B/C trains at the user's direction.
- The final authenticated read-only Claude Opus recheck completed on
  1 September 2026 and returned `PASS`. Its non-blocking notes are inputs for
  A0/boundary documentation work, not blockers to starting A0.
- The planning files intentionally remain uncommitted and unpushed at the
  user's request. The clean-tree requirement applies to completed implementation
  on `develop`, not to this pre-approval planning session.
- Decisions D1–D5 were accepted as recommended on 2026-09-01, and Mohammad Arif
  was named the accountable Release C content owner, closing the two remaining
  A0 deliverables.

## Transferable Al Quran practices

Adopted deliberately:

- persistent indexed shell branches and Back-to-primary behavior;
- exact resume surfaces for user continuity;
- search as a focused action with explicit recovery states;
- Library ownership of bookmarks/downloads;
- global audio continuity with a persistent mini-player; and
- end-to-end tests for resume, bookmarks, downloads, and search.

Rejected deliberately:

- domain-specific top-level breadth;
- a permanent search tab;
- multi-tab content-pack management without multiple content-pack types; and
- verse/Mushaf navigation semantics for lecture content.

## Definition of done

The IA work is complete when:

- the canonical navigation and entry journeys above match the shipped app;
- required outcomes BLK-01 through BLK-08 are closed with tests;
- all user-facing strings exist in all four ARB locales;
- no unavailable/failed state is presented as an empty user collection;
- local audio can be found and played after a cold offline restart;
- edition identity is never silently substituted;
- the Android journey matrix is green cumulatively through Release C with
  retained evidence;
- docs describe only current behavior and the quality backlog contains only
  genuinely open work;
- Release A, B, and C docs and operational evidence are complete; and
- `develop` contains reviewed conventional commits with no uncommitted changes.
