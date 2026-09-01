import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/utils/performance_thresholds.dart';
import 'package:myapp/utils/startup_metrics.dart';

import 'package:myapp/widgets/lecture_tile.dart';
import 'support/app_flow.dart';

/// On-device frame-timing benchmarks. Run in **profile** mode on a real device
/// — debug build times are inflated and a simulator's raster times are
/// meaningless:
///
///   `flutter drive --driver=test_driver/perf_driver.dart \`
///   `  --target=integration_test/performance_test.dart --profile -d DEVICE`
///   (or: `make perf-test DEVICE=...`)
///
/// `make perf-smoke DEVICE=...` runs the same scenarios with
/// `PERF_ENFORCE_THRESHOLDS=false` for emulator/harness validation. It still
/// requires nonempty frame timings and executes every scenario, but is not a
/// physical-device regression gate.
///
/// Each scenario collects `FrameTiming`s directly via `addTimingsCallback`
/// while a scroll/animation runs. (NOT `watchPerformance`/`traceAction`: those
/// open a VM-service socket to enable the Dart timeline, which isn't reachable
/// over `flutter drive` on a physical device — it fails with
/// `SocketException: Connection refused localhost`. Frame-timing callbacks need
/// no such connection.) We log the numbers so a run is readable at a glance.
/// Strict runs assert a **generous** ceiling — a regression net for egregious
/// jank, not a micro-benchmark that flaps between devices. A 60Hz frame is
/// 16.7ms; the ceilings sit well above it so a healthy physical build passes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const coldStartCohort = String.fromEnvironment(
    'COLD_START_COHORT',
    defaultValue: 'unspecified',
  );
  const coldStartOnly = bool.fromEnvironment(
    'COLD_START_ONLY',
    defaultValue: false,
  );
  const enforceThresholds = bool.fromEnvironment(
    'PERF_ENFORCE_THRESHOLDS',
    defaultValue: true,
  );
  const seedReturning = bool.fromEnvironment(
    'COLD_START_SETUP_RETURNING',
    defaultValue: false,
  );

  // Generous: ~2 frames of build headroom, ~2.5 of raster. Real profile
  // numbers on a mid device sit far under this; only real jank trips it.
  const maxAvgBuildMillis = 32.0;
  const maxAvgRasterMillis = 40.0;
  const frameBudgetMillis = 1000.0 / 60.0; // 16.67ms

  // Bounded pumps, never pumpAndSettle: the lecture list and reader carry
  // continuous animations (progress spinners, the continue-listening banner)
  // that never settle, so pumpAndSettle would wait its full 10-minute timeout
  // and hang. This is why AppFlow uses bounded pumps everywhere. Driving a
  // fixed span of frames also captures exactly the active fling — the window
  // we want to measure.
  Future<void> pumpFor(WidgetTester tester, int frames) async {
    for (var f = 0; f < frames; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> flingRepeatedly(
    WidgetTester tester,
    Finder scrollable, {
    required Offset delta,
    int times = 6,
  }) async {
    for (var i = 0; i < times; i++) {
      await tester.fling(scrollable, delta, 3500);
      await pumpFor(tester, 15);
    }
  }

  /// Runs [action] while accumulating the engine's per-frame build + raster
  /// timings, then logs a PERF line and asserts the jank ceiling.
  Future<void> measure(
    WidgetTester tester,
    String key,
    Future<void> Function() action,
  ) async {
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(collect);

    await action();
    // Frame timings arrive a beat after the frames rasterize — pump once more
    // so the last batch is delivered before we stop listening.
    await tester.pump(const Duration(milliseconds: 200));
    SchedulerBinding.instance.removeTimingsCallback(collect);

    expect(
      timings,
      isNotEmpty,
      reason: 'no frames captured for "$key" — run --profile on a real device',
    );

    double ms(Duration d) => d.inMicroseconds / 1000.0;
    final build = timings.map((t) => ms(t.buildDuration)).toList()..sort();
    final raster = timings.map((t) => ms(t.rasterDuration)).toList()..sort();
    double avg(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    double p90(List<double> xs) =>
        xs[(xs.length * 0.9).floor().clamp(0, xs.length - 1)];
    int missed(List<double> xs) =>
        xs.where((x) => x > frameBudgetMillis).length;

    // ignore: avoid_print
    print('PERF[$key] frames=${timings.length}  '
        'build avg=${avg(build).toStringAsFixed(1)} '
        'p90=${p90(build).toStringAsFixed(1)} '
        'worst=${build.last.toStringAsFixed(1)} missed=${missed(build)}  |  '
        'raster avg=${avg(raster).toStringAsFixed(1)} '
        'p90=${p90(raster).toStringAsFixed(1)} '
        'worst=${raster.last.toStringAsFixed(1)} missed=${missed(raster)}');

    expect(
      PerformanceThresholds.passes(
        averageMillis: avg(build),
        ceilingMillis: maxAvgBuildMillis,
        enforce: enforceThresholds,
      ),
      isTrue,
      reason: '$key: average frame BUILD time too high — UI thread jank',
    );
    expect(
      PerformanceThresholds.passes(
        averageMillis: avg(raster),
        ceilingMillis: maxAvgRasterMillis,
        enforce: enforceThresholds,
      ),
      isTrue,
      reason: '$key: average frame RASTER time too high — GPU jank',
    );
  }

  testWidgets('reader + lists hold their frame budget', (tester) async {
    // This is set before app.main() so the native marker includes the cohort
    // label. The clock itself began when startup_metrics.dart loaded, before
    // plugin/provider initialization.
    StartupMetrics.setCohortForTest(coldStartCohort);
    await AppFlow.launchApp(tester);
    if (seedReturning) {
      // This setup build is run only by the returning-user harness. It drives
      // the real onboarding flow once so a reinstall or empty emulator still
      // has a deterministic lectures landing state before measurement.
      await AppFlow.goToLectureList(tester);
      return;
    }
    final startup = await AppFlow.waitForStartupInteractive(tester);
    // Keep a line in the Flutter driver output for local runs. The automated
    // cold-start runner consumes the Android logcat line emitted by MainActivity,
    // whose elapsed time starts at Activity.onCreate rather than app.main().
    // ignore: avoid_print
    print(startup.machineLine);
    if (coldStartOnly) return;
    await AppFlow.goToLectureList(tester);
    await AppFlow.waitForCatalog(tester);
    expect(find.byType(LectureTile), findsWidgets);

    // ── 1. Lecture list (the long, image-bearing list) ──────────────────────
    final listScroll = find.byType(Scrollable).first;
    await measure(tester, 'lecture_list_scroll', () async {
      await flingRepeatedly(tester, listScroll, delta: const Offset(0, -400));
      await flingRepeatedly(tester, listScroll, delta: const Offset(0, 400));
    });

    // ── 2. Book reader — Nastaliq scroll + page turns ───────────────────────
    // Only when the edition has a Book tab in this environment.
    if (await AppFlow.navigateToReadTab(tester)) {
      // Open the first chapter (a chapter row pushes /book/<id>).
      await tester.tap(find.byType(InkWell).first);
      await AppFlow.pumpFrames(tester, count: 8);

      final readerScroll = find.byType(Scrollable).first;
      await measure(tester, 'book_reader_scroll', () async {
        await flingRepeatedly(
          tester,
          readerScroll,
          delta: const Offset(0, -500),
        );
        await flingRepeatedly(
          tester,
          readerScroll,
          delta: const Offset(0, 500),
        );
      });

      // Page turns — swipe the pager across a few chapters and back. A
      // left→right fling advances (RTL reading order).
      final pager = find.byType(PageView);
      if (tester.any(pager)) {
        await measure(tester, 'book_page_turn', () async {
          for (var i = 0; i < 4; i++) {
            await tester.fling(pager, const Offset(500, 0), 2000);
            await pumpFor(tester, 20); // ~320ms — the page transition
          }
          for (var i = 0; i < 4; i++) {
            await tester.fling(pager, const Offset(-500, 0), 2000);
            await pumpFor(tester, 20);
          }
        });
      }
    }
  });
}
