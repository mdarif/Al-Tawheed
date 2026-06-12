# Release Runbook

Step-by-step guide for cutting a production release: promote `develop` →
`master`, run the local gate, trigger the automated release, and (optionally)
submit to the Play Store.

For initial machine setup (signing keys, Java, `gh` auth) and general build
commands, see [deployment.md](deployment.md).

Follow these steps **in order** — each one says what to run, what success
looks like, and what to do if it doesn't go to plan.

## Pre-flight checklist

- [ ] `develop` has everything you want to ship, pushed, and CI is green:
      `gh run list --branch develop --limit 1`
- [ ] No uncommitted changes anywhere you're about to switch branches from:
      `git status`
- [ ] An Android device is connected and authorized: `flutter devices`
      (required for Step 2 — the on-device test gate)

## Step 1 — Promote develop to master, and prove it reached GitHub

> ## ⚠️ Read this before you do anything else
> **`make release` builds from `origin/master` on GitHub, not your local
> checkout** (`gh workflow run flutter-release.yml --ref master` resolves
> against the remote). If your merge isn't pushed and confirmed, the release
> workflow silently ships whatever was already on `origin/master` — and
> nothing warns you. This happened on 2026-06-07: a `2.1.0` release shipped
> containing only one stray commit because the local merge was never pushed.
> The fix: don't trust "the merge is done" until you've *verified* the remote
> matches local — that's what this step does.

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
Any commit listed by `git log` exists locally but not on GitHub: exactly the
gap that caused the 2026-06-07 incident.

> #### If the push is rejected ("non-fast-forward" / branches have diverged)
> Something added commits to `origin/master` that your local branch doesn't
> have (e.g. a previous `make release` run, or a direct push outside the
> normal `develop` flow). **Do not force-push.** Instead:
> ```sh
> git merge origin/master    # bring the remote commits into your local branch
> # resolve any conflicts (commonly the `version:` line in pubspec.yaml —
> # keep whichever number is higher, since that's the one already public)
> git push origin master
> git fetch origin && git status   # re-verify "up to date" before continuing
> ```
> Only `develop` is gated in CI (requires the `Flutter CI` check) — `master`
> has no such gate, so stray commits can land there unnoticed. Be deliberate
> about what you push to it.

## Step 2 — Run the local release gate

```sh
make release-apk DEVICE=<device_id>
```

Runs, in order: `pub get` → `flutter analyze --fatal-warnings` →
`flutter test` (unit/widget) → `flutter test integration_test/` (on-device,
~1 min) → `patrol test` (on-device native scenarios — airplane mode,
notifications, lock-screen controls) → `flutter build apk --release`.

**Success** looks like the final line:
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
> lock-screen controls — before Step 3.

**If any phase fails:** fix it on `develop` (not `master`), push, wait for CI
to go green, then restart from Step 1. Don't proceed to Step 3 with a failing
gate — it's the thing standing between you and shipping a broken build.

## Step 3 — Trigger the automated release

Re-run Step 1's verification now — drift can happen between steps:
```sh
git fetch origin && git status         # must say "up to date with origin/master"
git log origin/master..HEAD --oneline  # must print nothing
```
If either check is off, go back to Step 1 — **do not run `make release`**
until both come back clean.

```sh
make release BUMP=patch     # bug fixes only            → 2.0.2 → 2.0.3
make release BUMP=minor     # new user-facing features  → 2.0.2 → 2.1.0
make release BUMP=major     # breaking changes          → 2.0.2 → 3.0.0
```

Must be run from `master` (the Makefile target checks this and refuses
otherwise). Watch it run:
```sh
gh run watch
# or: https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml
```

The workflow (`flutter-release.yml`):
1. Computes the new version and guards against re-using an existing tag
2. Bumps `pubspec.yaml`
3. Re-runs analyze + tests (refuses to tag a broken build even if Step 2 passed
   — different machine, same checks)
4. Builds a **debug-signed** APK (CD Phase 2 — CI-side production signing
   isn't wired up yet; Step 2's locally-built APK is the one to distribute)
5. Commits the version bump to `master`, tags it, pushes both
6. Creates a GitHub Release with the APK attached and an auto-generated
   changelog

## Step 4 — Verify the release actually shipped

- [ ] New tag exists: `git fetch --tags && git tag --sort=-creatordate | head -3`
- [ ] New release is live: `gh release view --web` — check the changelog
      describes THIS release's commits (compare against
      `git log <previous-tag>..<new-tag> --oneline` if anything looks like it
      could be from a previous release — see Troubleshooting below) and the
      APK is attached and downloadable
