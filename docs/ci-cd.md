# CI/CD — Al-Tawheed

How CI and release automation work today. The procedure for cutting a release
is in [release-runbook.md](release-runbook.md); this file describes the machinery
and the one-time setup it relies on. Where this file and the workflow YAML
disagree, the YAML is right: fix this file.

---

## Flutter pin

- The SDK is pinned once, in `pubspec.yaml`:
  `environment: flutter: 3.47.4` (an exact version).
- Every workflow that sets up Flutter uses `subosito/flutter-action@v2` with
  `flutter-version-file: pubspec.yaml`. No workflow hard-codes a Flutter version.
  `test/tool/test_workflows.py` fails if one does.
- Java 21 is set up before Flutter in every job that builds Android
  (`android/app/build.gradle` requires it).
- To bump the SDK: change the pin, run `flutter pub get` locally, and commit any
  files the SDK's migrators rewrite (see [gotchas.md](gotchas.md), "Build &
  environment").

---

## Workflows

Six workflows live in `.github/workflows/`. Where a `make` target exists for a
gate, the workflow calls it. The table notes the steps that call Flutter or Python
directly.

| Workflow | Triggers | What it runs | Runner | Notes |
|---|---|---|---|---|
| `flutter-ci.yml` | push to `develop`; PRs into `develop`, `master` | `make format-check`, `make analyze`, `flutter test --coverage`, `make test-tooling` (pinned PyYAML in a venv), Codecov upload, `flutter build apk --debug`, upload `app-debug-apk` (7 days) | `ubuntu-latest` | The required `Flutter CI` check on `develop`. Runs on every push, so keep it fast. |
| `flutter-regression.yml` | PRs into `master`; manual dispatch | `make analyze`, boot an iPhone simulator, `make integration-test` on it; uploads `.xcresult` on failure | `macos-latest` | macOS minutes bill at a much higher rate than Linux, so this is not on every push. No nightly schedule (removed 2026-08-31). |
| `flutter-android-emulator.yml` | PRs into `master` or `develop` touching `lib/**`, `integration_test/**` or the workflow file; manual dispatch | `make analyze`, then `make integration-test` on an API 34 `google_apis` x86_64 emulator; uploads logcat on failure | `ubuntu-latest` (KVM) | Non-blocking: not a required check. Patrol is not run here. |
| `flutter-golden.yml` | push to `develop` and PRs into `master` touching `lib/**`, `assets/fonts/**`, `test/golden/**`, `test/flutter_test_config.dart` or the workflow file; manual dispatch | `make test-goldens`; uploads golden diffs on failure | `macos-latest` | Goldens are macOS-only. A paths filter runs them only when something that can move a pixel changed. |
| `flutter-live-contract.yml` | cron `0 3 * * *` (03:00 UTC daily); manual dispatch | `flutter test test/live_config_contract_test.dart --run-skipped` against the live CDN | `ubuntu-latest` | Cheap, and it catches a bad content deploy within a day. Not on PRs, so a CDN flake cannot block a merge. |
| `flutter-release.yml` | manual dispatch only (`workflow_dispatch`) | The release job graph below | `ubuntu-latest` | Queued, never cancelled (`concurrency: release`). |

Schedule and cost: the nightly runs of Regression, Golden and the emulator
workflow were removed on 2026-08-31 because they failed most runs and used
macOS minutes for no signal. Restore a schedule only after the failures are
fixed.

### Local equivalents

- `make ci` runs format-check, test-tooling, analyze, `flutter test`, and a
  debug APK build on this machine. It is an approximation, not the workflow: it
  does not run coverage, Codecov, or any device gate.
- `.githooks/pre-push` (activated by `make setup-hooks`) runs
  `flutter analyze --fatal-warnings`, `flutter test`, `make format-check` and
  `python3 -m unittest discover -s test/tool` before every push.

---

## Release pipeline

Dispatch (`make release` or the Actions UI) takes `bump` (patch | minor | major),
`confirm_promote`, `dry_run` and `skip_verify`.

```
prepare -> quality -> build-android -> verify-android
                                           |
   (skipped when dry_run) finalize-git -> publish-play -> github-release -> sync-develop
```

The rule: no durable state (a pushed commit, a tag, a Play release, a GitHub
Release) exists until `verify-android` has passed.

