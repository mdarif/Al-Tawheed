import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';

void main() {
  group('SeriesConfig.fromJson — hasBook', () {
    test('the Urdu series defaults to true (ships a bundled book)', () {
      final series = SeriesConfig.fromJson({
        'id': 'tawheed-ur',
        'catalogUrl': 'https://example.com/catalog.json',
      });

      expect(series.hasBook, isTrue);
    });

    test('other series default to false when hasBook is omitted', () {
      final series = SeriesConfig.fromJson({
        'id': 'tawheed-hi',
        'catalogUrl': 'https://example.com/catalog.json',
      });

      expect(series.hasBook, isFalse);
    });

    test('an explicit hasBook:false in the manifest wins for Urdu', () {
      final series = SeriesConfig.fromJson({
        'id': 'tawheed-ur',
        'catalogUrl': 'https://example.com/catalog.json',
        'hasBook': false,
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

  test('legacyUrduFallback ships a book (Urdu Book tab)', () {
    expect(SeriesConfig.legacyUrduFallback.hasBook, isTrue);
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
