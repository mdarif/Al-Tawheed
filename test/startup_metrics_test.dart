import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/startup_metrics.dart';

void main() {
  group('StartupMeasurement', () {
    test('parses Dart and logcat marker lines', () {
      expect(
        StartupMeasurement.tryParse(
          'COLD_START_INTERACTIVE cohort=fresh-install '
          'surface=welcome elapsed_ms=241',
        ),
        isA<StartupMeasurement>()
            .having((m) => m.cohort, 'cohort', 'fresh-install')
            .having((m) => m.surface, 'surface', 'welcome')
            .having((m) => m.elapsedMillis, 'elapsed', 241),
      );

      expect(
        StartupMeasurement.tryParse(
          '08-31 10:00:00.000 I/TawheedStartup: '
          'COLD_START_INTERACTIVE cohort=returning surface=lectures '
          'elapsed_ms=98',
        ),
        isA<StartupMeasurement>()
            .having((m) => m.cohort, 'cohort', 'returning')
            .having((m) => m.surface, 'surface', 'lectures')
            .having((m) => m.elapsedMillis, 'elapsed', 98),
      );
    });

    test('rejects malformed or negative measurements', () {
      expect(StartupMeasurement.tryParse('ordinary log line'), isNull);
      expect(
        StartupMeasurement.tryParse(
          'COLD_START_INTERACTIVE surface=welcome elapsed_ms=-1',
        ),
        isNull,
      );
      expect(
        StartupMeasurement.tryParse(
          'COLD_START_INTERACTIVE cohort=fresh surface=welcome elapsed_ms=nope',
        ),
        isNull,
      );
    });

    test('computes a median without fabricating a sample', () {
      final samples = [
        const StartupMeasurement(
          cohort: 'returning',
          surface: 'lectures',
          elapsedMillis: 300,
        ),
        const StartupMeasurement(
          cohort: 'returning',
          surface: 'lectures',
          elapsedMillis: 100,
        ),
        const StartupMeasurement(
          cohort: 'returning',
          surface: 'lectures',
          elapsedMillis: 200,
        ),
      ];
      expect(StartupMeasurement.medianMillis(samples), 200);
      expect(
        () => StartupMeasurement.medianMillis(const []),
        throwsArgumentError,
      );
    });
  });

  testWidgets('interactive marker records after its first painted frame',
      (tester) async {
    StartupMetrics.resetForTest();
    await tester.pumpWidget(
      MaterialApp(
        home: StartupInteractiveMarker(
          surface: 'welcome',
          child: const Scaffold(body: Text('ready')),
        ),
      ),
    );

    expect(StartupMetrics.measurement?.surface, 'welcome');
    final first = StartupMetrics.measurement;
    await tester.pump();
    expect(StartupMetrics.measurement, same(first));
  });
}
