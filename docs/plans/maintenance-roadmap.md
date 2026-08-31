# At-Tawheed maintenance roadmap

Approved 2026-08-31 after returning to the project. The verified starting
point is a clean analyzer and 511 passing unit/widget tests (two intentional
skips). The work restored documentation truth, then hardened the release
harness, downloads, player behavior, accessibility, and performance evidence.
The final automated snapshot is 582 passing unit/widget tests (two intentional
skips), 16 release-tool tests, three goldens, passing Android integration and
orientation suites, Patrol at 5 pass/0 fail/1 intentional skip, and passing
three-scenario emulator performance smoke. Physical performance evidence and
process-death download resumption remain open.

## P0 — Documentation truth pass

Status: ✅ complete.

Create one canonical quality backlog and reconcile active Markdown with the
current multi-series app. Mark the offline plan shipped-with-follow-ups, retire
the stale remote-tab proposal, remove retired Home/Daily Benefit claims, and
correct test counts/current flags. Do not rewrite historical release notes.

Acceptance: active docs agree with code and link to one canonical backlog.

## P1 — Stable E2E and truthful release gate

Status: ✅ complete.

Add a centralized stable-key registry for high-value E2E controls and migrate
`AppFlow` away from localized tab labels. Separate validation integration tests
from screenshot generators. Make Patrol's Android 16 limitation explicit; a
release command must not imply that zero discovered tests are a green gate.

Acceptance: selectors survive copy/locale changes, validation and asset
generation use different commands, and Makefile/runbook/testing docs agree.

## P2 — Verified atomic audio downloads

Status: ✅ complete for transfer integrity; process-death queue persistence is
tracked separately.

Adapt the proven Al Quran download-engine shape to this smaller app: write to a
sibling `.part`, verify expected/catalog or response bytes, atomically promote,
and classify cancellation, integrity, transfer, rate-limit, and insufficient
storage failures. Preserve existing public provider behavior where possible.

Acceptance: focused tests prove partial bytes never become a completed MP3 and
typed failures reach provider state without breaking existing download flows.
Queued/chapter job persistence across process death is a separate follow-up.

## P3 — Player reliability

Status: ✅ complete.

Introduce a narrow injectable audio seam and directly cover load/resume,
buffering/error/retry/reconnect, completion, local deletion, queue boundaries,
and disposal. Keep lock-screen and in-app controls on one policy.

## P4 — Design, accessibility, and goldens

Status: ✅ complete for the delivered scope.

Document the app's existing component vocabulary, move feature-level status
colors into semantic roles, consolidate evidenced duplicates, resolve contrast,
add large-text/semantics coverage, and extend focused multi-script goldens.

## P5 — Performance and navigation policy

Status: 🟡 partial; the physical-device baseline remains open.

Cold-start measurement and centralized local series-navigation capability checks
are complete. The emulator performance smoke is automated, but a real-device
profile-mode baseline remains open. Do not move content availability into
remote feature flags.
