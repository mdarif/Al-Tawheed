# Gotchas — the second brain's memory

Hard-won landmines: things that cost real time to discover, that the code alone
doesn't make obvious. **Read this before non-trivial work.** When you hit (and
resolve) something non-obvious, **add an entry here in the same change** — one
fact per entry, grouped by area, newest insight first within a group. This file
is portable memory: any LLM working the repo should read and extend it.

---

## Build & environment

- **Java 21 is required** (`android/app/build.gradle` sets `JavaVersion.VERSION_21`,
  `jvmTarget = '21'`). A build failing with `invalid source release: 21` means
  Gradle is using an older JDK.
- **`~/.gradle/gradle.properties` is global and overrides every Gradle project on
  the machine.** Another Flutter project writing `org.gradle.java.home` there can
  silently break this app's build. If Gradle picks the wrong JDK, check that file
  first, not just this repo. CI pins Java 21 explicitly, so it's a local-only trap.
- **Flutter is pinned to 3.41.1 in CI** (`.github/workflows/*.yml`). Match it
  locally when reproducing a CI-only failure.

## Testing

- **A flaky test is not always the test's fault — it can catch a real race.**
  `download_service_test.dart › "delete cancels an active download"` failed only
  on CI (passed locally) with a `PathNotFoundException`. Root cause was a genuine
  production race: deleting an actively-downloading lecture makes both `delete()`
  and `download()`'s cancel-cleanup race to remove the same partial file; the
  loser threw `PathNotFoundException` and the download future rejected with that
  instead of `DownloadCancelled`. Fix was in the app code (make both cleanup
  paths tolerate a concurrent deletion), not the test. Before re-running a flaky
  CI test, check whether it's pointing at a real concurrency bug.
- **`AudioService` is a process singleton — it can only be `init()`ed once per
  test process.** Integration tests that call `app.main()` must live in a
  **single `testWidgets`** and run scenarios sequentially. A second `testWidgets`
  that boots the app throws `_cacheManager == null: is not true`. See
  `integration_test/orientation_test.dart` (one test, five scenarios).
- **`compute()` (background isolate) breaks `pumpAndSettle`.** Moving JSON decode
  to `compute()` makes widget tests hang (`pumpAndSettle timed out`) — the test
  pump loop doesn't drive the isolate. Catalog/book JSON is decoded on the main
  isolate deliberately; payloads are small enough that isolate overhead isn't
  worth it. Don't "optimise" it back to `compute()` without re-checking the tests.
- **Orientation without native rotation:** swap `tester.view.physicalSize`
  (width↔height) to force a real relayout in integration tests — catches overflow
  / clipped widgets without flaky OS-level rotation. Pattern in
  `integration_test/orientation_test.dart`.
- **Welcome CTA is behind `IgnorePointer(ignoring: !isSeriesReady)`.** The
  `START LISTENING` text exists in the tree (opacity 0) before the series loads,
  so a single immediate `tap()` misses. Retry the tap until the widget leaves the
  tree. On first install with multiple series it routes to `/choose-series`, not
  `/lectures` — handle both. See `integration_test/support/app_flow.dart`.

## i18n & multi-series

- **Content language ≠ UI language.** The app does NOT force the locale to Arabic
  when the Arabic series is active. Use `context.l10nForSeries(series)` to get
  Arabic *chrome* for an Arabic-content series while the UI locale stays as the
  user set it. `arabicL10n` is a shared stateless `lookupAppLocalizations(Locale('ar'))`.
- **Every user-facing string must exist in all 4 ARB locales** (`en`, `ar`, `ur`,
  `ur_roman`). English-only additions are a bug. ARB wording is canonical (it won
  over shipped `_ar*` constants during the i18n cleanup).
- Not everything is an ARB duplicate: welcome taglines / native-script titles and
  the choose-series card subtitles are screen-specific branding with no ARB key —
  leave them as constants. A *new series* still needs its native title/tagline
  wired there, not via ARB.

## CI / release

- **Never inline `${{ steps.*.outputs.* }}` into a shell `run:` body when the
  value is free text** (changelogs, commit subjects). A commit subject with a
  double quote (e.g. `Localize "Now Playing" header`) closes the bash string and
  the step dies with exit 127. Pass it via the step's `env:` block instead — env
  values are not re-parsed by the shell. (Fixed in `flutter-release.yml` for both
  the Play Store notes and GitHub Release steps.)
- **Always dry-run a release first:** `make release-auto BUMP=minor DRY_RUN=true`.
  It builds + signs the AAB and runs the notes generation (not dry-run-gated) but
  publishes nothing — it caught the changelog-quoting bug above before it shipped.
- **Auto-deploy stops at the Play Store *internal* track** (`status: completed`).
  Promoting internal → production is a **manual** step in Play Console, on purpose.
- **A freshly-invited Play Store service account 403s until permission
  propagates** (`The caller does not have permission`). Setup can be correct and
  still fail on the first run made seconds after inviting it — wait minutes to ~an
  hour and re-run. `make release-auto` is idempotent (promote becomes a no-op).
- **The service account needs a Play Console *invite*, not just the JSON.** Create
  it in Google Cloud (enable "Google Play Android Developer API"), then in Play
  Console → Users and permissions → invite its email with **"Release apps to
  testing tracks"**. The old "API access → link project" page is deprecated.
- `make release-auto` must run from `develop`; `make release` from `master`. Each
  refuses the wrong branch on purpose.

## Security

- Remote-sourced URLs are launched through an https/mailto allowlist
  (`lib/utils/safe_url_launcher.dart`) — never pass a raw remote URL to
  `launchUrl`. Download ids from remote JSON are validated with
  `isSafePathSegment()` before use in file paths (path-traversal defence).
