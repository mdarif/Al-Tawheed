# Deployment Guide

Everything needed to set up your machine, build, and update the app.
Captures hard-won lessons from the v2 migration and first Play Store submission.

> For the step-by-step production release process, see
> [release-runbook.md](release-runbook.md).

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
# when ready to release, see docs/release-runbook.md
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

```sh
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
# Requires: android/key.properties with correct storeFile path
```

For the full release process (local gate, tagging, Play Store submission),
see [release-runbook.md](release-runbook.md).

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
| `docs/release-runbook.md` | Step-by-step production release process |
| `docs/ci-cd.md` | CI/CD pipeline reference |
| `docs/testing.md` | Unit, integration, and Patrol test guide |
| `docs/i18n-architecture.md` | Multilingual architecture (ADR-003) |
| `docs/remote-content-strategy.md` | Remote content strategy (ADR-002) |

---

## Hard-Won Lessons

**Don't work directly on master.**
The release workflow commits to master. If you have uncommitted local changes on
master, merge conflicts happen on the next release. Always work on develop.

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
