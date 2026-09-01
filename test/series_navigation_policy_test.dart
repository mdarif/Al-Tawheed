import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/navigation/series_navigation_policy.dart';

SeriesConfig _edition({required bool book, required bool study}) =>
    SeriesConfig(
      id: 'test',
      catalogUrl: 'https://example.com/catalog.json',
      storagePrefix: 'test_',
      hasBook: book,
      hasStudyMode: study,
      language: 'en',
      displayName: const {'en': 'Test'},
      speakerName: const {'en': 'Speaker'},
    );

void main() {
  test('Library is available for every edition and Settings remains last', () {
    for (final edition in [
      _edition(book: true, study: true),
      _edition(book: true, study: false),
      _edition(book: false, study: false),
    ]) {
      final tabs = SeriesNavigationPolicy.tabsFor(edition);
      expect(tabs, contains(SeriesNavigationTab.library));
      expect(tabs.last, SeriesNavigationTab.settings);
    }
  });
}
