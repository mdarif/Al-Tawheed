# Pipeline thinning — build, CI and release

**Status:** Revision 3 — accepted by owner 2026-10-21 (all of it lands
**before** the 2.4.2 cut; single pinned SDK = **Flutter 3.47.4**). Codex
(gpt-5.6-sol) review and recheck: both NEEDS_REVISION, all findings
incorporated below. PL1 landed as `e417270`.
**Evidence:** read-only audit (2026-10-21) of `Makefile`, `.github/workflows/`,
`tool/`, `scripts/`, `.githooks/`, and the CI/release docs. The four
release-safety findings below were re-verified by hand against the files.

## Why

The pipeline grew one fix at a time. Today local development and every
local/device gate run on Flutter 3.47.4 while CI tests and builds on 3.41.1,
so local evidence and CI evidence are about different SDKs; it can leave
`master` moved or a
Play build live without a tag when a step fails, can claim a skipped
verification as "Verified", and carries ~20 dead Makefile targets, a one-off
script in `tool/` and three overlapping descriptions of the same CI. Every `flutter`
3.47.4 command applied the SDK's one-time migrations to three tracked files
that had never been committed (they only ever ran locally, since CI stayed on
3.41.1), so every phase had to revert them by hand. PL1 fixed this.

## Verified defects (fix first)

| # | Defect | Evidence |
|---|---|---|
| D1 | Local SDK 3.47.4, CI pins 3.41.1 in six workflows: local and CI evidence come from different SDKs (CI does test and build the release on the same 3.41.1) | `flutter --version`; `flutter-version: 3.41.1` ×6 |
| D2 | Toolchain drift: 3.47.4's migrators add `analyzer.exclude` to `analysis_options.yaml` and `android.builtInKotlin=false` to `android/gradle.properties`; its `flutter_localizations` needs `intl ^0.20.3` (lock bumps) | flutter_tools `analysis_options_migration.dart`, `android/gradle.dart` DisableBuiltInKotlinMigration |
| D3 | `promote` pushes `master` before any build/test/verify gate | `flutter-release.yml:113-119` |
| D4 | Play upload (`:530`) precedes commit/tag/push (`:546-560`); a failed push leaves a live Play build with no tag or bump | same file |
| D5 | GitHub Release body always says "Verified: installed, launched…" even with `skip_verify` | `:585` |
| D6 | `build-android` format step lacks `-o none`, so it rewrites instead of checking | `:277` |

## Phases

