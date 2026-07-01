import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/feature_flags_provider.dart';

void main() {
  group('multiSeriesEnabled', () {
    test('defaults to false before any flags are loaded', () {
      final provider = FeatureFlagsProvider();

      expect(provider.multiSeriesEnabled, isFalse);
    });

    test('defaults to false when experimental json omits multiSeries', () {
      final provider = FeatureFlagsProvider()
        ..setExperimentalJsonForTest({'arabicTranslations': true});

      expect(provider.multiSeriesEnabled, isFalse);
    });

    test('is true only when experimental.multiSeries is explicitly true', () {
      final provider = FeatureFlagsProvider()
        ..setExperimentalJsonForTest({'multiSeries': true});

      expect(provider.multiSeriesEnabled, isTrue);
    });
  });
}
