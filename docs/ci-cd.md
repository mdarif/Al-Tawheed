# CI/CD Pipeline — Al-Tawheed

Complete reference for the CI/CD pipeline: what's built, how to use it, what still needs doing, and the roadmap ahead.

---

## Status

| Layer | Status | File |
|---|---|---|
| CI — analyze + test + build APK | **Active** | `.github/workflows/flutter-ci.yml` |
| Local pre-push hook | **Active** | `.githooks/pre-push` |
| CD Phase 1 — Release automation | **Active** — first release (`1.0.1`) shipped 2026-06-02 | `.github/workflows/flutter-release.yml` |
| CD Phase 1.5 — Promote + sync automation | Not started | `.github/workflows/flutter-release.yml` |
| CD Phase 2 — Signed release APK/AAB | Not started | `.github/workflows/flutter-release.yml`, `android/app/build.gradle` |
| CD Phase 3 — Play Store internal-track upload | Not started | `.github/workflows/flutter-release.yml` |
| CD Phase 4 — Android emulator CI gate | Not started | new: `.github/workflows/flutter-android-emulator.yml` |

---

## Files Created

```
.github/
  workflows/
    flutter-ci.yml          ← CI: runs on every push/PR
    flutter-release.yml     ← CD: release automation (workflow_dispatch)
.githooks/
  pre-push                  ← Local: mirrors CI, runs before every push
Makefile                    ← Updated with ci, ci-logs, release, setup-hooks targets
```

---

## One-Time Setup (Do This Now)

### 1. Activate the pre-push hook on every clone

```sh
make setup-hooks
```

This runs `git config core.hooksPath .githooks`. Required once per machine after cloning. Anyone who clones the repo must run this or the hook won't fire.

### 2. Branch protection — develop

Go to: **Settings → Branches → Add rule**

| Setting | Value |
|---|---|
| Branch name pattern | `develop` |
| Require a pull request before merging | On |
| Require status checks to pass | On |
| Status check name | `Flutter CI` |
| Require branches to be up to date | On |

> `Flutter CI` only appears in the dropdown after the first successful run on develop.

### 3. Branch protection — master

Same as develop, plus:

| Setting | Value |
|---|---|
| Branch name pattern | `master` |
| Require approvals | 1 |
| Allow force pushes | Off |
| Allow deletions | Off |

### 4. Allow the release bot to push to master

The release workflow commits a version bump directly to master. Without this, step 14 of the release workflow fails.

**Settings → Branches → Edit master rule → Bypass list → Add `github-actions[bot]`**

---

## Setup Status (re-verified live 2026-06-07, post-1.0.1)

What's actually configured right now (`gh api repos/.../branches/<branch>/protection`, `gh api repos/.../rulesets`):

- ✅ `develop` requires the `Flutter CI` status check (strict — must be up to date with the base branch) before merging
- ✅ `master` blocks force-pushes and branch deletions
- ⚠️ **Neither branch requires a pull request, review, or has a bypass-actor list configured** — no repository rulesets exist either. This means a direct `git merge develop && git push origin master` succeeds with no prompts, which is why the bot's version-bump push and manual merges both go through cleanly. (An earlier version of this doc claimed a PR requirement + `github-actions[bot]` bypass list were active — that's no longer the case, whether it changed since the `1.0.1` release or was never actually enforced. Treat the live `gh api` output as the source of truth, not this doc, if you need to confirm before relying on it.)
- ✅ `android/local.properties` is untracked (`git ls-files` returns nothing for it) and remains in `.gitignore`

If you want PR review enforced on `master` going forward (e.g. before a Play Store release), re-add it via **Settings → Branches → master rule → Require a pull request before merging**, and remember the release bot will then need a bypass — Repository Rulesets (not classic branch protection) are the only mechanism with a bypass-actor field.

---

## CI Pipeline — How It Works

**Trigger:** push to `develop`, PR into `develop`, PR into `master`

