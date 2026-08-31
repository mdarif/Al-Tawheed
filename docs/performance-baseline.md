# Performance baseline

Status: the baseline is pending a physical-device profile-mode run. No
measured values are recorded in this repository yet. The ceilings in
`integration_test/performance_test.dart` are regression limits, not baseline
measurements.

## Frame-timing procedure

Run the existing frame harness on the same physical device and build variant
for every comparison:

```sh
flutter devices
make perf-test DEVICE=<physical-device-id>
```

`make perf-test` is the strict physical-device regression gate; its
`PERF_ENFORCE_THRESHOLDS` compile-time default is `true`. For emulator or
harness smoke validation, use `make perf-smoke DEVICE=<android-emulator-id>`.
Smoke mode executes every scenario and requires nonempty timing data, but does
not fail on device-sensitive build/raster ceilings and must not be recorded as
the physical baseline.

The command uses `flutter drive --profile` and prints one `PERF[...]` line for
each scenario (`lecture_list_scroll`, `book_reader_scroll`, and, when the
selected edition has a Book, `book_page_turn`). Repeat each run three times
without changing the device, display refresh rate, power mode, or network
conditions. Record the median run; also retain the raw output as an artifact.
Do not use debug mode or a simulator for the baseline. The test's existing
average build/raster ceilings remain the pass/fail guard while the baseline is
being collected.

### Results

| Device / OS | App commit | Run date | Scenario | Frames | Build avg / p90 / worst (ms) | Raster avg / p90 / worst (ms) | Missed build / raster |
|---|---|---|---|---:|---|---|---|
| **pending physical profile run** | — | — | `lecture_list_scroll` | — | — | — | — |
| **pending physical profile run** | — | — | `book_reader_scroll` | — | — | — | — |
| **pending physical profile run** | — | — | `book_page_turn` | — | — | — | — |

The Book scenarios may be absent when the selected edition has no Book. The
performance harness does not measure Study Mode; do not record a Study result
under this baseline until a dedicated Study interaction is instrumented.

## Cold-start-to-interactive measurement

`performance_test.dart` emits a stable `COLD_START_INTERACTIVE` marker. On
Android, `MainActivity` records `SystemClock.elapsedRealtime()` in
`onCreate()` and logs the duration when the marker's first painted, interactive
landing surface appears (`welcome` for a fresh install, `lectures` for a
returning user). This avoids treating `am start -W`'s Activity `TotalTime` as
Flutter readiness.

Use the automated Android profile-mode runner for a cohort:

```sh
make cold-start-test DEVICE=<android-emulator-or-device> \
  COLD_START_COHORT=returning COLD_START_SAMPLES=3
make cold-start-test DEVICE=<android-emulator-or-device> \
  COLD_START_COHORT=fresh-install COLD_START_SAMPLES=3
```

Each sample is bounded by `COLD_START_TIMEOUT_SECONDS` (180 seconds by
default; override it when invoking `make`). On Android 13 and newer the runner
pre-grants `POST_NOTIFICATIONS` after state preparation, so the system
permission dialog cannot cover the app before its interactive marker. A grant
failure is fatal; only pre-Android-13 devices, where this permission does not
exist, skip the grant.

The runner builds `integration_test/performance_test.dart` in profile mode with
the cohort and cold-start defines, installs that exact APK, and passes it to
`flutter drive` with `--use-application-binary`. In the returning cohort it
first runs a separate setup build through the real onboarding/catalog flow,
then rebuilds and installs the measured APK in place. An APK signature
mismatch is fatal; the runner never uninstalls the app to hide lost state.
`flutter drive` is given `--keep-app-running`; the runner force-stops the app
itself after each marker (and on failure/timeout) so drive cleanup cannot
remove the measured APK.

The runner force-stops the app between returning-user samples while retaining
app data, and verifies that the marker surface is `lectures`. Its separate
returning setup build seeds/selects a series through the real onboarding flow,
so an empty install is prepared automatically rather than mislabeled as
returning. It clears `com.almarfa.tawheed` app data before **every**
fresh-install sample, so no sample silently becomes a returning-user run. It
captures the native logcat marker, keeps raw drive and logcat logs under
`build/cold-start/`, and prints a median/min/max summary. Keep the cohorts and
their summaries separate; never combine them into one startup number.

For a manual physical profile-mode run, use the same cohort rules and fill the
pending fields below:

1. Install the profile build on a physical device. For Android, use package
   `com.almarfa.tawheed` and launch activity
   `com.almarfa.tawheed/.MainActivity`.
2. Use separate returning-user (cached `/lectures`) and fresh-install
   (welcome) cohorts; never mix them in one number.
3. For a returning-user run, force-stop the app between samples while
   preserving app data. For a fresh-install run, clear app data before
   **each** sample. Keep the same catalog/cache and network conditions within
   a cohort.
4. Start timing at Activity `onCreate` and stop at the native logcat marker.
   Collect at least three launches after one warm-up. Record median and
   min/max, plus device, OS, refresh rate, app commit, profile build type,
   cohort, and network/cache state.

Do not substitute `adb shell am start -W`'s Activity `TotalTime` for the
marker: it ends at an Android lifecycle milestone, not Flutter interactive
content. Until the marker and a physical run exist, the measured fields stay
explicitly pending:

| Cohort | Device / OS | App commit | Run date | Samples | Cold start → interactive (median / min / max ms) |
|---|---|---|---|---:|---|
| Returning user (cached) | **pending** | **pending** | **pending** | **pending** | **pending** |
| Fresh install (welcome) | **pending** | **pending** | **pending** | **pending** | **pending** |

The final P5 gate remains human/device-gated: measured thresholds must be
reviewed from a profile-mode physical run rather than inferred from these
source-level limits.
