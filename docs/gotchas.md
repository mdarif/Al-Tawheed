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

## Screenshots (Play Store)

- **Automated via `make screenshots DEVICE=<id>`** — `flutter drive` runs
  `integration_test/screenshots_test.dart` (reuses `AppFlow` to navigate) →
  raws → `scripts/frame_screenshots.py` (Pillow) frames them on the brand
  gradient → `docs/play-store/v3/`. iOS sim works well.
- **The two series have different chrome — capture BOTH.** The Urdu series
  renders the app UI in **English** (Now Playing, Study Mode, Settings) and has a
  Study tab; the Arabic series renders **Arabic** chrome (يُشغَّل الآن، الدروس) and
  has a Book tab instead of Study. A screenshot set must show both. The harness
  picks Arabic first (for the Arabic welcome + Book), then switches to Urdu via
  Settings → language row (`اردو`/`العربية` endonyms) to capture the English
  screens. Switching routes through the new series' welcome if unseen.
- **iOS `takeScreenshot` captures the Flutter surface only — no native status
  bar** (clean, good for framing). Android needs
  `binding.convertFlutterSurfaceToImage()` first; iOS must NOT call it.
- **Clear prefs at the start** (`SharedPreferences.getInstance().clear()` before
  `app.main()`) so onboarding (welcome + choose-series) renders — otherwise a
  persisted series selection skips straight to lectures.
- Play caps phone screenshots at **8** and **2:1 max aspect**. The iPhone raw is
  ~2.17:1, so the framer composites onto a 2:1 canvas (1290×2580).

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

- **The one-click release job runs in detached HEAD — push with `HEAD:master`,
  not `master`.** When dispatched from `develop`, the `release` job checks out
  the promote SHA (`ref: needs.promote.outputs.sha`), so there is no local
  `master` branch. `git push origin master` fails with `src refspec master does
  not match any`; use `git push origin HEAD:master`. (Latent until the first
  release that actually reached the commit/tag/push step.)
- **`github-actions[bot]` must be on BOTH branches' bypass lists.** The
  `sync-develop` job fast-forwards `develop` to `master` and pushes, but
  `develop`'s protection ("Flutter CI" required status check) rejects the bot's
  push (`GH006: Protected branch update failed`) unless the bot is in develop's
  bypass list — same requirement already documented for `master`. Until added,
  the release ships fine but `sync-develop` fails; recover by fast-forwarding
  develop to master by hand (admin push bypasses protection):
  `git checkout develop && git merge --ff-only origin/master && git push origin develop`.
- **A consumed versionCode can't be reused.** If a release uploads the AAB to
  Play (versionCode N) but then fails *after* the upload (e.g. the push bug
  above), N is burned. A naive re-run recomputes the same N and the upload is
  rejected with "Version code N has already been used". Bump `pubspec.yaml`'s
  `+BUILD` so the compute step produces N+1 before re-running.
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
  Console → Users and permissions → invite its email. The old "API access → link
  project" page is deprecated — inviting the SA email *is* the link.
- **Account-level permission was NOT enough — grant it at the APP level with
  "Manage testing tracks".** This is what finally cleared the persistent
  `403 The caller does not have permission` (after account-level "Release apps to
  testing tracks" kept failing across several runs). Fix: Users and permissions →
  the SA → **Manage → App permissions tab → Add app → com.almarfa.tawheed**, then
  enable **Release apps to testing tracks** *and* **Manage testing tracks and edit
  tester lists** → Apply. Distinguish this from pure propagation delay: if
  account-level looks correct and it still 403s after ~30 min, it's the missing
  app-level grant, not time.
- `make release-auto` must run from `develop`; `make release` from `master`. Each
  refuses the wrong branch on purpose.

## Networking / CDN

- **`*.pages.dev` can be unreachable over IPv4 on some networks — serve content
  from a custom domain.** The content CDN was `al-tawheed-content.pages.dev`,
  which resolves to Cloudflare's `172.66.44.x` IPv4 range. On some ISPs that
  range gets **TCP-reset** (connects, then RST) while IPv6 and other Cloudflare
  ranges work. Browsers/curl prefer IPv6 and succeed; the Dart `http` client
  hits the broken IPv4 path → `SocketException: Connection reset by peer` → a
  **fresh install with no cache strands on "Connect to load lectures"** (2.3.0
  production). Existing users are shielded by the cached catalog
  (stale-while-revalidate). Root fix: point `AppConfig.contentBaseUrl` at a
  custom domain under `kitabattawheed.com` (uses the reachable 104.21.x/172.67.x
  anycast IPs). Diagnostic: `curl -4 URL` vs `curl -6 URL` — if v4 fails and v6
  works, it's this.
- **Resilience added in 2.3.1:** `RemoteContentService.fetch` now retries the
  fetch (3 attempts, injectable `http.Client` + `maxAttempts`/`retryDelay`), and
  `CatalogProvider` listens to `ConnectivityProvider` and auto-reloads when the
  network returns (previously the user was stuck until manually tapping Retry).
  **Retry delay defaults to `Duration.zero`** on purpose — a non-zero delay
  schedules a `Timer`, and a fire-and-forget `catalog.load()` in a widget test
  then trips "A Timer is still pending after the widget tree was disposed."
- **How we missed it:** `remote_content_service_test` only exercised the *pure*
  `decideCacheStrategy`; the actual fetch/failure/retry had **zero coverage** (no
  mock client). The fetch is now testable via an injected `MockClient`
  (`package:http/testing.dart`) — see the `fetch — retries` group.
- **"Works in the browser" ≠ "works in the app."** Browsers use Happy Eyeballs
  (race IPv4+IPv6, prefer whichever answers) and cache/retry, so they hide a
  flaky IPv4 path; the Dart client lands on it and fails. The pages.dev failure
  was **intermittent** (~7 of 8 IPv4 tries reset), which is exactly why it "works
  after a few tries" and why a no-cache fresh install (needs one success) is the
  worst case.
- **The CDN content lives in a *separate* repo — `mdarif/Al-Tawheed-Content`**
  (checked out at `../Al-Tawheed-Content`), auto-deployed to Cloudflare Pages on
  push to `main`. This app repo only has *dev fixtures* under `dev/fixtures/`.
  The 2.3.1 fix needed edits in **both**: `AppConfig.contentBaseUrl` here, and
  `series.json`'s `catalogUrl`s + the catalogs' `coverImageUrl` there.
- **Updating the CDN `series.json` fixes existing users at runtime — no app
  release.** The app fetches `series.json` and follows its `catalogUrl` per
  series, so repointing those at the custom domain repairs already-installed
  apps as their cache refreshes. The app-code change (`contentBaseUrl`) only
  helps new/updated installs.
- **Cloudflare Pages edge-caches JSON (`_headers`: `max-age=3600`,
  `stale-while-revalidate=86400`).** A content push is live at the origin
  immediately but the **edge serves the old copy for up to ~1 h** before
  revalidating. Verify a deploy with a **cache-buster query** (`?cb=<ts>` bypasses
  the edge cache); purge in the Cloudflare dashboard for urgent changes.

## Security

- Remote-sourced URLs are launched through an https/mailto allowlist
  (`lib/utils/safe_url_launcher.dart`) — never pass a raw remote URL to
  `launchUrl`. Download ids from remote JSON are validated with
  `isSafePathSegment()` before use in file paths (path-traversal defence).