**Concurrency:** cancels any in-progress run on the same branch when a new push arrives.

```
Step 1   Checkout repository
Step 2   Set up Java 21 (Temurin)          ← must come before Flutter
Step 3   Set up Flutter stable             ← also writes android/local.properties
Step 4   Cache pub packages                ← keyed on pubspec.lock
Step 5   Cache Gradle                      ← keyed on all 5 Gradle files
Step 6   Override Gradle JVM args          ← guards against -Xmx8g OOM on CI runners
Step 7   flutter pub get
Step 8   flutter analyze --fatal-warnings
Step 9   flutter test --reporter=expanded  ← runs every test/*.dart file
Step 10  flutter build apk --debug
Step 11  Upload APK artifact               ← retained 7 days, downloadable from Actions
```

> The workflow file's header comment still calls out `test/widget_test.dart` as "the stale Flutter
> counter template" that's "intentionally excluded." That's no longer true — see below — and the
> comment/TODO should be removed next time someone touches that file.

### `test/widget_test.dart` is no longer the stale counter template

It used to be the unmodified Flutter counter-app template (`find.text('0')`, `Icons.add`) and was
excluded from the test run. It has since been **rewritten** with real welcome-screen tests
(`Widget Tests - Sharah Kitab At-Tawheed`) and is now included in the plain
`flutter test --reporter=expanded` run along with everything else in `test/`. There is nothing to
delete or exclude — the workflow comments referencing it as a stale template are outdated.

One consequence worth knowing: because it asserts on the literal welcome-screen title string
(`find.textContaining('Kitab al-Tawheed')`), it will break again if that copy changes — e.g. it
broke on 2026-06-07 when the title was reformatted to `'Sharah\n Kitab al-Tawheed'` (the old
assertion `'Sharah Kitab'` no longer matched because the line break moved). Fixed in
[test/widget_test.dart](../test/widget_test.dart) by matching the more stable substring
`'Kitab al-Tawheed'`.

### `keys.dart` stub step — removed (no longer needed)

Earlier versions of this app used a YouTube Data API key via `lib/utilities/keys.dart`
(gitignored), and CI created a stub for it before `flutter analyze`. That code path was removed
during the V2 audio-app rewrite — there is no `api_service.dart` or `keys.dart` reference left
anywhere in `lib/`, the workflows, the Makefile, or the pre-push hook. `lib/utilities/` is now an
empty leftover directory and can be deleted.

---

## Local Fail-Fast — Pre-Push Hook

The hook at `.githooks/pre-push` runs automatically on every `git push`. It runs the same steps as CI (minus the APK build, which is slow).

```
▶  flutter analyze --fatal-warnings
▶  flutter test
✓  All checks passed — push allowed.
```

If either step fails, the push is **blocked**. You fix it locally and push again. No CI minutes wasted.

### Bypassing the hook (emergency only)

```sh
git push --no-verify
```

Do not use this routinely.

---

## CD Phase 1 — Release Automation

**Trigger:** manual, from master branch only.

```
GitHub → Actions → Release → Run workflow → bump: patch | minor | major → Run
```

Or from the terminal (must be on master):

```sh
make release            # patch bump (default)
make release BUMP=minor
make release BUMP=major
```

### What happens

```
Step 1   Compute new version (semver + build number from pubspec.yaml)
Step 2   Guard: abort if the tag already exists
Step 3   Update pubspec.yaml with new version
Step 4-6 Java 21 + Flutter + Gradle cache
Step 7   Override Gradle JVM args
Step 8   Create stub keys.dart
Step 9   flutter pub get
Step 10  flutter analyze --fatal-warnings   ← refuses to tag a broken build
Step 11  flutter test                        ← refuses to tag a failing build
Step 12  flutter build apk --debug
Step 13  Rename APK → al-tawheed-X.Y.Z.apk
Step 14  Generate changelog (git log since last tag, merge commits excluded)
Step 15  Commit version bump → master (chore: release X.Y.Z)
Step 16  Tag the commit (X.Y.Z, matching existing convention — no v prefix)
Step 17  Push commit + tag
Step 18  Create GitHub Release with APK attached and changelog in body
```

