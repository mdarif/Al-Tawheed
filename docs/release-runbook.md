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
- [ ] (One-time, CD Phase 2) Signing secrets are set —
      `gh secret list --repo mdarif/Al-Tawheed` should list `KEYSTORE_BASE64`,
      `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`. If any are missing, see
      [ci-cd.md → One-Time Setup → "Add CD Phase 2 signing
      secrets"](ci-cd.md#5-add-cd-phase-2-signing-secrets) — Step 2 will fail
      at "Configure release signing" without them.
- [ ] (One-time, CD Phase 3) Play Store secret is set —
      `gh secret list --repo mdarif/Al-Tawheed` should list
      `GOOGLE_PLAY_SERVICE_ACCOUNT`. If missing, see
      [ci-cd.md → One-Time Setup → "Add CD Phase 3 Play Store
      secret"](ci-cd.md#6-add-cd-phase-3-play-store-secret) — Step 2 will fail
      at "Require Play Store service account" without it.
- [ ] **`PLAY_FGS_MEDIA_DECLARED` is set to `true`** (or, for a one-time
      bootstrap attempt, `bootstrap`) — `gh secret list --repo
      mdarif/Al-Tawheed` should list it. Without this the `publish` job's
      Play preflight (`tool/play_release_preflight.py`) refuses the upload
      outright. See [ci-cd.md → One-Time Setup → "Add the
      `PLAY_FGS_MEDIA_DECLARED` secret"](ci-cd.md#7-add-the-play_fgs_media_declared-secret--required-or-publish-fails).

## Step 1 — Run the local release gate

On `develop`, with everything from the pre-flight checklist green:

```sh
make release-apk DEVICE=<device_id>
```

Runs, in order: `pub get` → `flutter analyze --fatal-warnings` →
`flutter test` (unit/widget) → `flutter test integration_test/app_test.dart`
(Flutter validation on-device) → `patrol test` (native scenarios — airplane
mode, notifications, lock-screen controls; must discover at least one test) →
`flutter build apk --release`. Play Store screenshot generators are separate
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

## Step 2 — Trigger the release

### Recommended: one click, from develop

```sh
git checkout develop   # if you aren't already
make release-auto BUMP=patch     # bug fixes only            → 2.0.2 → 2.0.3
make release-auto BUMP=minor     # new user-facing features  → 2.0.2 → 2.1.0
make release-auto BUMP=major     # breaking changes          → 2.0.2 → 3.0.0
```

This dispatches `flutter-release.yml` from `develop` with
`confirm_promote=true`. Watch it run:
```sh
gh run watch
# or: https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml
```

The workflow runs a six-job graph (plus a dry-run-only summary job):
`promote → prepare → build-android → verify-android → publish → sync-develop`.

1. **`promote`** — fast-forward merges `develop` into `master` and pushes.
   Fails fast if that's not possible (see Troubleshooting).
2. **`prepare`** — cheap and fast: computes the new version/tag, rejects a
   duplicate tag, and checks the signing secrets + Play service account are
   non-empty. All of this used to run only after a ~20-minute build; now a
   missing secret or a stale tag fails in seconds.
3. **`build-android`** — the only job holding signing secrets. Re-runs
   analyze + tests (refuses to tag a broken build even if Step 1 passed —
   different machine, same checks), plus the new `dart format
   --set-exit-if-changed` and `tool/` unit-test gates, builds a
   **production-signed** APK + AAB (CD Phase 2 — same upload key as Step 1's
   local build), and uploads them as the `android-release` artifact.
4. **`verify-android`** — a clean runner with no secrets. Downloads the exact
   signed APK, runs `tool/verify_release_apk.py --inspect-only`, then
   installs/launches/backgrounds/resumes it on an API 34 emulator, uploading
   screenshot + logcat evidence either way. **This is the job the
   `skip_verify` input bypasses** — see ci-cd.md for when that's legitimate.
5. **`publish`** — builds nothing (reuses `android-release`). Runs
   `tool/play_release_preflight.py` (which requires the
   `PLAY_FGS_MEDIA_DECLARED` secret — see the pre-flight checklist above),
   uploads the AAB to the Play Store **internal track** (CD Phase 3), commits
   the version bump to `master`, tags it, pushes both, and creates a GitHub
   Release with the APK and an auto-generated changelog. Play "What's new"
   notes are written for en-US/ar/ur but with the **same English text** in
   all three — release notes are authored in English only, unlike every
   other user-facing string in this app.
6. **`sync-develop`** — fast-forward merges `master` (now including the
   version bump + tag) back into `develop` and pushes. This is the step that
   used to be a manual "close out the release" chore — it's now automatic.

> **`needs:` propagates skips.** If an early job is skipped (e.g. `promote`
> on a non-develop dispatch), everything downstream skips too and the run
> still shows green with nothing built. See "dry run" note below and
> `docs/gotchas.md` for the mechanics.

> **First time, or testing a workflow change?** Add `DRY_RUN=true` (or run
> `make release-dry BUMP=patch`) to run build + verify only — nothing is
> promoted, committed, tagged, pushed, or released:
> ```sh
> make release-auto BUMP=patch DRY_RUN=true
> ```
> **A dry run that finishes in under a minute with no artifacts is a
> FAILURE, not a pass.** `needs:` cascade-skips can make the whole graph
> report green while nothing actually built. Confirm `build-android` and
> `verify-android` ran and uploaded the `android-release` / `verify-evidence`
> artifacts — the `dry-run-summary` job's step-summary exists to make this
> obvious.

### Fallback: manual promote + release from master

Use this only if `make release-auto` can't be used — e.g. the `promote` job
failed because `master` has genuinely diverged from `develop` and needs a
human to resolve it (see Troubleshooting), or you need to re-trigger a
release for code that's already on `master`.

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
develop" step needed even in this fallback flow.

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
      confirm it launches. As of CD Phase 2 it's production-signed (same key
      as Step 1's build) — a good final smoke test before Step 4.
- [ ] New internal-track release is live: play.google.com/console →
      Al-Tawheed → Testing → Internal testing — confirm version `<TAG>` /
      build `<NEW_VERSION>` is present (CD Phase 3)

If the workflow fails, `make ci-logs` fetches the failed run's logs directly
— no need to open a browser. Common failure points are in Troubleshooting
below.

## Step 4 — (Play Store only) Promote internal → production

Not every release needs this — only do it when you're ready to push to
production on the Play Store.

CD Phase 3's `release` job already uploaded `app-release.aab` to the
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

### Failure blast radius by job — read this first

The new job graph fails in three very different ways depending on which job
breaks. Know which one you're in before you touch anything:

**`verify-android` fails => NOTHING has shipped, safe to fix and re-run.**
No secrets are even present in this job, no upload has happened, no tag or
commit exists. Fix the underlying issue (a real crash the on-device check
caught, or infra flakiness in the emulator runner) and re-run
`make release-auto` from scratch. If the check itself is the blocker and the
release is genuinely time-critical, `skip_verify=true` bypasses it — but that
is an escape hatch for infra outages, not a way to ship past a real failure
it found.

**`publish` fails partway => the release may be HALF-SHIPPED. Do NOT blindly
re-run.** `publish` does multiple non-atomic things in sequence: Play upload,
then commit+tag+push, then GitHub Release creation. If it fails after the
Play upload step but before the tag push, the AAB is live on the Play Store
**internal track** with a `versionCode` now consumed, while `origin` has no
new tag/commit for it. Before doing anything:
1. Check the Play Console **internal testing** track — is the new build
   already there?
2. Check the tag list — `git fetch --tags && git tag --sort=-creatordate | head -3`
   — does the new version's tag exist?
3. If Play has it but the tag doesn't: don't re-trigger a normal release (it
   will try to reuse the same `versionCode` and get rejected — see "Version
   code N has already been used" below). Bump `pubspec.yaml`'s `+BUILD`,
   commit, tag, and push manually to reconcile, or bump `+BUILD` and let a
   fresh `make release-auto` run produce a new tag pointing at the right code.
4. If neither Play nor the tag has it: the failure happened before any
   irreversible action — a plain re-run is safe.

**`sync-develop` fails => the release already shipped — only `develop` needs
manual fixing.** By the time `sync-develop` runs, `publish` has already
succeeded: the AAB is on Play, the tag and GitHub Release exist, the commit
is on `master`. Nothing about the *release* is broken — only merging that
commit back into `develop` failed (see the `DEVELOP_SYNC_TOKEN` entry below
for the usual cause). Do not re-trigger the release workflow; just reconcile
`develop` by hand:
```sh
git checkout develop && git merge --ff-only origin/master && git push origin develop
```

---

**"Upload to Play Store failed: 'The caller does not have permission' (403),
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

**"Release job failed at 'Commit, tag, and push': 'src refspec master does not
match any'"**
The one-click (develop-dispatched) flow checks out the promote SHA, so the
release job runs in **detached HEAD** — there is no local `master` branch. The
step must push with `git push origin HEAD:master`, not `git push origin master`.
Fixed in `flutter-release.yml` on the 2.3.0 release; if it regresses, check that
step. Note: if the Play upload already ran before this failure, that versionCode
is consumed — bump `pubspec.yaml`'s `+BUILD` before re-running (see below).

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

**"Upload failed: 'Version code N has already been used'"**
A prior run uploaded that AAB to Play (consuming versionCode N) but then failed
*after* the upload, so no tag/commit was made and a re-run recomputes the same
N. Bump `pubspec.yaml`'s `+BUILD` (e.g. `2.2.0+15` → `+16`) so the compute step
yields N+1, commit, push, and re-run.

**"Release workflow failed at 'Configure release signing': signing secrets
are not set"**
One or more of `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`,
`STORE_PASSWORD` aren't set as repo secrets yet (CD Phase 2). See
`docs/ci-cd.md` → "One-Time Setup" → "Add CD Phase 2 signing secrets" for the
exact `gh secret set` commands — run them in your terminal, never paste
secret values in chat.

**"Release workflow failed at 'Require Play Store service account': secret
is not set"**
`GOOGLE_PLAY_SERVICE_ACCOUNT` isn't set as a repo secret yet (CD Phase 3). See
`docs/ci-cd.md` → "One-Time Setup" → "Add CD Phase 3 Play Store secret".

**"`publish` failed in the Play preflight step (`tool/play_release_preflight.py`):
refusing to upload — `PLAY_FGS_MEDIA_DECLARED` is not true"**
The `PLAY_FGS_MEDIA_DECLARED` secret is unset or not `true`/`bootstrap`. This
is a required secret, not an optional one — see the pre-flight checklist and
`docs/ci-cd.md` → "One-Time Setup" → "Add the `PLAY_FGS_MEDIA_DECLARED`
secret". If Play Console hasn't surfaced the foreground-service declaration
form yet, set it to `bootstrap` for one attempt, then switch it to `true`
once you've filled in the form. Nothing has shipped at this point — this
step runs before the Play upload.

**"Release workflow failed at 'Upload to Play Store' with 'no application was
found' / track not found"**
Google requires at least one **manual** upload to a track via Play Console
before the API can publish to it. Build the AAB locally (Step 4's fallback
box), upload it to the **internal** track by hand once, then re-run
`make release-auto`.

**"Release workflow failed at 'Upload to Play Store' with 'APK/Bundle
... versionCode ... has already been used'"**
The `versionCode` (the `+BUILD` number in `pubspec.yaml`) was already used by
a release on this or another track — most likely from a manual upload that
used a higher build number than the repo's `pubspec.yaml`. Bump
`pubspec.yaml`'s `+BUILD` past whatever the highest `versionCode` is in Play
Console (Release → any track → release details), commit, push, and re-run.

**"Release workflow failed at 'Upload to Play Store' with a permission /
403 error"**
The service account in `GOOGLE_PLAY_SERVICE_ACCOUNT` doesn't have **Release
Manager** access to Al-Tawheed yet, or that access hasn't propagated. Play
Console → Users and permissions → confirm the service account's email has
Release Manager (or Admin) on this app, then re-run.

**"`release-auto` failed at `promote`: 'not possible to fast-forward'"**
`master` has diverged from `develop` — most likely someone pushed directly to
`master` outside this workflow, or `sync-develop` failed on a previous
release and was never reconciled. Use the **Fallback: manual promote**
section above to reconcile `master` and `develop` by hand (resolve the
`pubspec.yaml` version conflict, keeping the higher number), then re-run
`make release-auto`.

**"`release-auto` failed at `promote`: 'Dispatched from develop without
confirm_promote=true'"**
`make release-auto` always sets `confirm_promote=true` — if you see this, the
workflow was dispatched manually (GitHub UI or `gh workflow run`) without
checking that input. Re-run via `make release-auto`, or tick
`confirm_promote` if dispatching manually. This guard exists so an accidental
`--ref develop` dispatch can't silently ship stale code from `master`.

**"`sync-develop` failed: 'not possible to fast-forward'"**
`develop` picked up its own commits (most likely its own `pubspec.yaml`
edits) since the last sync. Reconcile by hand:
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
commit, missing the entire offline-mode feature set). The one-click flow's
`promote` job (which always fast-forwards `master` to `develop` before
`release` builds) makes this much harder to hit, but if you're using the
manual fallback and it happens anyway:
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
This was a workflow ordering bug, fixed on 2026-06-13: `flutter-release.yml`'s
"Generate changelog" step ran `git-cliff --latest` *before* the "Commit, tag,
and push" step created the new tag — so `--latest` resolved against the
still-current tag and produced ITS changelog instead of the new one. The fix
changed the arg to `--unreleased` (changelog for commits since the last tag
that aren't tagged yet), which is correct regardless of step ordering. If you
see this again after this fix, the workflow has regressed — check the
"Generate changelog" step's args first.

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

**"`make release-auto` says it must be run from develop" / "`make release`
says releases must be triggered from master"**
Each target checks `git rev-parse --abbrev-ref HEAD` and refuses to run from
the wrong branch (intentional — stops a release from being tagged off a
feature branch by accident). `make release-auto` → `git checkout develop`.
`make release` → `git checkout master && git pull origin master`.

**"Tag already exists" in the release workflow**
The version in `pubspec.yaml` wasn't bumped since the last release, or you're
re-running a workflow that already succeeded. Bump `pubspec.yaml` manually (or
choose a higher `BUMP` level) and push before re-triggering.

**"`make release` / `make release-auto` returns HTTP 403"**
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
the release bot's pushes (`promote`, `release`, `sync-develop`) would start
failing. You'd need to switch to Repository Rulesets, which do have a
bypass-actor field, and add `github-actions[bot]` to it.