| Job | Needs | What it does | Secrets read |
|---|---|---|---|
| `prepare` | — | Checks the ref (`master`, or `develop` only with `confirm_promote=true` unless dry run). Pins the source SHA. Computes the version and tag once (`tool/compute_release_version.py`). Checks that the signing secrets and the Play service account exist, and runs the foreground-service preflight. Takes a read-only snapshot of Play. No Flutter, no Gradle. | the four signing secrets (presence only), `GOOGLE_PLAY_SERVICE_ACCOUNT`, `PLAY_FGS_MEDIA_DECLARED` |
| `quality` | prepare | `make format-check`, `make analyze`, `make test`, `make test-tooling`. None of them rewrites a file. | — |
| `build-android` | prepare, quality | The only job that decodes the keystore. Stamps the version computed by `prepare`, then `flutter build apk --release` and `flutter build appbundle --release`. Asserts the build version and records the AAB and APK SHA-256. Uploads `android-release`. | `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD` |
| `verify-android` | prepare, build-android | If `skip_verify=true`, a warning is logged and its checks are skipped. Otherwise, on a clean runner with no secrets: `tool/verify_release_apk.py --inspect-only`, then installs, launches, backgrounds and resumes the exact signed APK on an API 34 emulator. Uploads `verify-evidence` whether it passed or not. Sets `verified=true` only when the device check ran. | none |
| `finalize-git` | prepare, build-android, verify-android; not on dry run | One atomic push (`tool/release_git.py finalize`) of the release commit to `master` and the tag. When dispatched from `develop`, `develop` is promoted in the same push. Resumable: a tag that already exists is accepted only if it matches. | default `GITHUB_TOKEN` (`contents: write`) |
| `publish-play` | prepare, build-android, verify-android, finalize-git; not on dry run | Re-queries Play, then uploads, assigns, or skips. Proves Play shows the same AAB SHA-256 as `completed` on the **internal** track. Generates the changelog with `git-cliff --latest`, and the "What's new" text from it, truncated to 500 bytes (`head -c 500`). The same English text is sent for `en-US`, `ar` and `ur`. | `GOOGLE_PLAY_SERVICE_ACCOUNT` |
| `github-release` | …, publish-play; not on dry run | Creates the GitHub Release for the tag, or edits it, and replaces the APK, AAB and `play-store-notes.txt`. The body says "Device verification: PASSED" or "SKIPPED", computed from `verified`. | `GITHUB_TOKEN` (`contents: write`) |
| `sync-develop` | prepare, finalize-git, github-release; not on dry run | Fast-forwards `develop` to the release, with a lease, only if `develop` still equals the source SHA. No-op if it already contains the tag. Otherwise it fails with merge instructions and never overwrites. | `DEVELOP_SYNC_TOKEN` |
| `dry-run-summary` | prepare, quality, build-android, verify-android; dry run only | Writes a step summary that proves the dry run built and verified something. | — |

Guarantees, and where they are tested:

- The four state-changing jobs (`finalize-git`, `publish-play`,
  `github-release`, `sync-develop`) carry `if: inputs.dry_run != true`. A dry run
  cannot reach them. `test/tool/test_workflows.py` checks this structurally.
- Every job that pushes goes through `tool/release_git.py`, and that push is one
  `--atomic` call for the branch and the tag. `test/tool/test_release_git.py`
  covers it.

### Make targets that dispatch the workflow

| Command | Dispatches | Notes |
|---|---|---|
| `make release BUMP=patch` | `--ref master` | Must be run from `master`. |
| `make release MODE=develop BUMP=minor` | `--ref develop` with `confirm_promote=true` | Must be run from `develop`. Add `DRY_RUN=true` to dry-run it. |
| `make release MODE=dry BUMP=patch` | `--ref develop` with `dry_run=true` | Must be run from `develop`. Builds and verifies; ships nothing. |

