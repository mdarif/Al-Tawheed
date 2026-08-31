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

The runner force-stops the app between returning-user samples while retaining
app data, and verifies that the marker surface is `lectures`. Seed/select a
series once before the returning-user cohort; an unseeded install is rejected
instead of being mislabeled as returning. It clears `com.almarfa.tawheed` app data before **every**
fresh-install sample, so no sample silently becomes a returning-user run. It
captures the native logcat marker, keeps each raw drive log under
`build/cold-start/`, including raw drive and logcat logs, and prints a
median/min/max summary. Keep the cohorts and
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