### Version format

`pubspec.yaml` version: `MAJOR.MINOR.PATCH+BUILD`

Example: `1.1.0+8` → patch bump → `1.1.1+9`

The Android `versionCode` and `versionName` in `build.gradle` are read from `local.properties`, which Flutter writes from `pubspec.yaml`. Bumping `pubspec.yaml` bumps both automatically.

Tag format matches existing repo tags (`1.0.0`, `1.0.1`): no `v` prefix.

### Reading CI logs without copy-pasting

```sh
make ci-logs
```

Fetches the latest failed run from GitHub Actions directly. No need to open a browser or copy-paste error output.

---

## Day-to-Day Development Workflow

```
git checkout develop
# ... make changes ...
git add <files>
git commit -m "feat: ..."
git push origin develop        ← pre-push hook fires here (analyze + test)
```

If the hook passes, open a PR: `develop → develop` (or feature branch → develop).
CI runs on the PR. Merge when green.

---

## Release Workflow

> **Full step-by-step runbook lives in `docs/release-runbook.md`** —
> including the local release gate (`make release-apk`), the push-verification
> steps that catch a `master` drift before it ships (added after the
> 2026-06-07 incident where a release shipped the wrong code because a local
> merge was never actually pushed), and post-release checks. Follow that doc
> when actually cutting a release; the summary below is just the shape of it.

```
1. Promote develop → master and PROVE the push landed
     git checkout master && git pull origin master
     git merge develop && git push origin master
     git fetch origin && git status   # must say "up to date with origin/master"
   (No PR/review is required on master — see "Setup Status" above. Don't skip
   the verification, though: an unpushed local merge is exactly what caused
   make release to ship the wrong code on 2026-06-07.)
2. Run the local release gate (builds + tests + signed APK on a real device):
     make release-apk DEVICE=<device_id>
3. Re-verify master is still up to date, then trigger the release:
     make release            # patch
     make release BUMP=minor # minor
4. Watch the run:
     GitHub → Actions → Release
     or: gh run watch
5. Verify it shipped: new tag + GitHub Release exist, then sync local master
     git pull origin master --tags
6. (Play Store only) Build the signed AAB and submit via Play Console
7. Close out: sync the version bump back into develop (don't skip — otherwise
   the next release's merge hits a pubspec.yaml version conflict):
     git checkout develop && git pull origin develop
     git merge master && git push origin develop
```

> **Looking for a record of what shipped in each release** (version history,
> changelog, what the cycle accomplished)? That's **GitHub Releases**
> (`gh release list` / `github.com/mdarif/Al-Tawheed/releases`) — the release
> workflow generates it automatically from commits (Step 14 in the table
> above) and attaches the APK. There's no separate in-repo "release document"
> to maintain; this doc and `release-runbook.md` are purely the *how* (CI/CD
> mechanics and the execution runbook), not the *what shipped*.

---

## Makefile Reference (CI/CD targets)

| Command | What it does |
|---|---|
| `make setup-hooks` | Activate `.githooks/pre-push` for this clone |
| `make ci` | Run CI locally: analyze + unit/widget tests + debug APK |
| `make integration-test DEVICE=<id>` | Run `integration_test/` on a device |
| `make patrol-test` | Run Patrol native tests (`patrol_test/native_test.dart`) |
| `make release-apk DEVICE=<id>` | Full release gate: tests + integration + patrol + release APK |
| `make ci-logs` | Fetch latest failed GitHub Actions run logs via `gh` |
| `make release` | Trigger release workflow (patch bump) |
| `make release BUMP=minor` | Trigger release workflow (minor bump) |
| `make release BUMP=major` | Trigger release workflow (major bump) |
| `make analyze` | `flutter analyze --fatal-warnings` (matches CI) |
| `make test` | Run the CI test files with expanded reporter |

