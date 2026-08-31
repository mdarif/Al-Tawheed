# Testing Guide — Al-Tawheed

Three layers: **unit/widget** (CI, fast), **integration_test** (Flutter UI on device), **Patrol** (native OS interactions on device).

For *what is missing* rather than how to run what exists, see
**[test-plan.md](test-plan.md)** — a ranked gap backlog grounded in the bugs that
have actually shipped here.

---

## Quick reference

| Layer | Command | Needs device |
|-------|---------|--------------|
| Unit + widget | `flutter test` or `make test` | No |
| Integration validation (Flutter UI) | `make integration-test DEVICE=<id>` | Yes |
| Screenshot asset generation | `make screenshots DEVICE=<id>` | Yes |
| Patrol (native OS) | `make patrol-test DEVICE=<id>` | Yes |
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

The automated stock Android API 35 emulator run currently reports five passing
scenarios, zero failures, and one intentional skip. For final confidence,
verify Patrol's native automator features on a physical stock-Android device
when available. Android 16/API 36 currently reports zero discovered tests and
cannot satisfy the truthful Patrol gate. OEM-skinned phones can still make
native network-toggle automation unreliable. Realistic download/Wi-Fi-only
testing is best on a physical device because emulators proxy network through
the host.

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

CI runs the same command on every push/PR (`flutter-ci.yml`). The current local
snapshot is 582 passing unit/widget tests with two intentional skips.

---

## Integration tests (`integration_test/`)

Flutter SDK `integration_test` — same `WidgetTester` API as widget tests, runs on a real device or emulator. Covers all **in-app** flows without touching native OS UI.

**Validation scenarios covered**

- Welcome → catalog → lecture list  
- Shell tabs (Lectures, Book/Study when available, Settings)
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

`integration_test/app_test.dart` is the validation gate. `make screenshots`
invokes the phone capture harness (`screenshots_test.dart`) only; the framing
step derives both phone and tablet aspect assets. `screenshots_tablet_test.dart`
is not invoked by that target and neither capture file is validation.

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
# 1. Patrol CLI (once per machine; this exact version matches pubspec.yaml)
dart pub global activate patrol_cli 4.4.0

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
# The release-gate wrapper captures output and rejects Total: 0.
make patrol-test
make patrol-test DEVICE=<device_id>
```

For exploratory debugging you can invoke `patrol test` directly, but use
`make patrol-test` when deciding whether the native gate passed.

The app pins `patrol: ^4.6.1`; Patrol's compatibility check requires
`patrol_cli 4.4.0`. The native command is a release-gate check, not merely a
build check: it fails if Patrol reports `Total: 0`. On Android 16/API 36,
Patrol 4.4.0 currently builds and starts instrumentation but discovers zero
tests, so that device cannot produce a green native gate. Use a stock Android
target below API 36 (the API 34 emulator is suitable), or deliberately treat
the native scenarios as a separately documented manual check while keeping
the Flutter validation gate green. CLI 4.5.1 refuses the 4.6.1 package and is
not a workaround.

> `patrol test` has **no `--timeout` CLI flag** (only `--web-timeout`/`--web-global-timeout` for web runs — passing `--timeout` errors with `Could not find an option named "--timeout"`). The 10-minute per-test timeout is already set in code via `timeout: patrolTimeout` in `patrol_test/support/patrol_flow.dart`.

Patrol generates `patrol_test/test_bundle.dart` locally (gitignored).

### Airplane-mode fallback on Android 35 and OEM variants

On devices running custom Android skins (OnePlus OxygenOS, Oppo/Realme ColorOS, Samsung One UI, Xiaomi MIUI, etc.), `$.platform.mobile.enableAirplaneMode()` can fail with the suite showing the native step turn red ❌, e.g.:

```
✅ isPermissionDialogVisible (native)
✅ grantPermissionWhenInUse (native)
❌ enableAirplaneMode (native)
✅ disableAirplaneMode (native)
```

**Why**: Patrol's native automator drives the stock/AOSP Settings UI to find and tap the airplane-mode toggle. Android 35 images can omit the Quick Settings tile, and OEM skins can relocate or rename the control, so the lookup may return 404 even on a healthy device.

`PatrolFlow.withAirplaneMode` handles the known Android 404/missing-toggle
failure by disabling both Wi-Fi and cellular through Patrol, then restoring
both transports in `finally`. Unrelated native failures still fail the test;
the fallback does not skip or weaken the offline assertions. If an OEM blocks
both mechanisms, validate on a stock API 35 AVD or a real Pixel:

```bash
flutter emulators --launch flutter_emulator        # use a stock API 35 AVD
flutter devices                                     # copy the emulator-XXXX id
patrol test -t patrol_test/native_test.dart --device emulator-XXXX
```

A real Pixel device works too. If both native toggle paths fail on an OEM-skinned phone, treat the three airplane-mode-dependent scenarios as manual checks on that device and keep the stock-emulator gate as the automated evidence.

---

## Local CI mirror

```bash
make ci                  # analyze + unit/widget tests + debug APK (no device)
make release-apk DEVICE=<id>   # format + tooling + validation + discovered Patrol gate + APK
```

`make release-apk` runs `integration_test/app_test.dart`, never the screenshot
generators, then runs Patrol and requires at least one discovered test. A
successful process with `Total: 0` is intentionally rejected; Android 16/API
36 therefore cannot satisfy this release gate with the current Patrol pins.
The local release APK packaging step additionally requires the signing
`storeFile`; without that local keystore, debug APK builds and the preceding
validation gates can still pass, but a signed release artifact cannot be made.

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
