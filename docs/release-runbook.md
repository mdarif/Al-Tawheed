# Release Runbook

Step-by-step guide for cutting a production release: run the local gate,
trigger the automated release (one click, from `develop`), and (optionally)
submit to the Play Store.

For initial machine setup (signing keys, Java, `gh` auth) and general build
commands, see [deployment.md](deployment.md).

Follow these steps **in order** — each one says what to run, what success
looks like, and what to do if it doesn't go to plan.

> ### Note — Urdu Book tab (raised 2026-07-12, resolved on `feature/urdu-book`)
>
> The Urdu Book tab is enabled **client-side** and ships automatically with the
> `feature/urdu-book` release — `SeriesConfig.fromJson` defaults `hasBook` to
> `true` for the Urdu series because the app bundles the book asset. **No
> `series.json` change is needed** (and adding `hasBook:true` there would break
> not-yet-updated installs — don't). See [gotchas.md → Book](gotchas.md).
>
> Content is **done**: `assets/content/book_tawheed-ur.json` now ships the real
> bilingual Urdu content (all 67 chapters, through `876abed`), guarded by
> `test/book_content_integrity_test.dart`. The only residual item is *scholarly*
> QA of the translation — not a release blocker.

## Pre-flight checklist

- [ ] `develop` has everything you want to ship, pushed, and CI is green:
      `gh run list --branch develop --limit 1`
- [ ] No uncommitted changes anywhere you're about to switch branches from:
      `git status`
- [ ] A supported Android device is connected and authorized: `flutter devices`
      (required for Step 1 — Flutter validation plus the Patrol discovery gate).
      For the current `patrol 4.6.1` pin, use `patrol_cli 4.4.0` on a stock
      Android target below API 36; Android 16/API 36 currently discovers zero
      Patrol tests and cannot satisfy this gate.
- [ ] Golden (pixel-snapshot) tests are green on `develop`:
      `gh run list --workflow flutter-golden.yml --branch develop --limit 1`.
      They run automatically on any push to `develop` touching `lib/**`,
      `assets/fonts/**` or `test/golden/**`; if your release contains no UI
      change there may be no recent run, which is fine — dispatch one with
      `gh workflow run flutter-golden.yml --ref develop` if you want the
      check. On a Mac you can also just run `make test-goldens` locally.
      **Goldens are macOS-only** and are NOT part of the release workflow, so
      this is the only thing standing between a UI regression and the store.
- [ ] (One-time, CD Phase 2) Signing secrets are set —
      `gh secret list --repo mdarif/Al-Tawheed` should list `KEYSTORE_BASE64`,
      `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`. If any are missing, see
      [ci-cd.md → One-Time Setup → "Add CD Phase 2 signing
      secrets"](ci-cd.md#5-add-cd-phase-2-signing-secrets) — Step 2 will fail
      in `prepare` at "Require signing secrets" without them (in seconds,
      before any build).
- [ ] (One-time, CD Phase 3) Play Store secret is set —
      `gh secret list --repo mdarif/Al-Tawheed` should list
      `GOOGLE_PLAY_SERVICE_ACCOUNT`. If missing, see
      [ci-cd.md → One-Time Setup → "Add CD Phase 3 Play Store
      secret"](ci-cd.md#6-add-cd-phase-3-play-store-secret) — Step 2 will fail
      at "Require Play Store service account" without it.
- [ ] **`PLAY_FGS_MEDIA_DECLARED` is set to `true`** (or, for a one-time
      bootstrap attempt, `bootstrap`) — `gh secret list --repo
      mdarif/Al-Tawheed` should list it. Without this the `prepare` job's
      foreground-service preflight (`tool/play_release_preflight.py
      manifest`) refuses the release in seconds, before any build. See [ci-cd.md → One-Time Setup → "Add the
      `PLAY_FGS_MEDIA_DECLARED` secret"](ci-cd.md#7-add-the-play_fgs_media_declared-secret--required-or-publish-fails).

## Step 1 — Run the local release gate

On `develop`, with everything from the pre-flight checklist green:

```sh
make release-apk DEVICE=<device_id>
```

Runs, in order: `pub get` → `dart format --set-exit-if-changed` →
`python3 -m unittest discover -s test/tool` (release tooling) →
`flutter analyze --fatal-warnings` → `flutter test` (unit/widget) →
`flutter test integration_test/app_test.dart` (Flutter validation on-device)
→ `patrol test` (native scenarios — airplane mode, notifications, lock-screen
controls — plus the Arabic-edition suite in `arabic_series_test.dart`;
must discover at least one test) → `flutter build apk --release`.

The format and tooling checks are first because they cost seconds and
`build-android` gates on them too — without them here, Step 1 can pass locally
and the release still fail in CI on a stray format.

**Not covered by this gate:** golden tests. They are tagged `golden` and
skipped by every ordinary `flutter test` (see `dart_test.yaml`), so neither
Step 1 nor the release workflow runs them. On a Mac, run them yourself before
a UI-bearing release:
```sh
make test-goldens          # verify
make goldens-update        # re-bake masters after a REVIEWED intentional change
``` Play Store screenshot generators are separate
asset jobs and are not part of the release gate (`make screenshots
DEVICE=<device_id>`).

**Success** looks like the final line (and requires Patrol to report a non-zero
discovered test count):
```
✓ Release APK: build/app/outputs/flutter-apk/app-release.apk
```

That APK is a **properly signed production build** (`flutter build apk
--release` uses `android/key.properties` → `upload-keystore.jks`). Confirm
the signer if needed:
```sh
$ANDROID_SDK/build-tools/<version>/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
# Expect: Signer #1 certificate DN: CN=Al Marfa Duroos, OU=Development, ...
```

> **This only *builds* the APK — it doesn't install it.** For a final manual
> smoke test before release:
> ```sh
> flutter install -d <device_id>
> # or: adb install -r build/app/outputs/flutter-apk/app-release.apk
> ```
> Open the app and walk through a lecture or two — playback, downloads,
> lock-screen controls — before Step 2.

**If any phase fails:** fix it on `develop`, push, wait for CI to go green,
then restart from Step 1. Don't proceed to Step 2 with a failing gate — it's
the thing standing between you and shipping a broken build.

### Step 1b — Upgrade proof: real process restart (manual, owner-run)

The automated half of the upgrade proof is
`test/upgrade_from_2_4_1_test.dart`: it seeds the exact 2.4.1 preferences and
download layout, builds the current providers over them twice, and asserts
edition/onboarding, bookmarks, progress, font size and the downloaded-lecture
record read back identically. It runs in `make test`, so it is part of the
gate above and needs no device.

It cannot prove that downloaded audio **plays after a genuine process
restart**: `AudioService` initialises once per process, so no in-process test
(`integration_test`, or a second `app.main()`) can model a restart. That is
this manual step. Nothing in the automated gate covers it; do not record it as
passed until you have run it.

Use a stock Android emulator or device with the **same signing key** for both
builds (an upgrade only installs over a build signed by the same key; a debug
APK will fail with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`). The 2.4.1 release APK
is attached to its GitHub release; the 2.4.2 candidate is the release APK from
Step 1.

```sh
PKG=com.almarfa.tawheed
DEVICE=<device_id>            # from `flutter devices` / `adb devices`

# 1. Start from a clean install of 2.4.1 and create state worth keeping.
adb -s $DEVICE uninstall $PKG
gh release download 2.4.1 --pattern '*.apk' --dir /tmp/tawheed-2.4.1
adb -s $DEVICE install /tmp/tawheed-2.4.1/*.apk
adb -s $DEVICE shell am start -n $PKG/.MainActivity
#    In the app: START LISTENING, open the first lecture, tap the download
#    control and wait for "Saved for offline"; bookmark it; let it play for
#    ~20 s so a position is saved; then, in the Urdu edition, set a
#    non-default Book text size (2.4.1: open a Book chapter and pinch).

# 2. Upgrade in place (keeps data). Confirm the version really changed.
adb -s $DEVICE install -r build/app/outputs/flutter-apk/app-release.apk
adb -s $DEVICE shell dumpsys package $PKG | grep versionName     # expect 2.4.2

# 3. Kill the process, then cold-launch. This is the restart under test.
adb -s $DEVICE shell am force-stop $PKG
adb -s $DEVICE shell am start -n $PKG/.MainActivity

# 4. Go offline so playback can only come from the downloaded file.
adb -s $DEVICE shell cmd connectivity airplane-mode enable
```

Then, in the app, with no network:

- [ ] It opens on **Lectures** (no Welcome / series picker): onboarding and the
      edition survived.
- [ ] **Library > Downloads** lists the lecture you downloaded; **Library >
      Bookmarks** lists the one you bookmarked.
- [ ] Tap the downloaded lecture: the Player opens, shows **Saved for
      offline**, and the position **advances** (play icon becomes pause, the
      clock moves) with the radio off. It resumes from the position saved in
      2.4.1, not from zero.
- [ ] (Urdu edition) **Settings > Reading** shows the text size you pinched to
      in 2.4.1, and a Book chapter opens at that size.
- [ ] Repeat the restart once more (`am force-stop`, `am start`) and play the
      same lecture again: a second cold launch behaves identically.

```sh
adb -s $DEVICE shell cmd connectivity airplane-mode disable   # always restore
```

**Pass** = every box ticks. **Fail** = any lecture missing from Downloads,
a Welcome screen for a returning user, or a downloaded lecture that stays
buffering offline: stop the release and file it against the migration, with
`adb -s $DEVICE logcat -d` attached.

## Step 2 — Trigger the release

### Recommended: one click, from develop

```sh
git checkout develop   # if you aren't already
make release MODE=develop BUMP=patch     # bug fixes only            → 2.0.2 → 2.0.3
make release MODE=develop BUMP=minor     # new user-facing features  → 2.0.2 → 2.1.0
make release MODE=develop BUMP=major     # breaking changes          → 2.0.2 → 3.0.0
```

This dispatches `flutter-release.yml` from `develop` with
`confirm_promote=true`. Watch it run:
```sh
gh run watch
# or: https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml
```

The workflow runs an eight-job chain (plus a dry-run-only summary job):

```
prepare → quality → build-android → verify-android → finalize-git → publish-play → github-release → sync-develop
                                     └─ a dry run stops here (the last four are skipped) ─┘
```

**The rule: nothing durable exists until `verify-android` has passed.** No
pushed commit, no tag, no Play release and no GitHub Release is created before
the signed APK has been installed and launched. Until then a run leaves behind
only CI artifacts and read-only Play queries.

1. **`prepare`** — cheap and fast. Rejects a dispatch from any ref other than
   `master`/`develop` (and from `develop` without `confirm_promote`), pins the
   **immutable source SHA** (the commit the run was dispatched at — pushes to
   the branch while it runs cannot change what ships), checks `yq` exists,
   computes the new version/tag **once** and exports it (no later job
   recomputes it from the bump), checks the signing secrets, the Play service
   account and the foreground-service declaration, and takes a read-only
   snapshot of Play state. A missing secret or a stale tag fails in seconds.
2. **`quality`** — `make format-check` (check only, never rewrites), `make
   analyze`, `make test`, `make test-tooling`. Different machine, same checks
   as Step 1.
3. **`build-android`** — the only job holding signing secrets. Stamps exactly
   the version `prepare` computed, builds the **production-signed** APK + AAB
   (same upload key as Step 1's local build), asserts it built that version,
   records the **AAB's SHA-256**, and uploads `android-release`.
4. **`verify-android`** — a clean runner with no secrets. Downloads the exact
   signed APK, runs `tool/verify_release_apk.py --inspect-only`, then
   installs/launches/backgrounds/resumes it on an API 34 emulator, uploading
   screenshot + logcat evidence either way. **This is the job the
   `skip_verify` input bypasses** — see ci-cd.md for when that's legitimate.
   It exports `verified=true` only when the device check actually ran.
5. **`finalize-git`** — the first durable state. **One atomic push** of
   `master` (promoted to the source SHA when dispatched from `develop`) + the
   `chore: release X.Y.Z` commit + the tag: either all of it lands or none.
   Resumable: if the tag already exists it is accepted only when its commit's
   parent is the dispatched source SHA, its `pubspec.yaml` version is the
   release version, and `master` contains it; otherwise the job aborts.
6. **`publish-play`** — builds nothing (reuses `android-release`). Re-queries
   Play itself (the `prepare` snapshot may be stale), then: **upload** if the
   versionCode is absent, **assign** an already-uploaded bundle to the
   internal track without re-uploading, or **skip** if that exact build is
   already `completed`. A versionCode already on Play counts as ours only when
   Play's reported bundle SHA-256 equals the AAB's; otherwise the job fails
   with a conflict and writes nothing. It finishes by proving Play now shows
   the exact build as `completed` on the **internal track**
   (Play "What's new" notes are the **same English text** for en-US/ar/ur —
   release notes are authored in English only).
7. **`github-release`** — creates the release for the tag, or edits it if a
   previous attempt already did, replacing the APK, AAB and
   `play-store-notes.txt` assets. The body says "Device verification: PASSED"
   or "Device verification: SKIPPED" depending on what actually ran.
8. **`sync-develop`** — no-op if `develop` already contains the tag;
   fast-forwards it (with a lease) only if `develop` still equals the source
   SHA; otherwise fails with merge instructions. It never overwrites commits
   that landed on `develop` meanwhile.

> **Gating is by `if:`, not by luck.** The four state-changing jobs
> (`finalize-git`, `publish-play`, `github-release`, `sync-develop`) each carry
> `if: inputs.dry_run != true` and no status function (`always()` etc.), so a
> dry run structurally cannot reach them; `test/tool/test_workflows.py` proves
> it. See `docs/gotchas.md` for why `needs:` skip-propagation matters here.

> **First time, or testing a workflow change?** Add `DRY_RUN=true` (or run
> `make release MODE=dry BUMP=patch`) to run quality + build + verify only —
> nothing is promoted, committed, tagged, pushed, published or released:
> ```sh
> make release MODE=develop BUMP=patch DRY_RUN=true
> ```
> **A dry run that finishes in under a minute with no artifacts is a
> FAILURE, not a pass.** Confirm `build-android` and `verify-android` ran and
> uploaded the `android-release` / `verify-evidence` artifacts — the
> `dry-run-summary` job's step-summary exists to make this obvious.

### Fallback: manual promote + release from master

Use this only if `make release MODE=develop` can't be used — e.g. `finalize-git`
aborted because `master` has genuinely diverged from `develop` and needs a
human to resolve it (see Troubleshooting), or you need to release code that's
already on `master`.

> ## ⚠️ Read this before you do anything else
> **`make release` builds from `origin/master` on GitHub, not your local
> checkout** (`gh workflow run flutter-release.yml --ref master` resolves
> against the remote). If your merge isn't pushed and confirmed, the release
> workflow silently ships whatever was already on `origin/master` — and
> nothing warns you. This happened on 2026-06-07: a `2.1.0` release shipped
> containing only one stray commit because the local merge was never pushed.
> The fix: don't trust "the merge is done" until you've *verified* the remote
> matches local — that's what this section does.

```sh
git checkout master
git pull origin master
git merge develop
git push origin master
```

`master` only blocks force-pushes and branch deletions — no PR/review is
required, so this direct merge+push is normal *as long as `origin/master`
hasn't drifted independently* (see "if the push is rejected" below).

#### Now prove the push landed — don't skip this

```sh
git fetch origin
git status
# must say: "Your branch is up to date with 'origin/master'"
git log origin/master..HEAD --oneline
# must print nothing
```

If either check is off, **stop** — `make release` will build the wrong code.

> #### If the push is rejected ("non-fast-forward" / branches have diverged)
> Something added commits to `origin/master` that your local branch doesn't
> have. **Do not force-push.** Instead:
> ```sh
> git merge origin/master    # bring the remote commits into your local branch
> # resolve any conflicts (commonly the `version:` line in pubspec.yaml —
> # keep whichever number is higher, since that's the one already public)
> git push origin master
> git fetch origin && git status   # re-verify "up to date" before continuing
> ```

Once `origin/master` is confirmed up to date:

```sh
make release BUMP=patch     # must be run from master
```

`sync-develop` still runs automatically afterward — no separate "sync
develop" step needed even in this fallback flow (it fast-forwards `develop`
only if it still equals the commit the release was built from; after the
manual merge above, `develop` and `master` are the same commit, so it does).

## Step 3 — Verify the release actually shipped

- [ ] New tag exists: `git fetch --tags && git tag --sort=-creatordate | head -3`
- [ ] New release is live: `gh release view --web` — check the changelog
      describes THIS release's commits (compare against
      `git log <previous-tag>..<new-tag> --oneline` if anything looks like it
      could be from a previous release — see Troubleshooting below) and the
      APK is attached and downloadable
- [ ] `develop` and `master` are both up to date locally:
      `git fetch origin --tags`
- [ ] (Optional) Install the release-workflow APK on a second device to
      confirm it launches. `verify-android` already did exactly this on an
      API 34 emulator, so this is now a belt-and-braces check on real
      hardware rather than the only one — download the `verify-evidence`
      artifact from the run to see CI's screenshot and logcat.
- [ ] New internal-track release is live: play.google.com/console →
      Al-Tawheed → Testing → Internal testing — confirm version `<TAG>` /
      build `<NEW_VERSION>` is present (CD Phase 3)

If the workflow fails, `make ci-logs` fetches the failed run's logs directly
— no need to open a browser. Common failure points are in Troubleshooting
below.

## Step 4 — (Play Store only) Promote internal → production

Not every release needs this — only do it when you're ready to push to
production on the Play Store.

The `publish-play` job already uploaded `app-release.aab` to the
**internal track** (status: completed) with the auto-generated
`play-store-notes.txt` as the "What's new" text — nothing to build or upload
manually.

1. play.google.com/console → Al-Tawheed → Testing → Internal testing → open
   the release for version `<TAG>` / build `<NEW_VERSION>`
2. **Promote release** → choose **Production** as the target track — this
   carries over the AAB and release notes
3. Review the carried-over "What's new" text (edit if needed)
4. If you see an "Advertising ID" error → click **"Release without
   permission"** (the app has no ads)
5. Review → Start rollout to Production (or save as a draft first)

> **CI's Play Store upload failed, or `GOOGLE_PLAY_SERVICE_ACCOUNT` isn't set
> yet?** Build and upload the AAB by hand:
> ```sh
> flutter build appbundle --release
> # Output: build/app/outputs/bundle/release/app-release.aab
> # Requires: android/key.properties with the correct storeFile path
> ```
> Then upload it directly to whichever track you need via Play Console.

---

## Troubleshooting

### Failure points and recovery — read this first

The release is a resumable chain. The one rule that tells you how worried to
be: **nothing durable exists until `verify-android` has passed.** A failure at
or before `verify-android` leaves nothing behind but CI artifacts. After it, each
job leaves a known state and the next attempt picks up from there.

**To resume, use "Re-run failed jobs" on the SAME run** (Actions → the run →
Re-run failed jobs, or `gh run rerun <run-id> --failed`). Jobs that already
succeeded keep their outputs — the version, the source SHA and the AAB SHA-256
— so nothing is recomputed and the build is not repeated.

- Do **not** use "Re-run all jobs" once `finalize-git` has pushed: `prepare`
  would recompute the version, find the tag, and (correctly) refuse.
- A **fresh dispatch** is a *new release*: from an already-bumped `master` it
  computes the next version; from a `develop` that was never synced it
  computes the **same** version, finds the existing tag, and aborts in
  `prepare` ("Tag X.Y.Z already exists"). That abort is the signal to resume
  the old run instead.

| Job that failed | State it leaves | What "Re-run failed jobs" does |
|---|---|---|
| `prepare` | Nothing | Re-validates, recomputes the version. Fix the cause first (missing secret, bad ref, `confirm_promote`, Play conflict). |
| `quality` | Nothing | Re-runs the gates. A real failure needs a fix on `develop`, then a fresh dispatch. |
| `build-android` | Artifacts only | Rebuilds the same version (replaces `android-release`). |
| `verify-android` | Artifacts only | Re-verifies. A real crash needs a fix and a fresh dispatch; `skip_verify=true` is for emulator/infra outages only. |
| `finalize-git` | Nothing, **or** `master` + commit + tag all together (the push is one atomic push) | Tag absent: creates it. Tag present: continues only if its commit's parent is the dispatched source SHA, its `pubspec.yaml` version is the release version, and `master` contains it — otherwise aborts and tells you why. It never retags. |
| `publish-play` | The tag is on `master`. Play has: nothing, a bundle only, or the finished release | Re-queries Play and acts: **upload** if absent, **assign** the already-uploaded bundle without re-uploading, **skip** if that exact build is already `completed`; then verifies Play shows the same SHA-256. |
| `github-release` | Tag + Play release exist | Creates the release, or edits it and replaces the assets (`--clobber`). |
| `sync-develop` | The release is fully shipped | No-op if `develop` has the tag; leased fast-forward if `develop` is still the source SHA; otherwise fails with merge instructions. |

**`publish-play` conflict ("exists on Play with SHA-256 …, but this workflow
built SHA-256 …").** A versionCode is on Play but it is a *different* artifact
(a manual upload, or an older build). Nothing was written. A consumed
versionCode can never be reused, so bump the `+BUILD` number on `develop` and
cut a **new** release; the tag from this run stays on `master` as a record.

**`publish-play` fails but you suspect Play has the build.** Re-run failed
jobs: the decision step will say `skip` if the exact build is already
`completed` on the internal track, and the job turns green without writing.

**`sync-develop` fails => the release already shipped; only `develop` needs
manual fixing.** The AAB is on Play, the tag and GitHub Release exist, the
commit is on `master`. Do not re-trigger the release. Reconcile `develop`:
```sh
git fetch origin && git checkout develop && git merge origin/master
# if develop had its own commits, resolve the pubspec.yaml `version:` conflict
# keeping the HIGHER number, then:
git push origin develop
```
(`--ff-only` works when `develop` has no commits of its own.) The job is
deliberately strict: it never overwrites or rebases commits that landed on
`develop` while the release ran.

---

**"`publish-play` failed with 'The caller does not have permission' (403),
even though the service account is invited and Active"**
Account-level "Release apps to testing tracks" is **not sufficient**. Grant it
at the **app level**: Users and permissions → the service account → Manage →
**App permissions → Add app → com.almarfa.tawheed** → enable **Release apps to
testing tracks** *and* **Manage testing tracks and edit tester lists** → Apply.
(First observed on the 2.3.0 release — account-level alone 403'd across several
runs; the app-level grant with "Manage testing tracks" cleared it.) If
account-level looks right and it still 403s within the first ~30 min it may also
be permission propagation — but if it persists past that, it's the missing
app-level grant, not time.

**"`finalize-git` failed: 'src refspec master does not match any'"**
Historical (2.3.0): the release job runs in **detached HEAD**, so there is no
local `master` to push. `tool/release_git.py` now pushes an explicit
`<sha>:refs/heads/master` refspec together with the tag in one `--atomic`
push, and `finalize-git` runs before any Play upload, so a failure here can no
longer leave a live Play build without a tag. If it ever regresses, the
push is in `finalize()` in `tool/release_git.py`.

**"`finalize-git` failed: 'master is not an ancestor of the source SHA'"**
`master` moved (or diverged from `develop`) after the release was dispatched,
or someone pushed to `master` outside this workflow. Nothing was pushed. Use
the **Fallback: manual promote** section to reconcile, then dispatch again.

**"`finalize-git` failed: 'The tag already exists … but …'"**
The tag is there but this run did not create it (its commit has a different
parent, a different `pubspec.yaml` version, or `master` does not contain it).
Do not re-run. Inspect `git show <tag>`; delete the tag only if it was a
mistake, or dispatch a new release.

**"sync-develop failed: 'GH006: Protected branch update failed for
refs/heads/develop'"**
`develop`'s "Flutter CI" required status check rejects a push from
`github-actions[bot]` (no bypass; `enforce_admins:false` lets *admins* bypass but
not the bot). **Fixed as of 2.3.1+**: `sync-develop` checks out with
`secrets.DEVELOP_SYNC_TOKEN` (a fine-grained admin PAT), so its push runs as the
repo owner and bypasses. If it fails again, the usual cause is **the PAT expired**
— regenerate the fine-grained token (Contents + Workflows: write on this repo)
and update the `DEVELOP_SYNC_TOKEN` secret. Manual recovery meanwhile (your own
admin push bypasses too):
```sh
git checkout develop && git merge --ff-only origin/master && git push origin develop
```

**"`publish-play`: 'versionCode N exists on Play with SHA-256 …' / 'Version
code N has already been used'"**
Play already has versionCode N. Since the Play publish now runs *after* the tag
is pushed and re-queries Play first, the normal "half-shipped" case resolves
itself on "Re-run failed jobs" (same SHA-256: the job assigns or skips). If you
still see this, the code belongs to a **different** artifact (typically a manual
upload with a higher build number): bump `pubspec.yaml`'s `+BUILD` past the
highest versionCode in Play Console (e.g. `2.2.0+15` → `+16`), commit, push, and
cut a new release.

**"Release workflow failed at 'Require signing secrets'"** (in the
`prepare` job)
One or more of `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`,
`STORE_PASSWORD` aren't set as repo secrets yet (CD Phase 2). This is checked
in `prepare`, before any build — `build-android`'s "Configure release signing"
step only decodes the keystore and no longer validates.
Nothing has shipped at this point. See
`docs/ci-cd.md` → "One-Time Setup" → "Add CD Phase 2 signing secrets" for the
exact `gh secret set` commands — run them in your terminal, never paste
secret values in chat.

**"Release workflow failed at 'Require Play Store service account': secret
is not set"** (in the `prepare` job)
`GOOGLE_PLAY_SERVICE_ACCOUNT` isn't set as a repo secret yet (CD Phase 3). See
`docs/ci-cd.md` → "One-Time Setup" → "Add CD Phase 3 Play Store secret".

**"`prepare` failed at 'Foreground-service declaration preflight': refusing to
upload — `PLAY_FGS_MEDIA_DECLARED` is not true"**
The `PLAY_FGS_MEDIA_DECLARED` secret is unset or not `true`/`bootstrap`. This
is a required secret, not an optional one — see the pre-flight checklist and
`docs/ci-cd.md` → "One-Time Setup" → "Add the `PLAY_FGS_MEDIA_DECLARED`
secret". If Play Console hasn't surfaced the foreground-service declaration
form yet, set it to `bootstrap` for one attempt, then switch it to `true`
once you've filled in the form. Nothing has shipped at this point — this
check runs in `prepare`, before any build.

**"`publish-play` failed with 'no application was found' / track not found"**
Google requires at least one **manual** upload to a track via Play Console
before the API can publish to it. Build the AAB locally (Step 4's fallback
box), upload it to the **internal** track by hand once, then **Re-run failed
jobs** (if that manual upload used the release's own AAB the job skips; a
different AAB under the same versionCode is reported as a conflict — see
above).

**"`publish-play` failed with a permission / 403 error"**
The service account in `GOOGLE_PLAY_SERVICE_ACCOUNT` doesn't have **Release
Manager** access to Al-Tawheed yet, or that access hasn't propagated. Play
Console → Users and permissions → confirm the service account's email has
Release Manager (or Admin) on this app, then **Re-run failed jobs** — the
tag is already on `master`, so do not dispatch a new release.

**"`release MODE=develop` failed at `finalize-git`: 'master is not an ancestor
of the source SHA'"**
`master` has diverged from `develop` — most likely someone pushed directly to
`master` outside this workflow, or `sync-develop` failed on a previous
release and was never reconciled. Nothing was pushed. Use the **Fallback:
manual promote** section above to reconcile `master` and `develop` by hand
(resolve the `pubspec.yaml` version conflict, keeping the higher number), then
dispatch `make release MODE=develop` again.

**"`release MODE=develop` failed at `prepare`: 'Dispatched from develop without
confirm_promote=true'"**
`make release MODE=develop` always sets `confirm_promote=true` — if you see this, the
workflow was dispatched manually (GitHub UI or `gh workflow run`) without
checking that input. Re-run via `make release MODE=develop`, or tick
`confirm_promote` if dispatching manually. This guard exists so an accidental
`--ref develop` dispatch can't silently ship stale code from `master`. (A
`--dry_run` dispatch from `develop` does not need it.)

**"`sync-develop` failed: 'develop has moved since this release was cut'"**
`develop` picked up its own commits (most likely its own `pubspec.yaml`
edits) since the release was dispatched. The release has shipped. Reconcile by hand:
```sh
git checkout develop
git pull origin develop
git merge master
# resolve the `version:` conflict in pubspec.yaml — keep the HIGHER of the
# two numbers, since that's the one already public on master / tagged in
# the release
git add pubspec.yaml
git commit
git push origin develop
```

**🔴 "The release's changelog only shows one or two commits, but I shipped
way more than that"** — your release shipped the **wrong code**, fix it
immediately. This is the failure mode the manual flow's "prove the push
landed" check exists to prevent (it happened for real on 2026-06-07 — a
`2.1.0` release went out containing only a stray "Add Play Store assets"
commit, missing the entire offline-mode feature set). The one-click flow makes
this much harder to hit: the release is built from the immutable source SHA
the run was dispatched at, and `finalize-git` refuses to push if `master` is
not an ancestor of that SHA. If you're using the manual fallback and it
happens anyway:
1. Confirm the gap: `git log <bad-release-tag>..<your-local-master> --oneline`
   — if this lists your real commits, the release is missing them
2. Reconcile the branches (see the Fallback section's "if the push is
   rejected" box)
3. Decide what to do with the bad release/tag — editing its notes to point at
   the corrected version is the least destructive option; deleting it
   (`gh release delete <tag> --yes && git push origin :refs/tags/<tag>`) is
   more thorough but rewrites public history
4. Re-run Step 1's local gate is not needed again, but do re-verify
   `origin/master` is correct, *then* trigger a fresh release — it'll bump
   past the bad tag automatically since the version comes from
   `pubspec.yaml`, not which tags exist

**"The changelog describes the PREVIOUS release's changes, not this one (but
the APK itself is correct)"**
This was a workflow ordering bug (first fixed 2026-06-13): git-cliff's
`--latest` resolves to the newest tag *that exists*, so running it before the
new tag was created produced the previous release's changelog, and the fix was
`--unreleased` (commits since the last tag). The graph has since changed so
that the tag is pushed in `finalize-git` *before* `publish-play` and
`github-release` generate their notes — the tag now exists, `--unreleased`
would be empty, and both jobs correctly use `--latest` on a checkout of the
release commit. If a changelog is wrong again, check those two jobs' "Generate
changelog" args and that they check out `needs.finalize-git.outputs.release_sha`.

To regenerate the correct changelog for an already-published release and fix
it in place:
```sh
npx --yes git-cliff --config cliff.toml --strip header <previous-tag>..<bad-tag> \
  > /tmp/changelog.md
gh release edit <bad-tag> --notes-file /tmp/changelog.md
```

**"The integration test failed during `make release-apk` with
`Found 0 widgets with text "START LISTENING"`"**
The Flutter widget tree never finished building before the test's 30s wait
expired — usually because something blocked `runApp()` during cold start
(e.g. a native permission dialog being awaited synchronously in `main()`). It
is *not* a flaky-timing issue you can fix by waiting longer. Check
`lib/main.dart` for anything `await`ed before `runApp()` that could show
native UI (permission requests, platform channel calls that wait on user
interaction), and make sure those are fired without blocking startup.

**"`make release MODE=develop` says it must be run from develop" / "`make release`
says releases must be triggered from master"**
Each target checks `git rev-parse --abbrev-ref HEAD` and refuses to run from
the wrong branch (intentional — stops a release from being tagged off a
feature branch by accident). `make release MODE=develop` → `git checkout develop`.
`make release` → `git checkout master && git pull origin master`.

**"Tag already exists" in the release workflow (`prepare`)**
Either the version in `pubspec.yaml` wasn't bumped since the last release, or a
previous run already pushed this release's tag and stopped later (Play,
GitHub Release or the develop sync). In the second case do **not** dispatch
again: open the earlier run and use **Re-run failed jobs** — see "Failure points
and recovery" above. If it really is a stale version, bump `pubspec.yaml`
manually (or choose a higher `BUMP` level) and push before re-triggering.

**"`make release` / `make release MODE=develop` returns HTTP 403"**
Your `gh` token is missing the `workflow` scope — see `docs/deployment.md` →
"GitHub CLI auth".

**"I ran `make release-apk` and the APK isn't on my phone"**
Expected — the target only *builds* `app-release.apk`, it never installs
anything. Run `flutter install -d <device_id>` or
`adb install -r build/app/outputs/flutter-apk/app-release.apk` afterward.

**"Direct merge into master went through without any review prompt — is that
right?"**
Yes, as of the live-verified state on 2026-06-07: `master` only blocks
force-pushes and branch deletions, nothing requires PRs or reviews on either
branch (only `develop` requires the `Flutter CI` status check to merge *into*
it). See `docs/ci-cd.md` → "Setup Status" for the full picture and how to add
PR review back if you want it.

**"Can I require PRs on master without breaking the release bot?"**
Not with classic branch-protection rules — they have no bypass-actor field, so
the release bot's pushes (`finalize-git`, and `sync-develop` via the PAT) would start
failing. You'd need to switch to Repository Rulesets, which do have a
bypass-actor field, and add `github-actions[bot]` to it.
