# Al-Tawheed Project Setup Guide

Local development setup for the Sharah Kitab at-Tawheed Flutter app: toolchain,
signing, running, and the test commands. CI and release are in
[ci-cd.md](ci-cd.md); the release procedure is in
[release-runbook.md](release-runbook.md).

## Prerequisites

- macOS (Intel or Apple Silicon)
- Xcode and Android Studio, current versions
- Flutter SDK **3.47.4** (exact) — pinned in `pubspec.yaml` (`environment: flutter:`); CI reads the version from there (`flutter-version-file: pubspec.yaml`), so bump it in that one place
- Java 21 for Gradle (see [deployment.md](deployment.md))
- Dart SDK `>=3.0.0 <4.0.0` (set in `pubspec.yaml`; the Flutter SDK ships its own Dart)
- Python 3, with PyYAML pinned to 6.0.3, for the release tooling tests (`make test-tooling`)

## 1. Environment

### 1.1 Install Flutter 3.47.4

Install the Flutter SDK at exactly 3.47.4 by your usual method. Then:

```bash
flutter --version     # must print 3.47.4 (the same version CI reads from pubspec.yaml)
flutter doctor
```

Expect ✓ for Flutter, the Android toolchain, Xcode (on macOS) and Android Studio.

### 1.2 Install the Python test dependency

```bash
python3 -m pip install PyYAML==6.0.3
```

`make test-tooling` and the pre-push hook need it. The workflow-structure tests
fail with a clear message if it is missing.

## 2. Project setup

### 2.1 Clone and install

```bash
cd <your clone of Al-Tawheed>
make setup          # installs the pre-push hook (core.hooksPath) and runs flutter pub get
```

### 2.2 Android configuration

These come from `android/app/build.gradle`:

- `compileSdk 36`, `targetSdk 36`
- `minSdkVersion flutter.minSdkVersion`: the minimum SDK comes from the Flutter SDK,
  not from a number in this repo. Do not hard-code it.
- `applicationId "com.almarfa.tawheed"`

Java 21 is required; see [deployment.md](deployment.md).

### 2.3 Local properties

`android/local.properties` is written by Flutter from the SDK path and the
`pubspec.yaml` version. Do not edit the version there. It is gitignored. For example,
`version: 2.4.1+20` in `pubspec.yaml` gives `versionName` 2.4.1 and `versionCode` 20. If Gradle
says `flutter.sdk not set`, run the build through `flutter build apk` or
`make build-android`, not `./gradlew` directly.

### 2.4 Release signing (for release builds only)

