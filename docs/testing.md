# Testing Guide — Al-Tawheed

Three layers: **unit/widget** (CI, fast), **integration_test** (Flutter UI on device), **Patrol** (native OS interactions on device).

---

## Quick reference

| Layer | Command | Needs device |
|-------|---------|--------------|
| Unit + widget | `flutter test` or `make test` | No |
| Integration (Flutter UI) | `make integration-test DEVICE=<id>` | Yes |
| Patrol (native OS) | `make patrol-test` or `patrol test -t patrol_test/native_test.dart` | Yes |
| Full local release gate | `make release-apk DEVICE=<id>` | Yes |

List devices: `flutter devices`

---

## Unit and widget tests

```bash
flutter test --reporter=expanded
# or
make test
```

Coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html   # macOS, requires lcov
open coverage/html/index.html
```

CI runs the same command on every push/PR (`flutter-ci.yml`).

---

## Integration tests (`integration_test/`)

Flutter SDK `integration_test` — same `WidgetTester` API as widget tests, runs on a real device or emulator. Covers all **in-app** flows without touching native OS UI.

**Scenarios covered**

- Welcome → catalog → lecture list  
- Shell tabs (Home, Settings, Lectures)  
- Player + mini player  
- Offline sheet, download, local playback  
- Offline library (sheet + Settings)  
- List-tile download / cancel  

**Run**

```bash
flutter test integration_test/app_test.dart -d <device_id> --timeout 15m
# or
make integration-test DEVICE=<device_id>
```

**Notes**

- One sequential `testWidgets` per file (multiple tests reset the widget tree and hang).  
- Do **not** use `pumpAndSettle` while audio is playing — helpers use fixed `pump` loops.  
- Network required on first launch (catalog fetch).  

**Out of scope here** → see Patrol below.

---

## Patrol tests (`patrol_test/`)

[Patrol](https://patrol.leancode.co) extends `integration_test` with a native automator (airplane mode, notification shade, permission dialogs).

### One-time setup

```bash
# 1. Patrol CLI (once per machine)
dart pub global activate patrol_cli

# 2. Add pub global bin to PATH (required — otherwise: command not found: patrol)
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc

# 3. Dependencies (already in pubspec.yaml)
flutter pub get

# 4. Verify Android/iOS native wiring
patrol doctor
```

**Android** — configured in `android/app/build.gradle`:

- `PatrolJUnitRunner`  
- `MainActivityTest.java` under `android/app/src/androidTest/`  

**iOS** — requires a **RunnerUITests** UI test target in Xcode:

1. Open `ios/Runner.xcworkspace`  
2. File → New → Target → **UI Testing Bundle** → name `RunnerUITests`  
3. Replace generated `.m` file with `ios/RunnerUITests/RunnerUITests.m`  
4. Run `patrol doctor` until iOS checks pass  

### Scenarios covered (`patrol_test/native_test.dart`)

| Test | Native capability |
|------|-------------------|
| Offline banner | Airplane mode → **Offline** shell banner |
| Undownloaded lecture offline | Airplane mode → snackbar on tap |
| Skip-next blocked | Airplane mode → **Not available offline** dialog |
| Download notification (Android) | Notification shade while download in progress |

### Run

```bash
patrol test -t patrol_test/native_test.dart --timeout 10m
# specific device
patrol test -t patrol_test/native_test.dart --device <device_id> --timeout 10m
# or
make patrol-test
make patrol-test DEVICE=<device_id>
```

Patrol generates `patrol_test/test_bundle.dart` locally (gitignored).

---

## Local CI mirror

```bash
make ci                  # analyze + unit/widget tests + debug APK (no device)
make release-apk DEVICE=<id>   # full gate before Play Store upload
```

Pre-push hook (`.githooks/pre-push`): `flutter analyze` + `flutter test` — no device tests.

---

## Debugging

```bash
flutter test --verbose
flutter test --name "partial test name"
patrol test -t patrol_test/native_test.dart --verbose
patrol develop -t patrol_test/native_test.dart   # hot restart while writing tests
```

---

## Resources

- [Flutter testing](https://docs.flutter.dev/testing)  
- [Integration tests](https://docs.flutter.dev/testing/integration-tests)  
- [Patrol documentation](https://patrol.leancode.co/documentation)  

**Last updated:** June 2026