- [ ] Sync your local master: `git pull origin master --tags`
- [ ] (Optional) Install the release-workflow APK on a second device to
      confirm it launches. It's debug-signed (not Step 2's build) — a
      smoke-test artifact, not for end users or the Play Store.

If the workflow fails, `make ci-logs` fetches the failed run's logs directly
— no need to open a browser. Common failure points are in `docs/ci-cd.md` →
"Troubleshooting".

## Step 5 — (Play Store only) Build the signed AAB and submit

Not every release needs this — only do it when you're ready to push to
production on the Play Store.

```sh
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
# Requires: android/key.properties with the correct storeFile path
```

1. play.google.com/console → Al-Tawheed → Production → Create new release
2. Upload `app-release.aab`
3. Fill in release notes ("What's new")
4. If you see an "Advertising ID" error → click **"Release without
   permission"** (the app has no ads)
5. Review → Start rollout to Production (or save as a draft first)

## Step 6 — Sync the version bump back into develop (close out the release)

**Don't skip this** — the release workflow commits `chore: release X.Y.Z`
(the `pubspec.yaml` version + build-number bump) directly to `master`, and
nothing brings it back to `develop` automatically. Skip it and the *next*
release's `git merge develop` (Step 1) will hit a `version:` conflict in
`pubspec.yaml` that you'll have to resolve under release-day pressure. It's a
30-second no-conflict fast-forward while the bump is still fresh:

```sh
git checkout develop
git pull origin develop
git merge --ff-only master
git push origin develop
```

In the normal case (nobody committed to `develop` since the last promotion),
`--ff-only` just slides the `develop` pointer up to `master`'s tip — no merge
commit, output is `Fast-forward` (or `Already up to date`, also fine, nothing
left to do). We use `--ff-only` instead of a plain merge so it refuses cleanly
instead of silently creating a merge commit or conflict if `develop` has
picked up commits of its own — see the recovery box below if that happens.

Verify the push landed:
```sh
git fetch origin && git status
# must say: "Your branch is up to date with 'origin/develop'"
```
If it says "ahead by N commits", the push didn't go through — run
`git push origin develop` again and re-check.

#### If `--ff-only` refuses ("Not possible to fast-forward, aborting")

`develop` picked up its own commits (most likely its own `pubspec.yaml`
edits) since the last promotion — a true three-way merge is needed, and a
`version:` conflict is the most likely outcome:

```sh
git merge master
# resolve the `version:` conflict in pubspec.yaml — keep the HIGHER of the
# two numbers, since that's the one already public on master / tagged in
# the release
git add pubspec.yaml
git commit
git push origin develop
```

---

## Troubleshooting

**🔴 "The release's changelog only shows one or two commits, but I shipped
way more than that"** — your release shipped the **wrong code**, fix it
immediately. This is the failure mode Step 1's warning exists to prevent (it
happened for real on 2026-06-07 — a `2.1.0` release went out containing only a
stray "Add Play Store assets" commit, missing the entire offline-mode feature
set). To recover:
1. Confirm the gap: `git log <bad-release-tag>..<your-local-master> --oneline`
   — if this lists your real commits, the release is missing them
2. Reconcile the branches (see Step 1's "if the push is rejected" box —
   you'll likely need `git merge origin/master`, resolve the `pubspec.yaml`
   version conflict, then push)
3. Decide what to do with the bad release/tag — editing its notes to point at
   the corrected version is the least destructive option; deleting it
   (`gh release delete <tag> --yes && git push origin :refs/tags/<tag>`) is
   more thorough but rewrites public history
4. Re-run Step 1's verification (must say "up to date"), *then* trigger a
   fresh release — it'll bump past the bad tag automatically since the
   version comes from `pubspec.yaml`, not which tags exist

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

**"`make release` says releases must be triggered from master"**
You're not on `master`. `git checkout master && git pull origin master` first
— the Makefile target checks `git rev-parse --abbrev-ref HEAD` and refuses to
run from any other branch (intentional — stops a release from being tagged off
a feature branch by accident).

**"Tag already exists" in the release workflow**
The version in `pubspec.yaml` wasn't bumped since the last release, or you're
re-running a workflow that already succeeded. Bump `pubspec.yaml` manually (or
choose a higher `BUMP` level) and push before re-triggering.

**"`make release` returns HTTP 403"**
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
the release bot's version-bump push (Step 3) would start failing. You'd need
to switch to Repository Rulesets, which do have a bypass-actor field, and add
`github-actions[bot]` to it.