---

## Known Constraints

| Constraint | Reason | Resolution |
|---|---|---|
| APK is debug-signed | No keystore secret in repo | CD Phase 2 adds production signing |
| `widget_test.dart` excluded | Stale Flutter template | Delete the file |
| `flutter analyze --fatal-infos` not used | Third-party packages emit uncontrollable info hints | Intentional |
| Release requires `github-actions[bot]` bypass | Branch protection blocks bot push to master | One-time setting, documented above |

---

## Roadmap

Four phases turn today's "one click triggers tag + GitHub Release" (CD Phase
1) into a genuinely one-click production release. Each phase removes a
specific manual step from [release-runbook.md](release-runbook.md).

### CD Phase 1.5 — Promote + sync automation (next, no new secrets)

Removes Runbook Steps 1, 3, and 6 (promote `develop` → `master`, trigger the
workflow, sync the version bump back to `develop`) by letting the workflow do
all three when dispatched from `develop`.

Restructure `flutter-release.yml` into three jobs:

- **`promote`** (`if: github.ref == 'refs/heads/develop'`) — fast-forward
  merges `develop` into `master`, pushes, and outputs the resulting SHA.
  Skipped when dispatched from `master` (today's flow keeps working
  unchanged).
- **`release`** (`needs: promote`) — today's existing logic, checking out the
  SHA `promote` produced.
- **`sync-develop`** (`needs: release`) — `git merge --ff-only master` into
  `develop` (now includes the version-bump commit + tag), then pushes.

New `workflow_dispatch` inputs:
- `confirm_promote` (boolean, default `false`) — `promote` exits early unless
  `true`, so an accidental `--ref develop` dispatch can't silently ship.
- `dry_run` (boolean, default `false`) — runs analyze/test only, skips
  push/tag/release/sync. Use this to test workflow edits safely.

Makefile: extend the `release` target to allow triggering from `develop` once
`confirm_promote=true` is wired through.

### CD Phase 2 — Signed release APK/AAB

Removes the "Step 2's locally-built APK is the only properly-signed one"
caveat from the runbook.

- New secrets — set via `gh secret set <NAME>` in your **terminal**, never
  pasted in chat: `KEYSTORE_BASE64` (the `.jks`, base64-encoded), `KEY_ALIAS`,
  `KEY_PASSWORD`, `STORE_PASSWORD` (mirrors `android/key.properties`).
- New step before "Build debug APK": decode `KEYSTORE_BASE64` to
  `android/app/upload-keystore.jks`, write `android/key.properties` from the
  other three secrets (matches `signingConfigs.release` in
  `android/app/build.gradle`).
- Switch `flutter build apk --debug` → `flutter build apk --release`, and add
  `flutter build appbundle --release` for the AAB Phase 3 needs.
- APK is properly signed and installable without enabling "install from
  unknown sources".

### CD Phase 3 — Play Store internal-track auto-upload

Removes half of Runbook Step 5 (building and uploading the AAB).

- New secret: `GOOGLE_PLAY_SERVICE_ACCOUNT` (JSON key, Release Manager access
  on the Play Console).
- New step after Phase 2's AAB build: `r0adkll/upload-google-play@v1`,
  `track: internal`, with the generated `play-store-notes.txt` as release
  notes.
- Promoting internal → production stays a **manual** step in Play Console —
  a deliberate human safety gate before the app reaches end users.

### CD Phase 4 — Android emulator CI gate

Removes Runbook Step 2's on-device integration/patrol test run.

- **4a (non-blocking)** — new `flutter-android-emulator.yml`, mirroring
  `flutter-regression.yml`'s iOS-simulator pattern but using
  `reactivecircus/android-emulator-runner` on `ubuntu-latest`. Runs
  `integration_test/app_test.dart` (+ patrol tests if portable). Same
  triggers as the iOS regression workflow (PRs into master, nightly, manual
  dispatch). Adds ~8-12 min/run; failures surface in Actions but don't block
  anything yet.
