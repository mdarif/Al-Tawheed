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

## Devices — simulator/emulator vs real device

Both `integration_test` and Patrol need a running device — either a simulator/emulator or a physical phone. Either works; pick whichever is faster to set up for your platform.

### List what's available

```bash
flutter devices              # currently running/connected devices (use this ID with -d / DEVICE=)
flutter emulators            # installed emulators/simulators you can launch
```

### Android emulator

```bash
flutter emulators --launch <emulator_id>     # e.g. flutter emulators --launch flutter_emulator
# or, once it's booted:
flutter devices                              # copy the emulator-XXXX id
make integration-test DEVICE=emulator-5554
```

`flutter emulators --create` makes a new AVD if none of the listed ones suit you (e.g. you need a specific API level for `POST_NOTIFICATIONS` / Android 13+ behaviour).

### iOS Simulator (macOS only)

```bash
open -a Simulator                                   # launches the last-used simulator
# or pick a specific device:
xcrun simctl list devices available                 # find a device UDID, e.g. "iPhone 17 (4398...)"
xcrun simctl boot <device_udid>
flutter devices                                      # copy the simulator id once booted
make integration-test DEVICE=<simulator_id>
```

`flutter emulators --launch apple_ios_simulator` also works and boots the default simulator.

### Real device

1. **Android** — enable Developer Options → USB debugging, plug in via USB (or pair over Wi-Fi with `adb pair`), accept the "Allow USB debugging" prompt on the device.
2. **iOS** — plug in via USB/network, trust the computer on the device, and make sure the device is registered to a signing team in Xcode (`open ios/Runner.xcworkspace` → Signing & Capabilities).
3. Confirm it shows up: `flutter devices`, then use its ID with `-d` / `DEVICE=`.

Real devices are **required** (not optional) for:
- Patrol's native automator features — airplane mode toggling and the notification shade are unreliable or unsupported on emulators/simulators in our experience; always verify these on a physical phone before trusting a green run.
- Realistic download/Wi-Fi-only testing — emulators proxy network through the host, which can mask real connectivity-state transitions.

### Network

The catalog and lecture audio are fetched from a remote CDN — **the device needs real internet access** for `waitForCatalog` to succeed and for download scenarios to complete. Emulators use the host machine's network by default; real devices need Wi-Fi or mobile data.

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
patrol test -t patrol_test/native_test.dart
# specific device
patrol test -t patrol_test/native_test.dart --device <device_id>
# or
make patrol-test
make patrol-test DEVICE=<device_id>
```

> `patrol test` has **no `--timeout` CLI flag** (only `--web-timeout`/`--web-global-timeout` for web runs — passing `--timeout` errors with `Could not find an option named "--timeout"`). The 10-minute per-test timeout is already set in code via `timeout: patrolTimeout` in `patrol_test/support/patrol_flow.dart`.

Patrol generates `patrol_test/test_bundle.dart` locally (gitignored).

### Known issue — `enableAirplaneMode` fails on heavily-skinned OEM Android

On devices running custom Android skins (OnePlus OxygenOS, Oppo/Realme ColorOS, Samsung One UI, Xiaomi MIUI, etc.), `$.platform.mobile.enableAirplaneMode()` can fail with the suite showing the native step turn red ❌, e.g.:

```
✅ isPermissionDialogVisible (native)
✅ grantPermissionWhenInUse (native)
❌ enableAirplaneMode (native)
✅ disableAirplaneMode (native)
```

**Why**: Patrol's native automator drives the stock/AOSP Settings UI to find and tap the airplane-mode toggle. OEM skins restyle and relocate that screen (different layout, resource IDs, labels), so the automator opens "Wireless & networks" but can't locate the toggle and times out. `disableAirplaneMode` then "passes" trivially because airplane mode was never actually turned on. The phone isn't frozen — the step genuinely can't find the UI element it's looking for. `patrol: ^4.6.1` is the latest release on pub.dev as of writing, so this isn't fixed by upgrading.

**Workaround**: run the native suite against a closer-to-stock Android target instead — e.g. one of the Pixel-profile AVDs already available locally:

```bash
flutter emulators --launch flutter_emulator        # or Medium_Phone_API_36.1
flutter devices                                     # copy the emulator-XXXX id
patrol test -t patrol_test/native_test.dart --device emulator-XXXX
```

A real Pixel device works too. If you must validate on an OEM-skinned phone, treat the airplane-mode-dependent scenarios (`shows offline banner...`, `shows snackbar when tapping undownloaded lecture offline`, `blocks skip-next offline...`) as **manual** checks on that device rather than relying on the automated native step.

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
