# Deployment Guide

Everything needed to build, test, release, and update the app.
Captures hard-won lessons from the v2 migration and first Play Store submission.

---

## Branching Strategy

```
master   ← production (Play Store). Force-pushes and branch deletion are blocked;
           direct merges/pushes are allowed (no PR or review required — verified
           live via `gh api .../branches/master/protection`, 2026-06-07).
develop  ← all active development. Requires the `Flutter CI` status check to pass
           before merging. Branch from here for features.
```

**Day-to-day flow:**
```sh
git checkout develop
# ... make changes, commit ...
git push origin develop        # triggers CI (analyze + test)
# when ready to release, see "Release Runbook" below
```

After a `make release`, the bot commits the version bump to master and creates a
GitHub Release with the debug APK. The signed AAB for Play Store is still built
locally (see below).

> **Note:** `master` has no PR/review requirement configured — a direct
> `git merge develop && git push origin master` works and is the normal way to
> promote a release candidate. If you want PR review enforced before production
> releases, see the note in `docs/ci-cd.md` → "Setup Status".

---

## One-time Machine Setup

### Java 21 for Gradle

The project requires Java 21. Android Studio ships it. Point Gradle to it once:

```sh
# Add to ~/.gradle/gradle.properties (applies to ALL projects on this machine)
echo 'org.gradle.java.home=/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  >> ~/.gradle/gradle.properties
```

Without this, Gradle uses whatever Java is on PATH, which often isn't 21.

### Android signing (key.properties)

The keystore lives on Dropbox, not in git. After cloning on a new machine:

```
Keystore:     /Users/mohammadarif/Library/CloudStorage/Dropbox/Al-Marfa/Al-Tawheed/Keys/upload-keystore.jks
key.properties location: android/key.properties  (gitignored)
```

Create `android/key.properties` pointing to the keystore:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/Users/mohammadarif/Library/CloudStorage/Dropbox/Al-Marfa/Al-Tawheed/Keys/upload-keystore.jks
```

### GitHub CLI auth (for `make release`)

```sh
# Needs repo + workflow scopes
gh auth login
# Select: GitHub.com → HTTPS → Login with browser
```

If `make release` returns HTTP 403, the token is missing the `workflow` scope.
Create a new PAT at github.com/settings/tokens with `repo` + `workflow` checked,
then `gh auth login --with-token` in the terminal (never paste tokens in chat).

### Git hooks

```sh
make setup-hooks    # activates .githooks/pre-push (analyze + test before every push)
```

---

## Building

### Debug APK (for device testing)

```sh
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Install on connected device:
adb install build/app/outputs/flutter-apk/app-debug.apk
```

**Common issue — Java version mismatch:**
```
error: invalid source release: 21
```
Fix: ensure `org.gradle.java.home` is set in `~/.gradle/gradle.properties` (see setup above).

**Common issue — MainActivity ClassNotFoundException:**
The app installs but crashes immediately. Caused by `android.builtInKotlin=true`
silently skipping Kotlin compilation. The fix is in `android/app/build.gradle`
(Kotlin plugin applied explicitly — already done, do not revert).

### Signed release AAB (for Play Store)

Recommended: run the full local release gate first, then build the bundle.

```sh
git checkout master && git pull origin master
make release-apk DEVICE=<device_id>   # analyze, unit, integration, patrol, release APK
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
# Requires: android/key.properties with correct storeFile path
```

Upload the `.aab` to Play Console → Production → Create new release.

### iOS Simulator build

```sh
flutter build ios --simulator --no-codesign
# Output: build/ios/iphonesimulator/Runner.app

