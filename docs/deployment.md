# Deployment Guide

Everything needed to build, test, release, and update the app.
Captures hard-won lessons from the v2 migration and first Play Store submission.

---

## Branching Strategy

```
master   ← production (Play Store). Direct pushes blocked except by release bot.
develop  ← all active development. Branch from here for features.
```

**Day-to-day flow:**
```sh
git checkout develop
# ... make changes, commit ...
git push origin develop        # triggers CI (analyze + test)
# when ready to release:
make release BUMP=patch        # or minor / major
```

After a `make release`, the bot commits the version bump to master and creates a
GitHub Release with the debug APK. The signed AAB for Play Store is still built
locally (see below).

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

```sh
git checkout master && git pull origin master
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

## Releasing

### Automated release via `make release`

```sh
make release BUMP=patch    # 2.0.2 → 2.0.3
make release BUMP=minor    # 2.0.2 → 2.1.0
make release BUMP=major    # 2.0.2 → 3.0.0
```

The release workflow (`flutter-release.yml`) does:
1. Bumps version in `pubspec.yaml`
2. Runs analyze + tests
3. Builds debug APK
4. Commits version bump to master
5. Tags the commit
6. Creates GitHub Release with APK attached

**Requires:**
- GitHub token with `workflow` scope (`gh auth login`)
- Master branch must allow the bot to push directly

**Branch protection issue:**
If master requires PRs, the version-bump commit push fails. Fix:
- **Temporary:** Settings → Branches → master → disable "Require a pull request"
  and "Require status checks" → run release → re-enable both
- **Permanent:** Settings → Rules → Rulesets → add bypass actor `github-actions[bot]`

### Play Store submission (after building AAB)

1. play.google.com/console → Al-Tawheed → Production → Create new release
2. Upload `app-release.aab`
3. Fill in release notes ("What's new")
4. If you see "Advertising ID" error → click **"Release without permission"** (app has no ads)
5. Review → Start rollout to Production (or save as draft first)

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
4. `flutter analyze --fatal-warnings`
5. `flutter test --reporter=expanded`
6. `flutter build apk --debug`
7. Upload APK artifact (7-day retention)

Local equivalent: `make ci`

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
make ci                # run full CI pipeline locally
make ci-logs           # fetch latest failed GitHub Actions run
make release BUMP=patch # trigger automated release
make setup-hooks       # install pre-push git hook

flutter devices        # list connected devices/simulators
flutter run -d <UDID>  # run on specific device
flutter build apk --debug
flutter build appbundle --release
flutter test --reporter=expanded
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
| `docs/i18n-architecture.md` | Multilingual architecture (ADR-003) |
| `docs/remote-content-strategy.md` | Remote content strategy (ADR-002) |

---

## Hard-Won Lessons

**Don't work directly on master.**
The release workflow commits to master. If you have uncommitted local changes on
master, merge conflicts happen on the next release. Always work on develop.

**Branch protection vs release bot.**
The release workflow needs to push a version-bump commit to master. Classic branch
protection rules have no bypass list — you must temporarily relax them or switch to
Repository Rulesets (which has a bypass actor field for `github-actions[bot]`).

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
