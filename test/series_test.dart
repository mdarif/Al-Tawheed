import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';

void main() {
  group('SeriesConfig.fromJson — hasBook', () {
    test('defaults to false when omitted', () {
      final series = SeriesConfig.fromJson({
        'id': 'tawheed-ur',
        'catalogUrl': 'https://example.com/catalog.json',
      });

      expect(series.hasBook, isFalse);
    });

    test('parses true from JSON', () {
      final series = SeriesConfig.fromJson({
        'id': 'tawheed-ar',
        'catalogUrl': 'https://example.com/catalog.json',
        'hasBook': true,
      });

      expect(series.hasBook, isTrue);
    });
  });

  test('legacyUrduFallback has no book', () {
    expect(SeriesConfig.legacyUrduFallback.hasBook, isFalse);
  });

  group('SeriesConfig.fromJson — required fields', () {
    test('throws when id is missing or empty', () {
      expect(
        () => SeriesConfig.fromJson({'catalogUrl': 'https://x/c.json'}),
        throwsFormatException,
      );
      expect(
        () => SeriesConfig.fromJson({'id': '', 'catalogUrl': 'https://x/c.json'}),
        throwsFormatException,
      );
    });

    test('throws when catalogUrl is missing', () {
      expect(
        () => SeriesConfig.fromJson({'id': 'tawheed-ur'}),
        throwsFormatException,
      );
    });
  });
}
