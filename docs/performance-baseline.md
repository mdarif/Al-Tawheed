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

The Book scenarios may be absent when the selected edition has no Book. Run a
second profile session with the Urdu edition when both Book and Study are
needed for comparison.

## Cold-start-to-interactive measurement

`performance_test.dart` intentionally does not report a cold-start duration.
The integration test starts after the Flutter test process is already alive,
and `AppFlow.launchApp` waits on either onboarding or a catalog-backed lecture
tile. That endpoint changes with persisted onboarding state, manifest/catalog
cache state, and network latency. A stopwatch around `app.main()` would
therefore measure initialization of the test isolate, not a repeatable
user-visible cold start. The existing frame-timing harness is left unchanged.

When a stable first-interactive marker is added, use this physical profile-mode
protocol and fill the pending fields below:

1. Install the profile build on a physical device. For Android, use package
   `com.almarfa.tawheed` and launch activity
   `com.almarfa.tawheed/.MainActivity`.
2. Define the marker before collecting numbers: the first frame in which the
   intended landing surface is painted and accepts input. Use separate
   returning-user (cached `/lectures`) and fresh-install (welcome) cohorts;
   never mix them in one number.
3. For a returning-user run, force-stop the app between samples while
   preserving app data. For a fresh-install run, clear app data once before
   the cohort, then repeat force-stop launches without clearing it. Keep the
   same catalog/cache and network conditions within a cohort.
4. Start timing immediately before the OS launch command, stop at the marker,
   and collect at least three launches after one warm-up. Record median and
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
