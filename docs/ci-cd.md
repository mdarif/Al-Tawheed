# CI/CD Pipeline — Al-Tawheed

Complete reference for the CI/CD pipeline: what's built, how to use it, what still needs doing, and the roadmap ahead.

---

## Status

| Layer | Status | File |
|---|---|---|
| CI — analyze + test + build APK | **Active** | `.github/workflows/flutter-ci.yml` |
| Local pre-push hook | **Active** | `.githooks/pre-push` |
| CD Phase 1 — Release automation | **Active** — first release (`1.0.1`) shipped 2026-06-02 | `.github/workflows/flutter-release.yml` |
| CD Phase 1.5 — Promote + sync automation | **Implemented** — not yet used for a release | `.github/workflows/flutter-release.yml` |
| CD Phase 2 — Signed release APK/AAB | **Implemented** — needs the 4 signing secrets set, then unused for a release | `.github/workflows/flutter-release.yml`, `android/app/build.gradle` |
| CD Phase 3 — Play Store internal-track upload | **Implemented** — needs the `GOOGLE_PLAY_SERVICE_ACCOUNT` secret **and** the new `PLAY_FGS_MEDIA_DECLARED` secret set | `.github/workflows/flutter-release.yml` |
| CD Phase 4 — Android emulator CI gate | **4a Implemented** (non-blocking) — 4b (required check) not started | `.github/workflows/flutter-android-emulator.yml` |
| CD Phase 5 — Seven-job release graph + on-device verify gate | **Active** — `promote → prepare → build-android → verify-android → publish → sync-develop` (+ `dry-run-summary` on dry runs) | `.github/workflows/flutter-release.yml`, `tool/compute_release_version.py`, `tool/verify_release_apk.py`, `tool/play_release_preflight.py` |

---

## Files Created

```
.github/
  workflows/
    flutter-ci.yml          ← CI: runs on every push/PR
    flutter-release.yml     ← CD: release automation (workflow_dispatch), 7-job graph
.githooks/
  pre-push                  ← Local: mirrors CI, runs before every push (now incl. format-check + test-tooling)
tool/
  compute_release_version.py    ← single source of truth for version/tag (bump, tag-collision guard)
  verify_release_apk.py         ← --inspect-only (assets/signing) and --device (install/launch/logcat) checks
  play_release_preflight.py     ← Play upload gate: PLAY_FGS_MEDIA_DECLARED + manifest checks
test/tool/
  test_compute_release_version.py   ← 16 unit tests for the version/tag logic
Makefile                    ← ci, ci-logs, release, release-dry, setup-hooks, format-check, test-tooling, verify-apk targets
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

### 5. Add CD Phase 2 signing secrets

> **Shortcut — sets all 5 secrets (this section + section 6) in one command:**
> ```sh
> make setup-release-secrets
> ```
> Reads the keystore from the Dropbox key vault, the passwords from
> `android/key.properties`, and the newest `*.json` from the "Service Account
> JSON" folder — streaming each straight to `gh secret set` (no values ever
> printed). Re-run it only on key rotation or a new machine. Override paths
> via env (`VAULT=… KEYSTORE=… make setup-release-secrets`). Just want to
> check what's set? `scripts/setup-release-secrets.sh --verify-only`.
>
> The manual per-secret commands below remain valid if you prefer them.

The release workflow now builds a **production-signed** APK + AAB, using the
same upload key as `android/key.properties`. Without these 4 repo secrets,
the "Configure release signing" step fails fast with a clear error.

Run these in your **terminal** — never paste secret values into Claude Code
chat:

```sh
# 1. Base64-encode your keystore (KEY_ALIAS is "upload" per android/key.properties)
base64 -i /path/to/upload-keystore.jks | tr -d '\n' | gh secret set KEYSTORE_BASE64 --repo mdarif/Al-Tawheed

