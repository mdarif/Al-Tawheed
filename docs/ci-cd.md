# CI/CD Pipeline — Al-Tawheed

Complete reference for the CI/CD pipeline: what's built, how to use it, what still needs doing, and the roadmap ahead.

---

## Status

| Layer | Status | File |
|---|---|---|
| CI — analyze + test + build APK | **Active** | `.github/workflows/flutter-ci.yml` |
| Local pre-push hook | **Active** | `.githooks/pre-push` |
| CD Phase 1 — Release automation | **Built, pending 1 GitHub setting** | `.github/workflows/flutter-release.yml` |
| CD Phase 2 — Signed release APK | Not started | — |
| CD Phase 3 — Play Store deployment | Not started | — |

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

## Pending Action Items

These are leftover tasks from the CI/CD setup that are not yet done.

### High priority

- [ ] **Add bypass actor to master branch rule**
  Settings → Branches → master → Bypass list → `github-actions[bot]`
  Without this, `make release` will fail at the git push step.

- [ ] **Delete `test/widget_test.dart`**
  This is the unmodified Flutter counter-app template — it has no relation to this app. It is already excluded from the CI test command but should be removed to avoid confusion.
  ```sh
  git rm test/widget_test.dart
  git commit -m "chore: remove stale counter-app widget test template"
  ```

- [ ] **Stop tracking `android/local.properties`**
  This file contains machine-specific SDK paths and is now in `.gitignore`, but it was committed before the rule was added. Untrack it without deleting:
  ```sh
  git rm --cached android/local.properties
  git commit -m "chore: untrack android/local.properties (machine-specific paths)"
  ```

### Low priority

- [ ] **Set up branch protection rules** (steps 2 and 3 above)
  The CI status check only becomes available to select after the first successful run.

- [ ] **Trigger the first CI run**
  Push any commit to `develop`. This populates the `Flutter CI` status check in the branch protection dropdown.

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
Step 7   Create stub keys.dart             ← lib/utilities/keys.dart is gitignored
Step 8   flutter pub get
Step 9   flutter analyze --fatal-warnings
Step 10  flutter test (unit + widget)      ← explicit file list, excludes stale template
Step 11  flutter build apk --debug
Step 12  Upload APK artifact               ← retained 7 days, downloadable from Actions
```

### Why stub keys.dart?

`lib/utilities/keys.dart` contains the YouTube Data API key. It is gitignored so the key never reaches the repo. Without a stub, `flutter analyze` fails with `uri_does_not_exist` on `lib/services/api_service.dart`. The stub provides an empty constant that satisfies the import.

### Why specific test files?

`test/widget_test.dart` is the unmodified Flutter counter-app template. It references widgets (`find.text('0')`, `Icons.add`) that do not exist in this app. Running `flutter test` without arguments discovers it and fails. Until it is deleted, CI explicitly names only the real test files.

---

## Local Fail-Fast — Pre-Push Hook

The hook at `.githooks/pre-push` runs automatically on every `git push`. It runs the same steps as CI (minus the APK build, which is slow).

```
▶  flutter analyze --fatal-warnings
▶  flutter test test/unit_tests.dart test/widget_test_updated.dart
✓  All checks passed — push allowed.
```

If either step fails, the push is **blocked**. You fix it locally and push again. No CI minutes wasted.

The hook also handles `keys.dart` automatically: creates the stub if the real file is absent, removes it on exit.

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

```
1. Ensure develop is merged into master (open PR, get approval, merge)
2. Switch to master: git checkout master && git pull origin master
3. Trigger release:
     make release            # patch
     make release BUMP=minor # minor
4. Watch the run:
     GitHub → Actions → Release
     or: gh run watch
5. When complete: GitHub Release is created with APK attached
```

The version bump commit (`chore: release X.Y.Z`) is pushed to master automatically. Pull after the release to sync your local master:

```sh
git pull origin master --tags
```

---

## Makefile Reference (CI/CD targets)

| Command | What it does |
|---|---|
| `make setup-hooks` | Activate `.githooks/pre-push` for this clone |
| `make ci` | Run full CI locally: analyze + test + `flutter build apk --debug` |
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

### CD Phase 2 — Signed Release APK (next)

- Store keystore as a base64-encoded GitHub secret (`KEYSTORE_BASE64`)
- Store `key.properties` values as secrets (`KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`)
- Decode keystore in CI, write `android/key.properties`
- Switch release workflow from `flutter build apk --debug` to `flutter build apk --release`
- APK is properly signed and installable without enabling "install from unknown sources"

### CD Phase 3 — Play Store deployment

- Requires a Google Play service account JSON (stored as GitHub secret)
- Upload the signed AAB (`flutter build appbundle --release`) to the internal track
- Promote internal → alpha → production manually or automatically
- Tools: `gh` CLI + Google Play API, or Fastlane (when introduced)

### Future improvements

- Pin Flutter version (replace `channel: stable` with `flutter-version: 3.x.y`) for fully reproducible builds
- Add integration tests targeting a real Android emulator
- Add iOS CI once the iOS app is ready for release
- Cache invalidation strategy: clear Gradle cache on AGP/Kotlin version bumps

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

### CI fails with `uri_does_not_exist: keys.dart`

The stub creation step ran but the file wasn't created. Check that `lib/utilities/` exists in the repo (it's not excluded by `.gitignore`). The directory itself should be present even if `keys.dart` is ignored.

### Tag already exists error in release workflow

A tag for the computed version already exists. Either the version in `pubspec.yaml` was not bumped since the last release, or you are re-running a workflow that already succeeded. Choose a higher bump type or manually bump `pubspec.yaml` and push before re-triggering.

---

*Last updated: 2026-05-30*
