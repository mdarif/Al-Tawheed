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
| Release tooling and workflow structure | `make test-tooling` (needs PyYAML 6.0.3) | No |
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

Patrol native results are reported for 2.4.2, not treated as a release gate (owner
decision). Android 16/API 36 discovers zero Patrol tests, so it cannot produce a
meaningful native result; use a stock device or emulator below API 36. OEM-skinned
phones can make native network-toggle automation unreliable. Realistic
download and Wi-Fi-only testing is best on a physical device, because emulators
proxy the network through the host.

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

CI runs `flutter test --coverage --reporter=expanded` on every push to `develop` and
on PRs into `develop` and `master` (`flutter-ci.yml`). The 2.4.2 local snapshot
is **1780 passed, 2 skipped** from `make test`. Release tooling and workflow
structure tests (`make test-tooling`) are **175 tests**.

### 2.4.2 proof tests

- `test/overflow_smoke_test.dart`: every user-facing screen, in all four chrome
  locales, at text scale 1.0 and 2.0, on a 360x640 phone, with real Urdu and
  Arabic chapter titles. A `RenderFlex overflowed` report fails the test, and the
  message lists every overflow on the screen with its `lib/` widget.
- `test/upgrade_from_2_4_1_test.dart`: seeds the exact SharedPreferences keys and
  download layout that 2.4.1 writes, builds the 2.4.2 providers over them, tears
  them down and rebuilds them, then asserts edition, onboarding, bookmarks,
  progress, text size and downloaded-lecture records read back identically. It
  runs in `make test`. It is in-process only: it cannot prove that downloaded audio
  plays after a real process restart. That is the manual Step 1b in
  [release-runbook.md](release-runbook.md).

---

## Integration tests (`integration_test/`)

Flutter SDK `integration_test` — same `WidgetTester` API as widget tests, runs on a real device or emulator. Covers all **in-app** flows without touching native OS UI.

**Validation scenarios covered**

- Welcome → catalog → lecture list  
- Shell tabs (Lectures, Read with Book / Study when the edition has them, Library, Settings)
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

The download-notification scenario is deliberately constructed so it cannot
pass vacuously: it grants the contextual notification permission (rationale
"Allow" + the system dialog), works from the list tile only (opening the player
adds a media notification and Android 14 groups the two, hiding the download
row), throttles `.mp3` downloads (`patrol_test/support/slow_audio_downloads.dart`)
so the download is still running when the shade opens, and requires both the
lecture title (`android:id/title`) and the progress bar (`android:id/progress`)
to be visible. If the download is never observed in progress the test fails.
Details and the failure signatures: *Patrol* in [gotchas.md](gotchas.md).

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
make ci                        # format-check, test-tooling, analyze, unit/widget tests, debug APK (no device)
make release-apk DEVICE=<id>   # format-check, test-tooling, analyze, unit/widget tests, integration, Patrol, release APK
```

`make release-apk` runs `integration_test/app_test.dart`, never the screenshot
generators, then runs Patrol through `make patrol-test`. That target rejects a run
that discovers zero tests, so Android 16/API 36 cannot pass it with the current
Patrol pins. Packaging the release APK needs `android/key.properties` (see
[setup.md](setup.md)); without it, the debug build and the validation gates still
pass, but no signed artifact is produced.

For 2.4.2 the owner decided that Patrol results are reported, not a release gate.
The Makefile still includes Patrol in `release-apk`, so a local run that reaches
that step does fail on zero discovered tests. The GitHub release workflow does not
run Patrol at all.

Pre-push hook (`.githooks/pre-push`): `flutter analyze --fatal-warnings`, `flutter test`,
`make format-check` and `python3 -m unittest discover -s test/tool`. No device tests.

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

**Last updated:** 2026-10-21 (2.4.2 test state)
