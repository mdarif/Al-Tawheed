import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/performance_thresholds.dart';

void main() {
  test('enforced thresholds pass averages below the ceiling', () {
    expect(
      PerformanceThresholds.passes(
        averageMillis: 20,
        ceilingMillis: 32,
        enforce: true,
      ),
      isTrue,
    );
  });

  test('enforced thresholds reject averages at or above the ceiling', () {
    expect(
      PerformanceThresholds.passes(
        averageMillis: 32,
        ceilingMillis: 32,
        enforce: true,
      ),
      isFalse,
    );
    expect(
      PerformanceThresholds.passes(
        averageMillis: 40,
        ceilingMillis: 32,
        enforce: true,
      ),
      isFalse,
    );
  });

  test('smoke mode accepts device-sensitive averages', () {
    expect(
      PerformanceThresholds.passes(
        averageMillis: 40,
        ceilingMillis: 32,
        enforce: false,
      ),
      isTrue,
    );
  });
}
