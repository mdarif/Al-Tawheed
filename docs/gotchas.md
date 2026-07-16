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
- **A newly-added file in a directory-declared asset folder needs a build-cache
  bust before `flutter test`/`flutter run` sees it.** `pubspec.yaml` lists
  `assets/images/` (the *directory*), so the asset build cache keys off pubspec
  and does NOT re-scan the folder when you drop a new file in — pre-existing
  files in the same dir load fine, but the new one throws `Unable to load asset:
  "assets/images/…"` at runtime/in tests. `flutter pub get` does **not** fix it;
  `rm -rf .dart_tool/flutter_build build` (or `flutter clean`) does. Cost us two
  green-looking runs before we spotted it.

## Testing

- **An unawaited future that rejects before its matcher is attached = an
  unhandled async error, i.e. a flake.** `download_service_test › "delete
  cancels an active download"` starts a download, does NOT await it, deletes,
  and only then calls `expectLater(done, throwsA(...))`. The delete is what
  makes `done` reject, so under parallel load (`--concurrency=8`) the rejection
  lands before anything is listening and the test fails with a bare `Instance of
  'DownloadCancelled'` — production behaving exactly as designed. Attach the
  matcher **before** the action that triggers the rejection, and await it after.
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
  Since [ADR-0002](decisions/0002-chrome-language-follows-the-content-edition.md)
  the *edition* switch is what flips the chrome (the harness switches editions,
  not UI language) — so this now holds without touching the language picker,
  which is flag-gated off in production anyway.
- **iOS `takeScreenshot` captures the Flutter surface only — no native status
  bar** (clean, good for framing). Android needs
  `binding.convertFlutterSurfaceToImage()` first; iOS must NOT call it.
- **Clear prefs at the start** (`SharedPreferences.getInstance().clear()` before
  `app.main()`) so onboarding (welcome + choose-series) renders — otherwise a
  persisted series selection skips straight to lectures.
- Play caps phone screenshots at **8** and **2:1 max aspect**. The iPhone raw is
  ~2.17:1, so the framer composites onto a 2:1 canvas (1290×2580).

## Book content (hand-transcribed scripture)

- **The Urdu source is un-extractable — every chapter was read by eye.** The
  print PDF *and* .docx carry a corrupted CID Nastaliq text layer, so
  `pdftotext`/`textutil`/raw `<w:t>` all return scrambled garbage. Only
  `pdftoppm -r 220 -png` + visual transcription works. **This is why
  transcription defects recur, and will keep recurring.**
- **Word-level QA does not catch markup defects.** The all-67-chapter print
  re-verification compared *wording* (168 corrections, two of them
  meaning-inverting) and still left 8 markup bugs shipping: ch-59 had six stray
  closers dumped mid-sentence; ch-21/ch-48/ch-50 had *reversed* ornate pairs;
  ch-38/ch-46/ch-48 had hadith quotes that never closed; ch-44/ch-60 had the
  translator's own words in `[…]`, which the reader paints cyan **as a Qur'an
  citation** — a misattribution, not just a cosmetic slip.
  `test/book_content_integrity_test.dart` now guards all of it. Do not weaken
  those assertions to make a content change pass.
- **The ornate parens are general brackets, not just verse markers.** The print
  uses `﴿…﴾` around translator's glosses too (`﴿شرک سے﴾`, `﴿کڑا﴾`) — ~200 of
  them are correct and must not be "fixed". What is never correct is an
  unmatched or **reversed** pair: U+FD3E/U+FD3F are mirror glyphs, so a reversed
  pair renders as backwards brackets. Convention is `﴿` = U+FD3F (open), `﴾` =
  U+FD3E (close); a naive regex like `﴾[^﴿]*﴿` matches the *gap between* two
  adjacent pairs and invents hundreds of phantom defects — walk the string with
  a depth counter instead.
- **A truncated āyah injection is silent — and recurs.** The Urdu edition is
  bilingual by assembly: the print sets **no Arabic at all** (straight to the
  Urdu translation), so every `{āyah}` is injected from `book_tawheed-ar.json`.
  When the injector mispairs, it drops the tail and leaves something still
  well-formed: ch-09 carried 18 chars of a 184-char passage (an-Najm:19 under a
  translation of 19-23, citation truncated to match), ch-40 carried the first
  clause of ar-Ra'd:30 under a translation of the whole verse — and ch-40's
  citation still matched, so a citation-parity check could never see it.
  73ca16b fixed three more. Compare *lengths* against ar.json, not just
  citations; `book_content_integrity_test` now does.
- **A citation always carries a number; a gloss never does.** That is the only
  reliable way to tell `[النَّحْل:120]` from `[محض اتنا کہا کہو کہ]`, because the
  reader's `_citationRe` matches any `[…]`.
- **The cross-validation tooling is NOT in the repo.** It lives in
  `~/kat-urdu-work/` (`urdu_qa.md`, `apply_verify.py`, `assemble_urdu.py`,
  `pagemap.json` — chapter→print-page map). The commits citing "0 integrity
  mismatches" refer to it. Anything that must survive belongs in `tool/` or a
  test, not there.