# Install on a running simulator:
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <UDID> com.testing.tawheed
```

List available simulators: `xcrun simctl list devices`

---

## Release Runbook

Follow these steps **in order**. Each one says what to run, what success looks
like, and what to do if it doesn't go to plan — so you (or anyone else) can run
a release start to finish without guessing what comes next.

### Pre-flight checklist

- [ ] `develop` has everything you want to ship, pushed, and CI is green:
      `gh run list --branch develop --limit 1`
- [ ] No uncommitted changes anywhere you're about to switch branches from:
      `git status`
- [ ] An Android device is connected and authorized: `flutter devices`
      (required for Step 2 — the on-device test gate)

### Step 1 — Promote develop to master, and PROVE it reached GitHub

> ## ⚠️ Read this before you do anything else
> **`make release` builds from `origin/master` on GitHub — not your local
> checkout.** It runs `gh workflow run flutter-release.yml --ref master`, which
> resolves `master` against the *remote*. If your local merge hasn't been
> **pushed and confirmed**, the release workflow will silently build and ship
> whatever was already sitting on `origin/master` — possibly missing every
> feature you just spent weeks on — and **nothing will warn you**. The
> changelog will look thin, the APK will look like it built fine, and you won't
> find out until someone notices the new version doesn't actually have the new
> features (this happened on 2026-06-07: a `2.1.0` release shipped containing
> only one stray commit because the local merge was never pushed).
>
> The fix is simple — just don't trust that the merge "is done" until you've
> *verified* the remote matches local. That's what the steps below do.

```sh
git checkout master
git pull origin master
git merge develop
git push origin master
```

`master` only blocks force-pushes and branch deletions — there's **no PR or
review requirement**, so this direct merge+push is the normal flow and will not
be rejected *as long as `origin/master` hasn't drifted independently* (see the
"if the push is rejected" box below for what to do if it has).

#### Now PROVE the push landed — don't skip this

```sh
git fetch origin
git status
```

You must see **`Your branch is up to date with 'origin/master'`**. If you see
anything else — "ahead by N commits", "diverged" — **stop**. The push did not
fully land, and `make release` will build the wrong code if you proceed. Belt
and suspenders, also run:

```sh
git log origin/master..HEAD --oneline
```

This must print **nothing**. Any commit listed here is a commit that exists
locally but not on GitHub — exactly the gap that caused the 2026-06-07 incident.

> #### If the push is rejected ("non-fast-forward" / branches have diverged)
> This means someone (or some automation — e.g. a previous `make release` run,
> or a commit pushed straight to master outside the normal `develop` flow) has
> added commits to `origin/master` that your local branch doesn't have.
> **Do not force-push.** Instead:
> ```sh
> git merge origin/master    # bring the remote commits into your local branch
> # resolve any conflicts (commonly just the `version:` line in pubspec.yaml —
> # keep whichever number is higher, since that's the one already public)
> git push origin master
> git fetch origin && git status   # re-verify "up to date" before continuing
> ```
> (`develop` is the only branch that's actually gated in CI — it requires the
> `Flutter CI` status check before anything merges into it. `master` has no
> such gate, which is exactly why it's possible for stray commits to land there
> without anyone noticing — be deliberate about what you push to it.)

### Step 2 — Run the local release gate

```sh
make release-apk DEVICE=<device_id>
```

This runs, in order: `pub get` → `flutter analyze --fatal-warnings` →
`flutter test` (unit/widget) → `flutter test integration_test/` (on-device,
~1 min) → `patrol test` (on-device native scenarios — airplane mode,
notifications, lock-screen controls) → `flutter build apk --release`.

**Success looks like** the final line:
```
✓ Release APK: build/app/outputs/flutter-apk/app-release.apk
```

That APK is a **properly signed production build** — `flutter build apk
--release` uses `android/key.properties`, which points at the real
`upload-keystore.jks` (see "Android signing" above). You can confirm the signer:
```sh
$ANDROID_SDK/build-tools/<version>/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
# Expect: Signer #1 certificate DN: CN=Al Marfa Duroos, OU=Development, ...
```

> **`make release-apk` only *builds* the APK — it does not install it on your
> device.** That's expected; the gate's job is to prove the build is correct
> and shippable, not to deploy it. If you want it on your phone to do a final
> manual smoke test before the public release, install it explicitly:
> ```sh
> flutter install -d <device_id>
> # or, equivalently:
> adb install -r build/app/outputs/flutter-apk/app-release.apk
> ```
> Then open the app and walk through a lecture or two — playback, downloads,
> lock-screen controls — before moving on to Step 3.

**If any phase of the gate fails:** fix it on `develop` (not on `master` —
see "Hard-Won Lessons" below), push, wait for CI to go green, then start over
from Step 1 (re-merge `develop` into `master`, re-run the gate). Don't proceed
to Step 3 with a failing gate — it's the thing standing between you and
shipping a broken build.

### Step 3 — Trigger the automated release

#### One more guard before you press the button

Minutes or hours may have passed since Step 1's verification — re-run it now,
immediately before triggering, so there's no gap for drift to sneak in:

```sh
git fetch origin && git status
# must say: "Your branch is up to date with 'origin/master'"
git log origin/master..HEAD --oneline
# must print nothing
```

If either check is off, go back to Step 1's "PROVE the push landed" box —
**do not run `make release` until both come back clean.** This is the exact
check that would have caught the 2026-06-07 incident before it shipped.

```sh
make release BUMP=patch     # bug fixes only            → 2.0.2 → 2.0.3
make release BUMP=minor     # new user-facing features  → 2.0.2 → 2.1.0
make release BUMP=major     # breaking changes          → 2.0.2 → 3.0.0
```

Must be run from `master` (the Makefile target checks this and refuses
otherwise). Watch it run:
```sh
gh run watch
# or open: https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml
```

The workflow (`flutter-release.yml`):
1. Computes the new version and guards against re-using an existing tag
2. Bumps `pubspec.yaml`
3. Re-runs analyze + tests (it will refuse to tag a broken build even if your
   local gate passed — different machine, same checks)
4. Builds a **debug-signed** APK (CD Phase 2 — CI-side production signing —
   isn't wired up yet; that's why Step 2's locally-built, properly-signed APK
   is the one to actually distribute if you need a signed artifact)
5. Commits the version bump to `master`, tags it, pushes both
6. Creates a GitHub Release with the APK attached and an auto-generated changelog

### Step 4 — Verify the release actually shipped

- [ ] New tag exists: `git fetch --tags && git tag --sort=-creatordate | head -3`
- [ ] New release is live: `gh release view --web` (or
      `github.com/mdarif/Al-Tawheed/releases`) — check the changelog reads
      sensibly and the APK is attached and downloadable
- [ ] Sync your local master with the bot's commit + tag:
      `git pull origin master --tags`
- [ ] (Optional) Download and install the release-workflow APK on a second
      device to confirm the artifact GitHub published actually launches.
      Remember it's debug-signed (not the production-signed build from
      Step 2) — it's a good traceability/smoke-test artifact, not something
      to hand to end users or upload to the Play Store.

If the workflow fails, `make ci-logs` fetches the failed run's logs directly —
no need to open a browser. Common failure points are covered in
"Troubleshooting" in `docs/ci-cd.md`.

### Step 5 — (Only for a Play Store push) Build the signed AAB and submit

Not every release needs this — only do it when you're ready to push to
production on the Play Store.

```sh
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
# Requires: android/key.properties with the correct storeFile path (see above)
```

1. play.google.com/console → Al-Tawheed → Production → Create new release
2. Upload `app-release.aab`
3. Fill in release notes ("What's new")
4. If you see an "Advertising ID" error → click **"Release without permission"**
   (the app has no ads)
5. Review → Start rollout to Production (or save as a draft first)

### Step 6 — Sync the version bump back into develop (close out the release)

**Don't skip this** — the release workflow commits `chore: release X.Y.Z`
(the `pubspec.yaml` version + build-number bump) directly to `master`, and
nothing brings it back to `develop` automatically. Skip it and `develop`'s
`pubspec.yaml` stays one version behind `master`'s — which means the *next*
release's `git merge develop` (Step 1) will hit a `version:` line conflict in
`pubspec.yaml` that you'll have to resolve by hand under release-day pressure.
This is the last thing you do — once it's done, the release is fully closed
out and `develop` is ready for the next cycle. It's a 30-second no-conflict
fast-forward while the bump is still fresh:

```sh
git checkout develop
git pull origin develop
git merge --ff-only master
git push origin develop
```

**What you should see, step by step:**

- `git checkout develop` — switches branches. If you're *already* on `develop`,
  Git just says so; that's fine, continue.
- `git pull origin develop` — make sure your local `develop` matches the
  remote before merging anything into it.
- `git merge --ff-only master` — this is the actual sync. In the normal case
  (nobody has committed anything to `develop` since the last time it was
  promoted to `master`), `develop` is sitting exactly at the merge-base with
  `master`, so this is a **fast-forward**: Git just slides the `develop`
  pointer up to `master`'s tip — no merge commit, linear history, and the
  output is literally `Fast-forward` (or `Already up to date` if `develop`
  somehow already has everything — also fine, nothing left to do, just
  continue to the push/verify below).
  - We deliberately use `--ff-only` instead of a plain `git merge master` —
    it *guarantees* you get a fast-forward-or-nothing. If `develop` has picked
    up its own commits since the last promotion (so a clean fast-forward isn't
    possible), `--ff-only` **refuses and exits cleanly** instead of silently
    creating a merge commit or a conflict mid-flight. See the recovery box
    below for what to do if that happens.
- `git push origin develop` — pushes the synced commits to GitHub. **Don't
  skip this** — `git merge` only updates your *local* `develop`; until you
  push, `origin/develop` is still behind and `git branch -vv` will show your
  local `develop` as `ahead N` of `origin/develop`.

#### Now verify the push landed (same discipline as Step 1)

```sh
git fetch origin
git status
# must say: "Your branch is up to date with 'origin/develop'"
```

If it says "ahead by N commits" instead, the push didn't go through (or you
forgot to run it) — run `git push origin develop` again and re-check.

#### If `--ff-only` refuses ("Not possible to fast-forward, aborting")

This means `develop` picked up commits of its own (most likely its own
`pubspec.yaml` edits) since the last time it was promoted to `master` — a
true three-way merge is needed, and a `version:` conflict is the most likely
outcome:

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

## Release Scenarios & Troubleshooting

**🔴 "The release's changelog only shows one or two commits, but I shipped way
more than that" — your release shipped the WRONG CODE, fix it immediately**
This is not a cosmetic changelog problem — it means `make release` built from
`origin/master` *before* your local merge reached it (see the giant warning box
in Step 1). The published APK is missing your actual changes. **Treat this as a
shipped-bug incident, not a docs nitpick** — this exact thing happened on
2026-06-07 (a `2.1.0` release went out containing only a stray "Add Play Store
assets" commit, missing the entire offline-mode feature set). To recover:
1. Confirm the gap: `git log <bad-release-tag>..<your-local-master> --oneline`
   — if this lists your real commits, the release is missing them
2. Reconcile the branches (see "if the push is rejected" in Step 1 — you'll
   likely need `git merge origin/master`, resolve the `pubspec.yaml` version
   conflict, then push)
3. Decide what to do with the bad release/tag — editing its notes to point at
   the corrected version is the least destructive option; deleting it
   (`gh release delete <tag> --yes && git push origin :refs/tags/<tag>`) is
   more thorough but rewrites public history
4. Re-run Step 1's verification (`git fetch origin && git status` must say
   "up to date"), *then* trigger a fresh release — it'll bump past the bad
   tag automatically since the version comes from `pubspec.yaml`, not from
   which tags exist

**"The integration test failed during `make release-apk` with
`Found 0 widgets with text "START LISTENING"`"**
This means the Flutter widget tree never finished building before the test's
30s wait expired — usually because something blocked `runApp()` during cold
start (e.g. a native permission dialog being awaited synchronously in
`main()`). It is *not* a flaky-timing issue you can fix by waiting longer in
the test. Check `lib/main.dart` for anything `await`ed before `runApp()` that
could show native UI (permission requests, platform channel calls that wait on
user interaction), and make sure those are fired without blocking startup.

**"`make release` says releases must be triggered from master"**
You're not on `master`. `git checkout master && git pull origin master` first
— the Makefile target checks `git rev-parse --abbrev-ref HEAD` and refuses to
run from any other branch (this is intentional — it stops you from tagging a
release off a feature branch by accident).

**"Tag already exists" in the release workflow**
The version in `pubspec.yaml` wasn't bumped since the last release, or you're
re-running a workflow that already succeeded. Bump `pubspec.yaml` manually (or
choose a higher `BUMP` level) and push before re-triggering.

**"`make release` returns HTTP 403"**
Your `gh` token is missing the `workflow` scope — see "GitHub CLI auth" above.

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

---

## Content Updates (No App Release Needed)

All content lives in the `Al-Tawheed-Content` GitHub repo, deployed to
Cloudflare Pages. Edit files → push → Cloudflare redeploys in ~60s.

| File | Controls |
|---|---|
| `tawheed/catalog.json` | Lecture titles (all languages), chapters, daily benefits |
| `tawheed/app-config.json` | Links, contact email, share text |
| `tawheed/feature-flags.json` | Toggle features on/off remotely |
| `tawheed/announcements.json` | In-app banners |

**Example — add an announcement:**
```json
{
  "announcements": [
    {
      "id": "ann-002",
      "type": "info",
      "title": { "en": "New Feature", "ur": "نئی سہولت" },
      "body":  { "en": "Study Mode is now available.", "ur": "تعلیمی طریقہ اب دستیاب ہے۔" },
      "ctaLabel": null, "ctaUrl": null,
      "validFrom": "2026-06-01T00:00:00Z",
      "validUntil": "2026-12-31T00:00:00Z",
      "platforms": ["android", "ios"]
    }
  ]
}
```
Push to main → live within 30 minutes (cache TTL).

**Example — enable a feature flag:**
```json
{ "features": { "studyMode": true } }
```

---

## Taking Play Store Screenshots

Screenshots are saved in `docs/play-store/`.

### Automated via Flutter

```sh
flutter run -d <UDID>    # start the app on a simulator
```

Then in a separate terminal:
```sh
flutter screenshot --out /tmp/screen.png
```

Navigate through screens manually, call `flutter screenshot` for each.

### Wrapping in device frames

A Python script is used to add iPhone/iPad frames:

```sh
python3 -m venv /tmp/imgenv && /tmp/imgenv/bin/pip install Pillow arabic-reshaper python-bidi
```

Then run the framing script (see session history — generates framed PNGs at ~1662×3185).

### Feature graphic (1024×500)

Generated by the same Python environment using Pillow.
Source: `docs/store-assets/feature-graphic-spec.md`
Output: `docs/store-assets/play-store-feature-graphic-1024x500.png`

---

## CI Pipeline

GitHub Actions runs on every push to `develop`, `master`, and PRs into both:

1. Java 21 setup
2. Flutter stable
3. Gradle + pub cache
4. `flutter pub get`
5. `flutter analyze --fatal-warnings`
6. `flutter test --reporter=expanded`
7. `flutter build apk --debug`
8. Upload APK artifact (7-day retention)

Local equivalent: `make ci`

On-device tests (integration + Patrol) are **not** in CI yet — run locally before release:

```sh
make integration-test DEVICE=<device_id>
make patrol-test DEVICE=<device_id>    # optional native scenarios
make release-apk DEVICE=<device_id>    # full gate: tests + integration + patrol + release APK
```

See `docs/testing.md` for full test documentation.

Check latest CI run: `make ci-logs`

---

## Audio / Content Infrastructure

| Service | URL | Purpose |
|---|---|---|
| Cloudflare Pages | `al-tawheed-content.pages.dev` | Serves `catalog.json`, config, announcements |
| Cloudflare R2 | `pub-8a0d3971e9fd4d7c991d2300ca9bdca5.r2.dev` | Serves audio MP3s (Range requests) |

Audio files: 50 MP3s, ~390 MB total, `lec-001.mp3` → `lec-050.mp3`

**Verify Range requests work (required for audio seeking):**
```sh
curl -sI -H "Range: bytes=0-999" \
  https://pub-8a0d3971e9fd4d7c991d2300ca9bdca5.r2.dev/lec-001.mp3 \
  | grep "HTTP\|content-range"