# 2. gh prompts for each value — type it in, it's never echoed or logged
gh secret set KEY_ALIAS --repo mdarif/Al-Tawheed       # value: upload
gh secret set KEY_PASSWORD --repo mdarif/Al-Tawheed    # from android/key.properties
gh secret set STORE_PASSWORD --repo mdarif/Al-Tawheed  # from android/key.properties
```

### 6. Add CD Phase 3 Play Store secret

The release workflow now uploads `app-release.aab` to the Play Store
**internal track** automatically. This needs a Google Play service account
with Release Manager access:

1. Play Console → Setup → API access → create (or link) a Google Cloud
   service account
2. Play Console → Users and permissions → grant that service account
   **Release Manager** access to Al-Tawheed
3. Download its JSON key, then set the secret — run in your **terminal**,
   never paste the JSON in chat:

```sh
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT --repo mdarif/Al-Tawheed < /path/to/service-account.json
```

> **First-time Play Store API use?** Google requires at least one release to
> have been uploaded to a track **manually** via Play Console before the API
> can upload to it. If the workflow fails at "Upload to Play Store" with a
> "no application was found" / track-not-found style error, do one manual
> upload to the **internal** track via Play Console first, then re-run.

### 7. Add the `PLAY_FGS_MEDIA_DECLARED` secret — REQUIRED, or `publish` fails

> ⚠️ **Without this secret set, the `publish` job WILL fail.** It is not
> optional the way some of the setup above is "if you want Play upload."

The manifest declares `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`
(needed for background audio playback with lock-screen controls). Play
requires an explicit declaration form for any app requesting a foreground
service permission, and `tool/play_release_preflight.py` — a new step in the
`publish` job, run before every Play upload — refuses to upload an AAB until
it can confirm that declaration exists, so a burned `versionCode` doesn't get
wasted on a Play-side rejection.

```sh
# Normal case: the Play Console declaration form is already filled in
gh secret set PLAY_FGS_MEDIA_DECLARED --repo mdarif/Al-Tawheed <<< "true"
```

**Bootstrap escape hatch:** if Play Console isn't yet showing the foreground-
service declaration form (it only appears after Google has seen the
permission in an uploaded APK/AAB at least once), set the secret to
`bootstrap` instead of `true` for exactly one release attempt:

```sh
gh secret set PLAY_FGS_MEDIA_DECLARED --repo mdarif/Al-Tawheed <<< "bootstrap"
```

`bootstrap` lets the preflight pass with a loud `::warning::` so Play sees the
permission and surfaces the declaration form — then switch the secret back to
`true` (after actually filling in the form in Play Console) before the next
release. Any other value, or an unset secret, fails the preflight and blocks
the upload outright.

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
(`Widget Tests - Sharah Kitab at-Tawheed`) and is now included in the plain
`flutter test --reporter=expanded` run along with everything else in `test/`. There is nothing to
delete or exclude — the workflow comments referencing it as a stale template are outdated.

One consequence worth knowing: because it asserts on the literal welcome-screen title string
(`find.textContaining('Kitab at-Tawheed')`), it will break again if that copy changes — e.g. it
broke on 2026-06-07 when the title was reformatted to `'Sharah\n Kitab at-Tawheed'` (the old
assertion `'Sharah Kitab'` no longer matched because the line break moved). Fixed in
[test/widget_test.dart](../test/widget_test.dart) by matching the more stable substring
`'Kitab at-Tawheed'`.

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
▶  dart format --set-exit-if-changed
▶  python3 -m unittest discover -s test/tool
✓  All checks passed — push allowed.
```

The format-check and Python tooling-test steps were added alongside the new
`build-android` CI gates of the same name, so a push can't land unformatted
code or a broken `tool/` script that CI would catch ~20 minutes later mid-build.

If either step fails, the push is **blocked**. You fix it locally and push again. No CI minutes wasted.

### Bypassing the hook (emergency only)

```sh
git push --no-verify
```

Do not use this routinely.

---

## CD Phase 1 / 1.5 / 2 / 3 / 5 — Release Automation

**Trigger:** manual (`workflow_dispatch`), from `develop` (one-click) or `master` (traditional).

```
GitHub → Actions → Release → Run workflow
  → bump: patch | minor | major
  → confirm_promote (required when dispatched from develop)
  → dry_run (build + verify only, nothing pushed/tagged/released/uploaded)
  → skip_verify ("Emergency hotfix only" — skips the on-device APK check)
  → Run
```

Or from the terminal:

```sh
# One-click, from develop: promotes develop -> master, releases, syncs develop back
make release-auto BUMP=patch
make release-auto BUMP=patch DRY_RUN=true   # validate without shipping anything
make release-dry BUMP=patch                 # same idea, dedicated target — see below

# Traditional, from master: release only (sync-develop still runs after)
make release BUMP=patch
```

`concurrency: {group: release, cancel-in-progress: false}` is set at the
workflow level — a second dispatch queues behind an in-flight release instead
of racing or cancelling it.

### What happens — the seven-job graph

```
promote -> prepare -> build-android -> verify-android -> publish -> sync-develop
(plus dry-run-summary, which only runs on a dry run, and only if the
 build+verify jobs actually SUCCEEDED — not merely didn't fail)
```

```
promote          (skipped unless dispatched from develop)
  - Require confirm_promote=true, else fail the run
  - git merge --ff-only develop -> master, push

prepare          (needs: promote, always()+success-checked — see gotchas.md)
  - Cheap, fail-fast job: no Flutter/Gradle work yet.
  - Compute the new version + tag (tool/compute_release_version.py)
  - Guard: abort if that tag already exists
  - Verify the 4 signing secrets + GOOGLE_PLAY_SERVICE_ACCOUNT are non-empty
  - All of the above used to run AFTER a ~20-minute build; now it fails in
    seconds if something as simple as a missing secret would have doomed
    the run anyway.

build-android    (needs: promote, prepare)
  - The ONLY job holding signing secrets.
  - Java 21 + Flutter + Gradle cache, flutter pub get
  - flutter analyze --fatal-warnings   ← refuses to tag a broken build
  - flutter test                        ← refuses to tag a failing build
  - dart format --set-exit-if-changed lib test tool integration_test  ← format gate
  - python3 -m unittest discover -s test/tool  ← release-tooling gate
  - Configure release signing (decode KEYSTORE_BASE64 -> upload-keystore.jks,
    write key.properties from KEY_ALIAS/KEY_PASSWORD/STORE_PASSWORD)
  - flutter build apk --release
  - flutter build appbundle --release
  - Upload the signed APK+AAB as artifact `android-release`

verify-android   (needs: prepare, build-android) — clean runner, NO secrets
  - Skipped-checks version: if skip_verify=true, logs a ::warning:: and a
    step-summary line, and every check below is skipped. See "skip_verify"
    below for when this is legitimate.
  - Otherwise: downloads the exact signed APK from `android-release`
  - tool/verify_release_apk.py --inspect-only (asset hashes byte-for-byte,
    JSON validity, rejects a debug-signed APK)
  - Installs/launches/backgrounds/resumes it on an API 34 x86_64 emulator
    (reactivecircus/android-emulator-runner), fails on any logcat crash
  - Uploads screenshot + logcat as artifact `verify-evidence` — whether or
    not it passed, so evidence exists for failing runs too

publish          (needs: prepare, build-android, verify-android;
                   if: always() && needs.build-android.result == 'success' &&
                       needs.verify-android.result == 'success')
  - Builds NOTHING — reuses the `android-release` artifact from build-android
  - tool/play_release_preflight.py — NEW gate before the Play upload; refuses
    to upload unless PLAY_FGS_MEDIA_DECLARED is `true` (or `bootstrap` for one
    bootstrap attempt) — see One-Time Setup §7
  - Generate changelog (git-cliff --unreleased) + Play Store notes (500-char
    cap, up from 480) for THREE locales: en-US, ar, ur — all carrying the
    SAME English text, deliberately, because release notes are authored in
    English only (this is the one user-facing string set NOT covered by
    ARB parity — see gotchas.md)
  - [skipped if dry_run] Upload app-release.aab to the Play Store internal
    track (r0adkll/upload-google-play, status: completed)
  - [skipped if dry_run] Commit version bump -> master (chore: release X.Y.Z),
    tag it (X.Y.Z, no v prefix), push commit + tag
  - [skipped if dry_run] Create GitHub Release with APK + changelog attached

sync-develop     (needs: publish)
  - git merge --ff-only master -> develop, push

dry-run-summary  (only on dry_run=true; needs: prepare, build-android,
                   verify-android; if: build-android succeeded AND
                   (verify-android succeeded OR skip_verify==true))
  - Writes a step-summary confirming the dry run actually built + verified
    something, rather than just reporting a green run that skipped
    everything (see "reading a dry run" below)
```

