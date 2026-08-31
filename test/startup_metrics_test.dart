import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/startup_measurement.dart';

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
        StartupMeasurement.tryParse('--------- beginning of main'),
        isNull,
      );
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

    test('batch parser rejects malformed, wrong, and missing samples', () {
      const valid = 'I/TawheedStartup: COLD_START_INTERACTIVE cohort=returning '
          'surface=lectures elapsed_ms=100';
      const wrongCohort =
          'I/TawheedStartup: COLD_START_INTERACTIVE cohort=fresh-install '
          'surface=lectures elapsed_ms=100';
      const wrongSurface =
          'I/TawheedStartup: COLD_START_INTERACTIVE cohort=returning '
          'surface=welcome elapsed_ms=100';
      const malformed =
          'I/TawheedStartup: COLD_START_INTERACTIVE surface=lectures';

      expect(
        StartupMeasurement.parseBatch(
          [valid, valid, valid],
          cohort: 'returning',
          surface: 'lectures',
          expectedCount: 3,
        ),
        hasLength(3),
      );
      for (final lines in [
        [valid, malformed, valid],
        [wrongCohort, valid, valid],
        [wrongSurface, valid, valid],
        [valid, valid],
        [valid, valid, valid, valid],
      ]) {
        expect(
          () => StartupMeasurement.parseBatch(
            lines,
            cohort: 'returning',
            surface: 'lectures',
            expectedCount: 3,
          ),
          throwsFormatException,
        );
      }
    });
  });
}
