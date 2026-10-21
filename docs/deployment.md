# Deployment and machine setup

Machine setup, local builds, and remote content operations. This file does not
describe CI or the release pipeline.

- Release procedure: [release-runbook.md](release-runbook.md)
- CI and release machinery: [ci-cd.md](ci-cd.md)
- Branches and commits: [git-workflow.md](git-workflow.md)

---

## One-time machine setup

### Java 21 for Gradle

The project requires Java 21 (`android/app/build.gradle` compiles with 21). Android
Studio ships a suitable JDK. Point Gradle at it once:

```sh
# Add to ~/.gradle/gradle.properties (applies to ALL projects on this machine)
echo 'org.gradle.java.home=/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  >> ~/.gradle/gradle.properties
```

Without this, Gradle uses whatever Java is on `PATH`, which is often not 21. See
[gotchas.md](gotchas.md) ("Build & environment") for the global-file trap.

### Android signing (`android/key.properties`)

The upload keystore lives in Dropbox, not in git. `android/key.properties` is
gitignored and machine-specific:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<absolute path to upload-keystore.jks>
```

Without this file the `release` signing config has no store file, so
`make release-apk` and `make release-android` do not produce a Play-ready artifact.

### GitHub CLI (`gh`)

`make release` and `make ci-logs` call `gh`. Log in with the `repo` and `workflow`
scopes:

```sh
gh auth login
```

If `make release` returns HTTP 403, the token is missing the `workflow` scope.
Create a token with both scopes and pass it with `gh auth login --with-token` in
the terminal. Never paste tokens into a chat window.

### Git hooks

```sh
make setup-hooks    # activates .githooks/pre-push
```

---

## Local builds

| Artifact | Command | Output |
|---|---|---|
| Debug APK (device testing) | `make build-android` or `flutter build apk --debug` | `build/app/outputs/flutter-apk/app-debug.apk` |
| Signed release APK (local gate) | `make release-apk DEVICE=<id>` | `build/app/outputs/flutter-apk/app-release.apk` |
| Signed release APK only | `flutter build apk --release` | same path |
| Play bundle (AAB) | `make release-android` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS simulator | `flutter build ios --simulator --no-codesign` | `build/ios/iphonesimulator/Runner.app` |

A debug APK is for testing on a device. It is not a release artifact. The signed
release APK and AAB come from the release pipeline (see [ci-cd.md](ci-cd.md)) or
from the local gate in [release-runbook.md](release-runbook.md), Step 1.

`make release-apk` builds the APK but does not install it. Install it with
`adb install -r build/app/outputs/flutter-apk/app-release.apk` or
`flutter install -d <device_id>`.

**Common issue: `error: invalid source release: 21`.** Set `org.gradle.java.home`
as above.

**Common issue: app installs and crashes at launch with `ClassNotFoundException`
for `MainActivity`.** Caused by `android.builtInKotlin=true`. The project applies
the Kotlin plugin explicitly. Do not re-enable `builtInKotlin`.

### iOS simulator

```sh
flutter build ios --simulator --no-codesign
xcrun simctl list devices                                   # find a UDID
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <UDID> com.testing.tawheed
```

---

## Store screenshots

`make screenshots DEVICE=<id>` runs the capture harness on a connected device or
simulator, then frames the images with `scripts/frame_screenshots.py`. Output goes
to `docs/play-store/v3/framed/` (phone) and `docs/play-store/v3/framed-tablet/`
(tablet). This target generates assets. It is not a validation gate.

The feature graphic (1024x500) spec is in `docs/store-assets/`.

---

## Remote content (no app release needed)

Content lives in the `Al-Tawheed-Content` repository, served from Cloudflare
Pages. Edit a file, push, and Cloudflare redeploys in about a minute.

| File | Controls |
|---|---|
| `tawheed/catalog.json` | Lecture titles (all languages), chapters, daily benefits |
| `tawheed/app-config.json` | Links, contact email, share text |
| `tawheed/feature-flags.json` | Feature toggles |
| `tawheed/announcements.json` | In-app banners |

Clients cache these files, so a change can take up to about 30 minutes to reach
installed apps.

**Example: an announcement**

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

**Example: a feature flag**

```json
{ "features": { "studyMode": true } }
```

---

## Audio hosting

| Service | Purpose |
|---|---|
| Cloudflare Pages | Serves `catalog.json`, app config and announcements |
| Cloudflare R2 | Serves audio files, with HTTP Range support |

Cloudflare Pages does not return `206 Partial Content` for Range requests, so
audio must be served from R2. Check that Range requests work (seeking depends on
them):

```sh
curl -sI -H "Range: bytes=0-999" <audio URL> | grep "HTTP\|content-range"
# Expect: HTTP/1.1 206 Partial Content
```

---

## Hard-won lessons

**Commit to `develop`, not `master`.** The release workflow moves `master`. Local
commits on `master` conflict with the next release. See
[git-workflow.md](git-workflow.md).

**`android.builtInKotlin=true` breaks Kotlin compilation.** It silently skips
`MainActivity.kt`. The Kotlin plugin is applied explicitly. Do not re-enable it.

**`audio_service` on Android needs `AudioServiceActivity`.** `MainActivity` must
extend it and override `provideFlutterEngine`.

**The signing key path is machine-specific.** `storeFile` in
`android/key.properties` must match where the keystore is on this machine.

**Never paste secrets into a chat.** A token pasted there is compromised. Enter it
in the terminal.