- **4b (blocking)** — once stable, make it a required check for the
  `promote` job (Phase 1.5) or a required status check on `master`. At that
  point `make release-apk` on a physical device becomes optional — CI
  provides the on-device gate instead.

### End state — true one-click release

```sh
gh workflow run flutter-release.yml --ref develop \
  -f bump=patch -f confirm_promote=true
```

...does everything: promotes, runs unit *and* on-device tests, builds a signed
APK + AAB, tags, creates the GitHub Release, uploads to the Play Store
internal track, and syncs `develop`. What stays manual by design: promoting
internal → production in Play Console, and reviewing the auto-generated
"What's new" text.

### Future improvements

- Pin Flutter version (replace `channel: stable` with `flutter-version: 3.x.y`) for fully reproducible builds
- Add iOS CI once RunnerUITests target is wired in Xcode
- Cache invalidation strategy: clear Gradle cache on AGP/Kotlin version bumps

---

## ✅ Resolved: GitHub Actions Node.js 20 deprecation

CI runs around 2026-06-07 (e.g. run `27089193259`) emitted this runner warning:

> Node.js 20 actions are deprecated. The following actions are running on Node.js 20 and may not
> work as expected: `actions/cache@v4`, `actions/checkout@v4`, `actions/setup-java@v4`. Actions will
> be forced to run with Node.js 24 by default starting **June 16th, 2026**. Node.js 20 will be
> removed from the runner on **September 16th, 2026**.

Fixed on 2026-06-08 by bumping every pinned action in both `flutter-ci.yml` and
`flutter-release.yml` to a major version that natively runs on Node 24 (verified via each repo's
own release notes — `gh release view <tag> -R <owner>/<repo>` — not just version-number guessing):

| Action | Was | Now | Why it's safe |
|---|---|---|---|
| `actions/checkout` | `@v4` | `@v6` | v6 release notes: "Update README to include Node.js 24 support details" |
| `actions/setup-java` | `@v4` | `@v5` | v5 release notes: "Breaking Changes — Upgrade to node 24" |
| `actions/cache` | `@v4` | `@v5` | v5 release notes: "runs on the Node.js 24 runtime" |
| `actions/upload-artifact` | `@v4` | `@v6` | v6 release notes: "now runs on Node.js 24 (`runs.using: node24`) by default" |
| `subosito/flutter-action` | `@v2` | unchanged | floating `@v2` tag already resolved to `v2.23.0`, which vendors `actions/cache@v5` internally — nothing to bump |

`setup-java@v5` / `cache@v5` / `upload-artifact@v6` each call out a minimum Actions Runner version
of `2.327.1` — a non-issue on GitHub-hosted `ubuntu-latest` runners (auto-updated by GitHub), only
relevant if this project ever moves to self-hosted runners.

**Verify the warning is gone** on the next CI run: `make ci-logs` or check the run summary at
`github.com/mdarif/Al-Tawheed/actions` — the "Node.js 20 actions are deprecated" banner should no
longer appear.

---

## Troubleshooting

### Pre-push hook not running

```sh
git config core.hooksPath    # should print: .githooks
make setup-hooks             # re-run if blank
```

### `flutter.sdk not set in local.properties`

This happens if Gradle is invoked directly (e.g., `./gradlew tasks`) without going through Flutter. Always use `flutter build apk` or `make build-android` — Flutter writes `local.properties` before invoking Gradle.

### Release workflow fails at "Commit, tag, and push"

The `github-actions[bot]` is not in the master branch bypass list. See the one-time setup section above.

### Tag already exists error in release workflow

A tag for the computed version already exists. Either the version in `pubspec.yaml` was not bumped since the last release, or you are re-running a workflow that already succeeded. Choose a higher bump type or manually bump `pubspec.yaml` and push before re-triggering.

---

*Last updated: 2026-06-13*