- **The book remains a transcribed draft — no scholar has proofed it.**

## i18n & multi-series

- **The edition supplies the *default* chrome language; an explicit pick wins.**
  `LanguageProvider.language` resolves `explicit ?? seriesDefault ?? device`
  (see [ADR-0002](decisions/0002-chrome-language-follows-the-content-edition.md)).
  So the Arabic edition renders Arabic chrome out of the box, but never
  overrides a language the user chose in Settings. **There is exactly one chrome
  locale — `context.l10n`. Never fork chrome on the series.** `l10nForSeries` is
  gone: it was reverted once already for discarding the user's pick, and forking
  is now redundant anyway since the edition steers chrome upstream. `arabicL10n`
  survives only for the Welcome screen, which renders before the edition is
  definitive.
- **`setLanguage` compares against the saved pick, not the effective language.**
  An Arabic-edition user tapping "العربية" is already seeing Arabic via the
  series default; guarding on the effective value early-returns, persists
  nothing, and lets their chrome flip to English on the next edition switch.
- **Chrome numbers follow the chrome locale — the Book follows the edition.**
  Two different rules, on purpose:
  - **Chrome** (durations, counts, %, seek bar, lecture/class badges, speed
    chips): `context.localizedDigits` / `localizedTime` /
    `localizedHoursMinutes` / `localizedDecimal` / `numeralFontFamily`. They key
    off `Localizations.localeOf`, **not** `LanguageProvider` — that is the
    locale the surrounding words actually resolved from, so digits and words
    agree by construction. English chrome ⇒ `01`, `23h 19m`. The Urdu edition
    ships English chrome, so **it must keep Western digits** — localizing it was
    a regression once already.
  - **Book** (chapter badges, position indicator, inline āyah numbers):
    `localizedDigitsInString(s, series.language)` + `series.bookFontFamily`. The
    Urdu book reads ۰۱ even under English chrome, because it is set the way the
    print sets it.
  The helpers post-process the *finished* l10n string (idempotent, `[0-9]` only)
  rather than retyping ARB placeholders, because `partsCount` needs its `int`
  for `Intl.pluralLogic`. **Never use `NumberFormat`/`decimalPattern`:** it keys
  off the l10n locale and CLDR's default numbering system for `ur` is `latn`, so
  it silently renders `45` — discarding the U+06F0–06F9 set the Urdu book
  deliberately uses. Never blanket-apply: `settingsAboutVersion` would render
  `٣٫٤٫١` while the clipboard kept `3.4.1`.
- **Arabic needs the decimal separator too** — `١٫٥` (U+066B), not `١.٥`. See
  `localizedDecimal`; the speed chips are the only user of it today.
- **The Book's colour-key samples are forced RTL.** The ornate parentheses
  (U+FD3E/U+FD3F) are bidi-neutral, so in an LTR sheet U+FD3F lands on the left
  where its glyph reads as a *closing* brace — the key rendered ﴾…﴿ mirrored.
  They are Arabic typography; lay them out like the reader body, not like the
  chrome around them.
- **The `language` feature flag gates the Settings switcher only** — never the
  effective language. It is `false` in live remote config, so the series default
  is what everyone actually gets today.
- **Every user-facing string must exist in all 4 ARB locales** (`en`, `ar`, `ur`,
  `ur_roman`). English-only additions are a bug. ARB wording is canonical (it won
  over shipped `_ar*` constants during the i18n cleanup).
- Not everything is an ARB duplicate: welcome taglines / native-script titles and
  the choose-series card subtitles are screen-specific branding with no ARB key —
  leave them as constants. A *new series* still needs its native title/tagline
  wired there, not via ARB.

## Book (bundled reader)

- **The Urdu Book ships real *bilingual* content (Arabic āyah + Urdu), NOT the
  Arabic placeholder.** `assets/content/book_tawheed-ur.json` is built by
  `/tmp/build_urdu_book.py` (kept out of the repo): it pulls each clean Arabic
  āyah from `book_tawheed-ar.json` and pairs it with the Urdu **transcribed
  verbatim from the print PDF**, then the masāʾil/hadith in Urdu. Only ch-00 and
  ch-01 are done so far (a proofed sample); the rest of the ~156-page book is
  pending.