For how to read a dry run, how to resume a failed run, and every failure mode,
see [release-runbook.md](release-runbook.md) (especially "Failure points and
recovery"). The short version: resume with **Re-run failed jobs** on the same
run. After `finalize-git` has pushed, never use **Re-run all jobs** (see
[gotchas.md](gotchas.md)).

### Version format

`pubspec.yaml` `version:` is `MAJOR.MINOR.PATCH+BUILD`. The release computes the
next version from the bump and tags it without a `v` prefix (for example `2.4.1`).
The Android `versionCode` comes from `+BUILD`, and `versionName` from
`MAJOR.MINOR.PATCH`.

### skip_verify

`skip_verify` skips the on-device check in `verify-android`. Use it only when the
emulator itself is down. Never use it to get past a real crash. Every use is
logged as a warning and written to the step summary.

---

## One-Time Setup

### 1. Activate the pre-push hook on every clone

```sh
make setup-hooks
```

This runs `git config core.hooksPath .githooks`. Run it once per clone.

### 2. Branch rules the workflows rely on

As recorded in the prerequisites in `flutter-release.yml`:

- `develop` requires the `Flutter CI` status check before merging.
- `master` blocks force-pushes and branch deletions. No pull request or review is
  required on either branch.
- `github-actions[bot]` must be able to push to `master` (the release commit).

Classic branch protection has no bypass-actor field, so adding a PR requirement
to `master` would break the release bot unless you move to repository rulesets.

### 3. Add the DEVELOP_SYNC_TOKEN secret

`sync-develop` pushes to protected `develop` with a fine-grained personal access
token owned by the repo admin (Contents and Workflows: write on this repo). The
default bot token is rejected by the `Flutter CI` required check. Set it in your
terminal, never in chat:

```sh
gh secret set DEVELOP_SYNC_TOKEN --repo mdarif/Al-Tawheed
```

The token expires. When `sync-develop` starts failing with a protected-branch
error, regenerate the token and update this secret.

### 4. Confirm github-actions[bot] can push to master

Settings → Branches → `master`: no rule may stop the bot's version-bump push
(see item 2).

### 5. Add CD Phase 2 signing secrets

> **Shortcut:** `make setup-release-secrets` pushes the four signing secrets and
> `GOOGLE_PLAY_SERVICE_ACCOUNT` to GitHub in one step. It reads the keystore from
> the Dropbox key vault, the passwords from `android/key.properties`, and the
> service-account JSON from its folder, and streams each value straight to
> `gh secret set` without printing it. Override paths with env vars
> (`VAULT=… KEYSTORE=… make setup-release-secrets`). To check what is set, run
> `scripts/setup-release-secrets.sh --verify-only`.

The manual commands, if you prefer them:

```sh
# 1. Base64-encode your keystore (KEY_ALIAS is "upload" per android/key.properties)
base64 -i /path/to/upload-keystore.jks | tr -d '\n' | gh secret set KEYSTORE_BASE64 --repo mdarif/Al-Tawheed

# 2. gh prompts for each value; nothing is echoed or logged
gh secret set KEY_ALIAS --repo mdarif/Al-Tawheed       # value: upload
gh secret set KEY_PASSWORD --repo mdarif/Al-Tawheed    # from android/key.properties
gh secret set STORE_PASSWORD --repo mdarif/Al-Tawheed  # from android/key.properties
```

Without these, `prepare` fails at "Require signing secrets", before any build.

### 6. Add CD Phase 3 Play Store secret

`publish-play` uploads the AAB to the Play **internal** track. It needs a Google
Play service account with release access to the app:

1. Play Console → Setup → API access: create or link a Google Cloud service
   account.
2. Play Console → Users and permissions: invite that service account and grant it
   Release Manager (or Admin) access to Al-Tawheed. Account-level access alone
   has not been enough in the past; see [gotchas.md](gotchas.md) ("CI / release").
3. Download its JSON key, then, in your terminal:

```sh
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT --repo mdarif/Al-Tawheed < /path/to/service-account.json
```

Google needs at least one release uploaded to a track manually through Play
Console before the API can publish to it. If `publish-play` fails with a "no
application was found" or track-not-found error, upload once by hand to the
internal track, then **Re-run failed jobs**.

### 7. Add the `PLAY_FGS_MEDIA_DECLARED` secret — REQUIRED, or publish fails

The app declares `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK` (lock-screen
playback). Play requires a declaration form for it. The `prepare` job's
foreground-service preflight (`tool/play_release_preflight.py manifest`) refuses
the release unless this secret is `true`, so a build number is not burned on a
Play-side rejection.

```sh
# Normal case: the Play Console declaration form is filled in
gh secret set PLAY_FGS_MEDIA_DECLARED --repo mdarif/Al-Tawheed <<< "true"
```

Bootstrap: if the form does not yet appear in Play Console (it appears only after
Google has seen the permission in an uploaded build), set the value to `bootstrap`
for exactly one attempt. The preflight then passes with a warning. Switch back to
`true` once the form is filled in. Any other value, or an unset secret, blocks the
upload.

```sh
gh secret set PLAY_FGS_MEDIA_DECLARED --repo mdarif/Al-Tawheed <<< "bootstrap"
```

### Secrets at a glance

| Secret | Read by | Purpose |
|---|---|---|
| `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD` | `prepare` (presence check), `build-android` | Release signing. `build-android` writes `key.properties` from them. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | `prepare` (snapshot), `publish-play` | Play API: read, upload, assign, verify. |
| `PLAY_FGS_MEDIA_DECLARED` | `prepare` | Foreground-service declaration gate. |
| `DEVELOP_SYNC_TOKEN` | `sync-develop` | Fast-forward `develop` past the bot's protection. |
| `GITHUB_TOKEN` (automatic) | `finalize-git`, `github-release` | Push the release commit and tag; create the release. |
| `CODECOV_TOKEN` (optional) | `flutter-ci.yml` | Coverage upload. The step does not fail if Codecov is down. |

---

## Known constraints

- **Patrol is not run by CI.** `make release-apk` runs it locally. It is a
  reported check for 2.4.2, not a release gate (owner decision). The Makefile
  still rejects a run that discovers zero tests. On Android 16 / API 36, Patrol
  4.4.0 discovers zero tests, so use an API 34 device or emulator for the native
  scenarios.
- **`flutter analyze --fatal-infos` is not used.** Third-party packages emit info
  hints the project cannot control.
- **Developer machines need PyYAML pinned to 6.0.3** for `make test-tooling` and
  the pre-push hook. See [gotchas.md](gotchas.md) ("Build & environment").

---

## Makefile reference

Output of `make help` (grouped as the Makefile prints it):

| Group | Command | What it does |
|---|---|---|
| Setup & Maintenance | `make setup` | Complete project setup (installs hooks, pub get) |
| | `make setup-hooks` | Point git at `.githooks` (pre-push); run once after clone |
| | `make setup-release-secrets` | One-time: push signing and Play Store credentials to GitHub secrets |
| | `make clean` | Clean build artifacts |
| | `make pub-get` | Get pub dependencies |
| | `make doctor` | Run `flutter doctor -v` |
| | `make devices` | List connected devices |
| | `make version` | Show project and Flutter version |
| Run | `make run` | Run app on connected device |
| | `make run-android` | Launch Android emulator and run on it |
| | `make run-ios` | Run on iOS simulator |
| Testing & Quality | `make test` | `flutter test` (unit + widget) |
| | `make test-verbose` | `flutter test` with verbose output |
| | `make test-goldens` | Verify golden (pixel) tests (macOS only) |
| | `make goldens-update` | Re-bake golden masters after a reviewed UI change |
| | `make test-tooling` | Python unittest suite in `test/tool` |
| | `make analyze` | `flutter analyze --fatal-warnings` |
| | `make lint` | `dart analyze` |
| | `make format` | `dart format .` (rewrites files) |
| | `make format-check` | `dart format --set-exit-if-changed` (no rewrite) |
| | `make coverage` | `flutter test --coverage` (report in `coverage/`) |
| | `make ci` | format-check, test-tooling, analyze, test, debug APK build |
| On-device | `make integration-test DEVICE=<id>` | Validation `integration_test/app_test.dart` on device |
| | `make orientation-test DEVICE=<id>` | Portrait/landscape flip suite on device |
| | `make patrol-test [DEVICE=<id>]` | Patrol native tests; rejects zero discovered tests |
| | `make perf DEVICE=<id> [MODE=full\|smoke]` | Frame-timing benchmarks (`full` needs a real device in profile mode) |
| | `make cold-start-test DEVICE=<id>` | Repeated Android cold-start measurement |
| | `make screenshots DEVICE=<id>` | Generate and frame Play Store assets (not validation) |
| Build & Release | `make build-android` | `flutter build apk --debug` |
| | `make build-ios` | `flutter build ios` |
| | `make release-apk DEVICE=<id>` | Local release gate: checks, integration, Patrol, release APK |
| | `make verify-apk` | Inspect a signed release APK (`APK=…`, optional `DEVICE=`) |
| | `make release` | Trigger the release workflow (`MODE=master\|develop\|dry`, `BUMP=patch\|minor\|major`, `DRY_RUN=true`) |
| | `make release-android` | `flutter build appbundle --release` (Play AAB) |
| | `make release-ios` | `flutter build ios --release` (App Store archive) |
| | `make ci-logs` | Fetch the latest failed GitHub Actions run logs |

---

## Roadmap

### CD Phase 4 — Android emulator CI gate

- **4a (implemented, non-blocking):** `flutter-android-emulator.yml` runs
  `integration_test/app_test.dart` on an API 34 emulator. It is not a required
  check.
- **4b (not started):** make that emulator job a required check. Then the
  on-device step in [release-runbook.md](release-runbook.md) Step 1 would become
  optional. Patrol's native scenarios would still need their own plan (a device
  farm, or an emulator-based `patrol test` job), because 4a leaves them out.

### Still open

- Upgrade proof on a real device: the automated half is
  `test/upgrade_from_2_4_1_test.dart`. The process-restart half is the manual
  Step 1b in [release-runbook.md](release-runbook.md).
- Physical-device performance baseline (see
  [quality-backlog.md](quality-backlog.md)).

---

*Last updated: 2026-10-21*
