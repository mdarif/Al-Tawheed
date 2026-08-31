# At-Tawheed maintenance roadmap

Approved 2026-08-31 after returning to the project. The verified starting
point is a clean analyzer and 511 passing unit/widget tests (two intentional
skips). The work restores documentation truth first, then hardens the release
harness, downloads, player behavior, accessibility, and performance evidence.

## P0 — Documentation truth pass

Create one canonical quality backlog and reconcile active Markdown with the
current multi-series app. Mark the offline plan shipped-with-follow-ups, retire
the stale remote-tab proposal, remove retired Home/Daily Benefit claims, and
correct test counts/current flags. Do not rewrite historical release notes.

Acceptance: active docs agree with code and link to one canonical backlog.

## P1 — Stable E2E and truthful release gate

Add a centralized stable-key registry for high-value E2E controls and migrate
`AppFlow` away from localized tab labels. Separate validation integration tests
from screenshot generators. Make Patrol's Android 16 limitation explicit; a
release command must not imply that zero discovered tests are a green gate.

Acceptance: selectors survive copy/locale changes, validation and asset
generation use different commands, and Makefile/runbook/testing docs agree.

## P2 — Verified atomic audio downloads

Adapt the proven Al Quran download-engine shape to this smaller app: write to a
sibling `.part`, verify expected/catalog or response bytes, atomically promote,
and classify cancellation, integrity, transfer, rate-limit, and insufficient
storage failures. Preserve existing public provider behavior where possible.

Acceptance: focused tests prove partial bytes never become a completed MP3 and
typed failures reach provider state without breaking existing download flows.

## P3 — Player reliability

Introduce a narrow injectable audio seam and directly cover load/resume,
buffering/error/retry/reconnect, completion, local deletion, queue boundaries,
and disposal. Keep lock-screen and in-app controls on one policy.

## P4 — Design, accessibility, and goldens

Document the app's existing component vocabulary, move feature-level status
colors into semantic roles, consolidate evidenced duplicates, resolve contrast,
add large-text/semantics coverage, and extend focused multi-script goldens.

## P5 — Performance and navigation policy

Record a real-device baseline for the existing frame harness, add cold-start
measurement, and centralize local series-navigation capability checks. Do not
move content availability into remote feature flags.