- **The Urdu source text is UN-EXTRACTABLE — transcribe from rendered images.**
  Both the print PDF *and* its `.docx` carry a corrupted text layer (the CID
  *Jameel Noori Nastaleeq* font's char mapping drops/reorders letters), so every
  extractor lies: `pdftotext`, `textutil`, and even reading the docx
  `word/document.xml` `<w:t>` runs directly all return scrambled/letters-missing
  garbage (`اتكباوتلیح` for `کتاب التوحید`; `ار شد ت ریتعا یلٰہ` for `ارشادِ باری
  تعالیٰ ہے`). The **only** reliable path is `pdftoppm -r 220 -png` → read the
  page image visually and transcribe. Nastaliq OCR tools aren't accurate enough
  for scripture; don't trust any *text* extraction of this source.
- **Faithfulness beats a "cleaner" paraphrase.** The first Urdu pass was a
  fluent paraphrase; proofing against the PDF showed the print edition's exact
  wording differs throughout (intros `ارشادِ باری تعالیٰ ہے` / `مزید ارشاد ہے`,
  every long āyah translation, both hadith sets, and all masāʾil — which also
  embed āyah translations the paraphrase dropped). Match the PDF verbatim; flag
  edition quirks for a scholar rather than "correcting" them (e.g. the Muʿādh
  hadith *question* in this edition names only Allah's right over the servants,
  not both directions — the Arabic matn has both).
- **Prophet's name is spelled out (`صلی اللہ علیہ وسلم`), not the `ﷺ` glyph**,
  in the bundled Urdu JSON — the glyph didn't render reliably in the Nastaliq
  font. Digits in the JSON stay Western (`56`, `151`) and are localised **at
  render time** to the *book's* language (Urdu numerals everywhere in an Urdu
  book, even inside Arabic āyāt), via `localizedDigitsInString(text,
  widget.language)` in the reader.
- **The Urdu series renders 3 bottom-nav tabs** (Lectures · Book · Study) — it
  has both `hasBook` and `hasStudyMode`. Settings / Bookmarks / About are **not**
  tabs; they live in the `⋯` overflow menu
  ([app_overflow_menu.dart](../lib/widgets/app_overflow_menu.dart)) shown on
  every shell tab.
- **There is no Home tab, and Lectures is the landing screen** (`/` →
  `/lectures`). The old Home tab was retired: its **only** keeper, the resume
  card, moved to a self-hiding [continue_listening_banner.dart](../lib/widgets/continue_listening_banner.dart)
  atop the Lectures list, and **announcements** moved from the space-eating
  inline banner to a bell+badge ([announcements_bell.dart](../lib/widgets/announcements_bell.dart))
  in the Lectures app bar (tap → bottom sheet of `AnnouncementCard`s). Daily
  Benefit + the offline-prep nudge were dropped. `/book` and `/study` redirect to
  `/lectures` (not `/home`) for series lacking those features.
- **The Urdu Book tab is enabled client-side, not via `series.json`.**
  `SeriesConfig.fromJson` defaults `hasBook` to `true` for the legacy Urdu
  series (`id == legacyId`) because this app version bundles
  `book_tawheed-ur.json`. This deliberately **decouples** the tab from a
  coordinated `series.json` deploy: older app versions have neither the default
  nor the asset, so a shared `series.json` can never strand them with a Book
  tab whose asset is missing. **Do not** add `hasBook:true` to `series.json`
  for `tawheed-ur` — it's unnecessary and would break not-yet-updated installs.
  An explicit `hasBook:false` in the manifest still disables it.
- **Switching series must clear the book, not keep it.** `BookProvider.load`
  short-circuits once loaded, so `switchSeries` calls `BookProvider.reload()`
  (clear to idle); the Book tab lazy-loads the current series' book on open.
  Eager-loading inside `switchSeries` blocks the switch on `rootBundle` I/O and
  hangs `pumpAndSettle` in tests (the load future doesn't resolve under fake
  async) — clear-only avoids both.
- **The Book reader font is per-series** via `SeriesConfig.bookFontFamily`
  (default `NotoNaskhArabic`). To render the Urdu book in Nastaliq later, bundle
  a Nastaliq face and return it from that getter — the reader/chapter-list never
  hardcode the family.

## CI / release

- **The one-click release job runs in detached HEAD — push with `HEAD:master`,
  not `master`.** When dispatched from `develop`, the `release` job checks out
  the promote SHA (`ref: needs.promote.outputs.sha`), so there is no local
  `master` branch. `git push origin master` fails with `src refspec master does
  not match any`; use `git push origin HEAD:master`. (Latent until the first
  release that actually reached the commit/tag/push step.)
- **`sync-develop` pushes to protected `develop` with an admin PAT, not the bot
  token.** `develop`'s protection ("Flutter CI" required status check) rejects a
  push from `github-actions[bot]` (`GH006: Protected branch update failed`), and
  classic branch protection on a *personal* repo has no bypass-actor field to
  whitelist the bot (rulesets could, but only offer "Repository admin"/deploy-key
  bypass on User-owned repos — not the default token). Fix (in
  `flutter-release.yml`): the `sync-develop` checkout uses
  `token: ${{ secrets.DEVELOP_SYNC_TOKEN }}` — a fine-grained PAT (Contents +
  Workflows: write) owned by the repo admin, so the push runs *as the admin* and
  bypasses (`develop` has `enforce_admins: false`). **The PAT expires** — when it
  does, `sync-develop` fails again; rotate the token + update the secret. Manual
  recovery if it ever fails:
  `git checkout develop && git merge --ff-only origin/master && git push origin develop`
  (your own admin push bypasses too).
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