| Phase | Work | Runner | Owns | Needs |
|---|---|---|---|---|
| PL1 | **One SDK.** Pin `environment: flutter: 3.47.4` (exact scalar — the action rejects ranges/`^`) in `pubspec.yaml`; every workflow uses `flutter-version-file: pubspec.yaml` (no literal versions); commit the migrator outputs (`analysis_options.yaml` excludes, `android.builtInKotlin=false`) and `intl: ^0.20.3` + regenerated `pubspec.lock`; record the SDK in `docs/setup.md`. | Sonnet | `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `android/gradle.properties`, the `flutter-version` lines of all six workflows, `docs/setup.md` (SDK line only), new `test/tool/test_workflows.py` | — |
| PL2 | **Safe, truthful, resumable release.** Rebuild `flutter-release.yml` as `prepare` (immutable source SHA, version, Play state) → `quality` → `build-android` → `verify-android` → `finalize-git` (ONE atomic push of master + release commit + tag). `prepare` computes the exact `new_version` once and passes it as a job output; `build-android` and `finalize-git` assert they used exactly it (never recompute from `--bump`). Resume rule: if the tag already exists, proceed only when the tag's commit has the dispatched SHA as parent, its `pubspec.yaml` version equals `new_version`, and `master` contains the tag — otherwise abort. "Re-run failed jobs" on the same run is a resume; a fresh dispatch from an already-bumped `master` is a new release → `publish-play` (re-queries Play state itself — the `prepare` snapshot may be stale; bundle assignment and track completion happen in ONE committed edit; on an API conflict it re-queries before deciding success or failure) → `github-release` (create-or-edit for the validated tag, `gh release upload --clobber` for assets; tested for absent and existing release) → `sync-develop` (no-op if `develop` already contains the tag; fast-forward with a lease only if `develop` still equals the source SHA; otherwise fail with merge instructions — never overwrite or rebase commits that landed meanwhile). No durable Git or Play release state is created before verify passes (CI artifacts and read-only Play queries are fine). `play_release_preflight.py` reports bundle-uploaded and internal-track state separately: upload if absent, assign an already-uploaded bundle to the track without re-uploading, skip if that exact version is already `completed`, abort on a conflicting used versionCode. Add a `yq --version` preflight (the action needs it). Release notes state "Device verification: SKIPPED" when skipped. Format steps `-o none`. Unify `upload-artifact`, fix stale header comments, scope `DEVELOP_SYNC_TOKEN` note. Device/golden workflows call Makefile targets instead of re-implementing them. | Sonnet | `.github/workflows/*`, `tool/play_release_preflight.py` + its tests, `test/tool/test_workflows.py`, `Makefile` `test-tooling` (pinned PyYAML) | PL1, PL3 merged |
| PL3 | **Thin Makefile + tools.** Delete dead targets (docker-build, firebase-config, docs, help-verbose, check-quality, dev-setup, pre-commit, build-all, build-web, build-android-split, run-verbose/profile/release, pub-upgrade, pub-outdated, dependencies, upgrade-flutter, open-xcode, open-android-studio, phantom `build`); merge `release`/`release-auto`/`release-dry` → `release MODE=master|develop|dry`; merge `perf-test`/`perf-smoke`; fix `build-android` debug/release ambiguity; drop "exact mirror" overclaims; pre-push hook format check includes `patrol_test/`. Move `tool/extract_book.py` to `tool/archive/` with a README line. (`tool/dispatch.py` is the owner's local, git-excluded tool — not repo content, untouched.) Update **every** reference to a removed/renamed target in the same change: `AGENTS.md`, `docs/troubleshooting.md` (`pre-commit`), `docs/performance-baseline.md` (`perf-*`), `scripts/setup-release-secrets.sh`, `docs/gotchas.md`. | Haiku | `Makefile`, `.githooks/pre-push`, `tool/extract_book.py`, the reference sites listed | P6T merged (P6T may touch `Makefile`) |
| PL4 | **One set of docs.** `docs/ci-cd.md` = how CI/CD works; `docs/release-runbook.md` = how to cut a release. Remove duplicated CI/release material from `deployment.md` and `git-workflow.md` (its CI example and v-prefixed release checklist); fix stale facts (status table, approvals, job count, Xmx, minSdk, Firebase deps, debug-APK claim). | Haiku → Opus review | `docs/ci-cd.md`, `docs/release-runbook.md`, `docs/deployment.md`, `docs/git-workflow.md`, `docs/setup.md` | PL2, PL3 merged |

Serial on shared files: P6T → PL3 (`Makefile`) → PL2 (workflows call the
final targets; PL1 must also be merged) → PL4 (docs describe the final state;
P6T's restart step in `docs/release-runbook.md` is already merged and kept).
P6D (release docs) follows PL4.

## Proof (red before green)

Workflow structure is behaviour: `test/tool/test_workflows.py` (run by
`make test-tooling`, which CI already runs) asserts, each test written first
and seen failing. PL1's checks are simple line checks (stdlib); PL2's job-graph
and step-order checks use a pinned PyYAML with a custom `SafeLoader` subclass
whose bool resolver is removed for `on`/`off`/`yes`/`no` (plain `safe_load`
turns the `on:` key into `True`), installed in every job that runs
`test-tooling`:

- no workflow contains a literal `flutter-version:`; each uses
  `flutter-version-file: pubspec.yaml`, and `pubspec.yaml` pins exactly one
  Flutter version (PL1);
- in `flutter-release.yml`, no `git push` occurs in any job that does not
  (transitively) `needs` `verify-android`; `finalize-git` pushes master and
  the tag in one atomic push; `publish-play` needs `finalize-git`; the release-notes "Verified" text is
  conditional on verification having run; every `dart format` step is a
  check (`-o none` / `--set-exit-if-changed`) (PL2);
- device and golden workflows invoke `make` targets for test runs (PL2).

Plus tests for the resume rule (tag absent / matching / wrong version /
wrong parent), `sync-develop`'s three cases, and `play_release_preflight.py`'s four Play states
(absent / bundle-only / completed / conflicting), `actionlint` on all workflows, `make format-check && make analyze &&
make test`, one Ubuntu Android build and one macOS golden smoke on CI with
the new pin, and one **dry-run release dispatch** on GitHub after PL2 — an
outward action, run only with the owner's confirmation.

## Review record

Codex `gpt-5.6-sol`, read-only, 2026-10-21 — **NEEDS_REVISION**: D1
overstated (CI tests and builds on one SDK; the real gap is local vs CI);
D2–D6 verified; PL2's retry rule missed a Play bundle-uploaded-but-not-on-track
state → resumable job graph adopted; stdlib can't robustly assert job graphs →
pinned PyYAML; PL3 must update documented references; `tool/dispatch.py` is
not repo content; P6T's runbook hunk sequenced.

Recheck (revision 2) — **NEEDS_REVISION**: resume identity too weak → exact
`new_version` stamped once, tag/parent/version/master checks; GitHub Release
idempotency undefined → create-or-edit + `--clobber`, tested; moved `develop`
undefined → no-op / leased fast-forward / safe failure; stale Play snapshot →
re-query in `publish-play`, single committed edit; PyYAML `on:` coercion →
custom loader; "nothing reaches a remote" and "two dead scripts" overclaims
corrected. All incorporated in revision 3.

## Not in scope

Changing what CI gates (no new workflows, no removal of the emulator,
regression, golden or live-contract workflows), iOS release automation,
Play track promotion beyond internal.