Create `android/key.properties` (gitignored; the keystore lives in Dropbox):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=your_keystore_password
keyAlias=upload
keyPassword=your_key_password
```

Debug builds do not need it. The local release gate needs it:
`make release-apk DEVICE=<id>`.

## 3. Development

### 3.1 Run on a simulator or emulator

```bash
make run-ios                       # flutter run -d "iPhone 15 Pro"
make run-android                   # launches the emulator and runs on emulator-5554
flutter emulators                  # list what is installed
```

### 3.2 Run on a physical device

```bash
flutter devices                    # copy the device id
flutter run -d <device_id>
```

Android: enable Developer Options and USB debugging. iOS: trust the computer and
pick a signing team in Xcode (`open ios/Runner.xcworkspace`).

### 3.3 Run modes

```bash
flutter run -v                     # verbose
flutter run --profile              # profile mode (performance work)
flutter run --release
```

Hot reload is `r` in the terminal. Hot restart is `R`.

## 4. Testing

| Command | What it runs | Device |
|---|---|---|
| `make test` | `flutter test --reporter=expanded` (unit and widget tests) | no |
| `make test-tooling` | `python3 -m unittest discover -s test/tool` (release tooling and workflow structure) | no |
| `make test-goldens` | Golden (pixel) tests, macOS only | no |
| `make analyze` | `flutter analyze --fatal-warnings` | no |
| `make format-check` | `dart format --set-exit-if-changed` (no rewrite) | no |
| `make integration-test DEVICE=<id>` | `integration_test/app_test.dart` | yes |
| `make orientation-test DEVICE=<id>` | Portrait and landscape flip suite | yes |
| `make release-apk DEVICE=<id>` | The full local release gate | yes |

Run a single test file with `flutter test test/<file>_test.dart`. Coverage:
`make coverage`.

`make ci` runs format-check, test-tooling, analyze, the unit and widget tests, and
a debug APK build on this machine. See [testing.md](testing.md) for the test layers.

## 5. Package management

```bash
flutter pub outdated               # what is out of date
flutter pub get                    # install the resolved versions
flutter pub add <package>          # add a dependency
flutter pub add --dev <package>    # add a dev dependency
flutter pub remove <package>
```

Only add a dependency when a change needs it. Check `pubspec.yaml` first.

## 6. Build

| Artifact | Command |
|---|---|
| Debug APK | `make build-android` (`flutter build apk --debug`) |
| Play bundle (AAB) | `make release-android` (`flutter build appbundle --release`) |
| iOS release build | `make release-ios` (`flutter build ios --release`) |

Play Store uploads use the AAB, not an APK. The release procedure, including
signing and the release workflow, is in [release-runbook.md](release-runbook.md).

## 7. Project structure

```
Al-Tawheed/
├── lib/                 # app code: screens/, widgets/, providers/, services/, models/, l10n/
├── android/             # Android project (build.gradle, key.properties and local.properties are gitignored)
├── ios/                 # iOS project (Runner, Podfile)
├── test/                # unit and widget tests; test/tool/ holds the release-tooling tests
├── integration_test/    # on-device validation, orientation, performance, screenshots
├── patrol_test/         # Patrol native tests (airplane mode, notifications)
├── tool/                # release tooling (version, git, Play, APK verification) and CLIs
├── .github/workflows/   # CI and release workflows
├── .githooks/           # pre-push hook
├── docs/                # documentation (start at AGENTS.md)
├── pubspec.yaml         # dependencies, version, and the pinned Flutter SDK
└── assets/              # bundled fonts, images, and the Urdu book content
```

## 8. Troubleshooting

### Gradle: `invalid source release: 21`

Gradle is using an older JDK. Set `org.gradle.java.home` in
`~/.gradle/gradle.properties` (see [deployment.md](deployment.md)).

### `flutter --version` does not print 3.47.4

Switch to the pinned SDK before running anything. The CI pin is `pubspec.yaml`, and
the `flutter` on your `PATH` must match it.

### Pods fail to install on iOS

```bash
cd ios
rm -f Podfile.lock
pod install
cd ..
```

### Gradle build fails after a change in dependencies

```bash
make clean
flutter pub get
make build-android
```

### `flutter` not found in PATH

```bash
# Add to ~/.zshrc
export PATH="$PATH:/path/to/flutter/bin"
source ~/.zshrc
```

### Android SDK not found

```bash
flutter config --android-sdk /path/to/android-sdk
flutter doctor
```

### `make test-tooling` fails with "PyYAML is required"

Install the pinned version: `python3 -m pip install PyYAML==6.0.3`.

## 9. Command reference

| Command | Purpose |
|---|---|
| `make help` | Every make target with a description |
| `make setup` | Hooks plus `flutter pub get` |
| `make pub-get` | Install dependencies |
| `make analyze` | Static analysis (CI gate) |
| `make test` | Unit and widget tests |
| `make format-check` | Formatting check (CI gate) |
| `make ci` | Local approximation of CI |
| `make ci-logs` | Latest failed GitHub Actions run logs |
| `make clean` | Clean build artifacts |
| `flutter doctor` | Check the environment |

---

**Flutter version**: 3.47.4 (pinned in `pubspec.yaml`)
**Dart SDK**: `>=3.0.0 <4.0.0`
**Last updated**: 2026-10-21