### `skip_verify` — when it's legitimate

`skip_verify` (boolean input, default `false`, labeled "Emergency hotfix
only") skips `verify-android`'s on-device install/launch check entirely. Use
it **only** when a release is time-critical and the on-device check itself is
the blocker (e.g. emulator infra is down) — never to route around a real
failure the check found. Every use logs a `::warning::` in the run and a line
in the step summary, so it's visible after the fact who shipped without the
on-device gate.

### Reading a dry run correctly

A dry run that finishes in **under a minute with no artifacts is a FAILURE**
(a `needs:` cascade-skip through the job graph), not a pass — `needs:`
propagates skips transitively, so if an upstream job is skipped, everything
downstream skips too and the run still shows green. Always check that
`build-android` and `verify-android` actually ran and uploaded the
`android-release` / `verify-evidence` artifacts — `dry-run-summary`'s
step-summary exists specifically to make this obvious without digging through
job logs.

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
> including the local release gate (`make release-apk`), the one-click
> trigger, and the manual fallback for when `master` has genuinely diverged
> from `develop`. Follow that doc when actually cutting a release; the
> summary below is just the shape of it.

```
1. Run the local release gate (builds + tests + signed APK on a supported
   device; Patrol must discover tests):
     make release-apk DEVICE=<device_id>
2. Trigger the one-click release from develop:
     make release-auto BUMP=patch     # or BUMP=minor / BUMP=major
   CI promotes develop -> master, releases, and syncs develop back —
   no manual branch juggling needed. Watch it: gh run watch
3. Verify it shipped: new tag + GitHub Release exist
     gh release view --web
4. (Play Store only) Build the signed AAB and submit via Play Console
```

> **Looking for a record of what shipped in each release** (version history,
> changelog, what the cycle accomplished)? That's **GitHub Releases**
> (`gh release list` / `github.com/mdarif/Al-Tawheed/releases`) — the release
> workflow generates it automatically from commits and attaches the APK.
> There's no separate in-repo "release document" to maintain; this doc and
> `release-runbook.md` are purely the *how* (CI/CD mechanics and the
> execution runbook), not the *what shipped*.

---

## Makefile Reference (CI/CD targets)

| Command | What it does |
|---|---|
| `make setup-hooks` | Activate `.githooks/pre-push` for this clone |
| `make ci` | Run CI locally: format-check + tooling tests + analyze + unit/widget tests + debug APK |
| `make format-check` | `dart format --set-exit-if-changed -o none lib test tool integration_test` — mirrors the `build-android` CI gate exactly |
| `make test-tooling` | `python3 -m unittest discover -s test/tool` — mirrors the `build-android` CI gate exactly |
| `make verify-apk` | Run `tool/verify_release_apk.py` locally (`APK=` optional, defaults to the standard release path; `DEVICE=` optional for the on-device check) |
| `make integration-test DEVICE=<id>` | Run validation `integration_test/app_test.dart` on a device |
| `make screenshots DEVICE=<id>` | Generate Play Store assets (not validation) |
| `make patrol-test DEVICE=<id>` | Run Patrol 4.6.1 native tests with CLI 4.4.0; reject `Total: 0` |
| `make release-apk DEVICE=<id>` | Full gate: tests + validation integration + discovered Patrol + release APK |
| `make ci-logs` | Fetch latest failed GitHub Actions run logs via `gh` |
| `make release` | Trigger release workflow (patch bump) |
| `make release BUMP=minor` | Trigger release workflow (minor bump) |
| `make release BUMP=major` | Trigger release workflow (major bump) |
| `make release-dry BUMP=<level>` | Dispatch a dry-run release from develop (build + verify, nothing shipped) |
| `make analyze` | `flutter analyze --fatal-warnings` (matches CI) |
| `make test` | Run the CI test files with expanded reporter |

---

## Known Constraints

### Patrol version and Android 16 discovery

`pubspec.yaml` pins `patrol: ^4.6.1`, which requires `patrol_cli 4.4.0`.
Patrol CLI 4.5.1 refuses that package. On Android 16/API 36, CLI 4.4.0 can
successfully build and start instrumentation while discovering `Total: 0`
tests; the Makefile rejects that result, so it is not a release-gate pass.
Use a stock Android target below API 36 (API 34 is the recommended emulator)
for the native gate. The Flutter `integration_test/app_test.dart` validation
target remains independent, and screenshot capture remains an asset-generation
target (`make screenshots`), never part of `make release-apk`.

| Constraint | Reason | Resolution |
|---|---|---|
| `widget_test.dart` excluded | Stale Flutter template | Delete the file |
| `flutter analyze --fatal-infos` not used | Third-party packages emit uncontrollable info hints | Intentional |
| Release requires `github-actions[bot]` bypass | Branch protection blocks bot push to master | One-time setting, documented above |

---

## Roadmap

One remaining phase turns the one-click promote/release/sync flow (CD Phases
1.5, 2, and 3, implemented — see "CD Phase 1 / 1.5 / 2 / 3 — Release
Automation" above) into a fully automated production release. It removes the
last manual step from [release-runbook.md](release-runbook.md).

### CD Phase 4 — Android emulator CI gate

Removes Runbook Step 1's on-device integration/patrol test run.

- **4a (non-blocking, implemented)** — new
  `.github/workflows/flutter-android-emulator.yml`, mirroring
  `flutter-regression.yml`'s iOS-simulator pattern but using
  `reactivecircus/android-emulator-runner` (API 34, `google_apis`, `x86_64`)
  on `ubuntu-latest`. Runs `integration_test/app_test.dart`. Same triggers as
  the iOS regression workflow (PRs into master, nightly, manual dispatch).
  Failures surface in Actions but don't block anything yet.

  Patrol native tests (`patrol_test/native_test.dart`) are **not** included:
  they need `patrol_cli` plus an instrumented test build (roughly doubling
  the job's runtime) and exercise airplane mode / notification shade
  automation, which is significantly flakier on emulators than on a physical
  device. They remain part of Runbook Step 1 (`make release-apk` on a
  connected device).
- **4b (blocking)** — once stable, make it a required check for the
  `promote` job (Phase 1.5) or a required status check on `master`. At that
  point `make release-apk` on a physical device becomes optional — CI
  provides the on-device gate instead. Patrol's native scenarios would still
  need a separate plan (physical-device farm, or an emulator-based
  `patrol test` job) since 4a deliberately excludes them.

### End state — true one-click release

```sh
gh workflow run flutter-release.yml --ref develop \
  -f bump=patch -f confirm_promote=true
```

...promotes, runs analyze/unit tests, builds a signed APK + AAB, tags, creates
the GitHub Release, uploads to the Play Store internal track, and syncs
`develop`. It does not have a connected-device step: run the local
`make release-apk DEVICE=<id>` gate first (including discovered Patrol tests).
The Android emulator validation workflow is non-blocking until CD Phase 4b is
adopted. What stays manual by design: promoting internal → production in Play
Console, and reviewing the auto-generated "What's new" text.

### Future improvements

- ✅ ~~Pin Flutter version~~ — done: all 4 workflows
  (`flutter-ci.yml`, `flutter-release.yml`, `flutter-regression.yml`,
  `flutter-android-emulator.yml`) use `flutter-version: 3.41.1` instead of
  `channel: stable`. To bump, update `flutter-version` in all 4 files (and
  confirm `flutter --version` locally matches before pushing).
- Add iOS CI for `patrol_test/native_test.dart` once it's worth the runtime —
  `ios/RunnerUITests` is wired (Patrol native iOS runner), but on the iOS
  Simulator `withAirplaneMode()` short-circuits ("Control Center is not
  available on Simulator") and 3 of the 6 native tests are
  `if (!Platform.isAndroid) return`, so today this would mostly re-test
  Patrol's bootstrap + one player open/close — coverage already implied by
  `flutter-regression.yml`. Revisit if more iOS-specific native scenarios are
  added to that file.
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

*Last updated: 2026-08-31*