# Expect: HTTP/1.1 206 Partial Content
```

---

## Useful Commands

```sh
make help              # all available make targets
make ci                # run CI pipeline locally (analyze + unit/widget + debug APK)
make ci-logs           # fetch latest failed GitHub Actions run
make release BUMP=patch # trigger automated GitHub release workflow
make setup-hooks       # install pre-push git hook

# On-device testing (network + real device/emulator required)
make integration-test DEVICE=<device_id>
make patrol-test DEVICE=<device_id>
make release-apk DEVICE=<device_id>

flutter devices        # list connected devices/simulators
flutter run -d <UDID>  # run on specific device
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
flutter test --reporter=expanded
flutter test integration_test/ -d <device_id> --timeout 15m
patrol test -t patrol_test/native_test.dart --timeout 10m
flutter analyze --fatal-warnings

adb devices                                         # list Android devices
adb install build/app/outputs/flutter-apk/app-debug.apk
xcrun simctl list devices                           # list iOS simulators
```

---

## Key Files

| File | Purpose |
|---|---|
| `android/key.properties` | Signing config — gitignored, machine-specific |
| `android/local.properties` | SDK paths — gitignored, machine-specific |
| `~/.gradle/gradle.properties` | User-level Gradle config (Java home override) |
| `lib/app_config.dart` | All remote content URLs and version constants |
| `Al-Tawheed-Content/tawheed/` | All remotely-managed content |
| `docs/ci-cd.md` | CI/CD pipeline reference |
| `docs/testing.md` | Unit, integration, and Patrol test guide |
| `docs/i18n-architecture.md` | Multilingual architecture (ADR-003) |
| `docs/remote-content-strategy.md` | Remote content strategy (ADR-002) |

---

## Hard-Won Lessons

**Don't work directly on master.**
The release workflow commits to master. If you have uncommitted local changes on
master, merge conflicts happen on the next release. Always work on develop.

**Branch protection vs release bot — only matters if you turn PR review back on.**
Right now `master` has no PR/review requirement, so the release bot's
version-bump push just goes through. *If* you ever add "Require a pull request
before merging" to `master` (e.g. to gate Play Store releases more tightly),
know that classic branch protection rules have no bypass-actor field — the bot's
push would then fail. You'd need to switch to Repository Rulesets, which do have
a bypass-actor field, and add `github-actions[bot]` to it.

**`android.builtInKotlin=true` breaks Kotlin compilation.**
This flag (added by Flutter's migrator) silently skips compiling `MainActivity.kt`,
causing `ClassNotFoundException` at launch. The project now applies the Kotlin plugin
explicitly and `builtInKotlin` is commented out. Do not re-enable it.

**audio_service on Android requires `AudioServiceActivity`.**
`MainActivity` must extend `AudioServiceActivity` (not plain `FlutterActivity`) and
override `provideFlutterEngine` so the audio plugin can locate the FlutterEngine.

**Cloudflare Pages does not support HTTP Range requests.**
Audio files served from Pages return `200` for range requests (not `206`). All audio
must be served from Cloudflare R2, which does support Range requests natively.

**Signing key path is machine-specific.**
`android/key.properties` → `storeFile` must match the actual keystore location on
the current machine. The keystore lives on Dropbox and the path changes per machine.
Update `storeFile` in `key.properties` locally after cloning on a new machine.

**Never paste secrets in Claude Code chat.**
GitHub PATs exposed in the conversation are immediately compromised. Always paste
tokens directly in the terminal, never in the chat window.
