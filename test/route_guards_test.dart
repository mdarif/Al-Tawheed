import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/navigation/route_guards.dart';
import 'package:myapp/navigation/series_navigation_policy.dart';

/// The redirect matrix for `lib/app.dart`. `app.dart` itself has no test — the
/// `AudioService` singleton makes `MyApp` unmountable in the test harness — so
/// before this file every routing decision (does a deep link into /read on the
/// minimal-audio-only edition open, or bounce?) shipped unguarded.
SeriesConfig _series({required bool hasBook, required bool hasStudyMode}) =>
    SeriesConfig(
      id: 'test',
      catalogUrl: 'https://example.com/catalog.json',
      storagePrefix: 't_',
      hasStudyMode: hasStudyMode,
      hasBook: hasBook,
      language: 'en',
      displayName: const {'en': 'Test'},
      speakerName: const {'en': 'Speaker'},
    );

void main() {
  group('RouteGuards.read (/read)', () {
    test('allows the route when the series bundles a book', () {
      final series = _series(hasBook: true, hasStudyMode: false);
      expect(RouteGuards.read(series), isNull);
    });

    test('allows the route when the series has study mode alone', () {
      final series = _series(hasBook: false, hasStudyMode: true);
      expect(RouteGuards.read(series), isNull);
    });

    test('bounces to /lectures when the series has neither', () {
      final series = _series(hasBook: false, hasStudyMode: false);
      expect(RouteGuards.read(series), '/lectures');
    });
  });

  group('RouteGuards.welcome (/)', () {
    test('shows the welcome screen (no redirect) for a first-run series', () {
      expect(RouteGuards.welcome(shouldShowWelcome: true), isNull);
    });

    test('sends a returning user straight to /lectures', () {
      expect(RouteGuards.welcome(shouldShowWelcome: false), '/lectures');
    });
  });

  // /read keys off hasBook OR hasStudyMode — the real Arabic edition (book,
  // no study) and Urdu edition (both) must each land on the same tab.
  group('the shipped editions land correctly', () {
    test('Arabic edition: /read opens (book, no study)', () {
      const arabic = SeriesConfig(
        id: 'tawheed-ar',
        catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
        storagePrefix: 'ar_',
        hasStudyMode: false,
        hasBook: true,
        language: 'ar',
        displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
        speakerName: {'en': 'Shaikh Salih al-Fawzan'},
      );
      expect(RouteGuards.read(arabic), isNull);
    });

    test('Urdu edition: /read opens (book and study)', () {
      const urdu = SeriesConfig.legacyUrduFallback;
      expect(RouteGuards.read(urdu), isNull);
    });

    test('guards mirror the shared local capability policy', () {
      const arabic = SeriesConfig(
        id: 'tawheed-ar',
        catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
        storagePrefix: 'ar_',
        hasStudyMode: false,
        hasBook: true,
        language: 'ar',
        displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
        speakerName: {'en': 'Shaikh Salih al-Fawzan'},
      );
      const editions = <SeriesConfig>[SeriesConfig.legacyUrduFallback, arabic];

      for (final series in editions) {
        final tabs = SeriesNavigationPolicy.tabsFor(series);
        expect(
          RouteGuards.read(series),
          tabs.contains(SeriesNavigationTab.read) ? isNull : '/lectures',
        );
      }

      expect(SeriesNavigationPolicy.tabsFor(SeriesConfig.legacyUrduFallback), [
        SeriesNavigationTab.lectures,
        SeriesNavigationTab.read,
        SeriesNavigationTab.library,
        SeriesNavigationTab.settings,
      ]);
      expect(SeriesNavigationPolicy.tabsFor(arabic), [
        SeriesNavigationTab.lectures,
        SeriesNavigationTab.read,
        SeriesNavigationTab.library,
        SeriesNavigationTab.settings,
      ]);

      final minimal = _series(hasBook: false, hasStudyMode: false);
      expect(SeriesNavigationPolicy.tabsFor(minimal), [
        SeriesNavigationTab.lectures,
        SeriesNavigationTab.library,
        SeriesNavigationTab.settings,
      ]);
    });
  });
}
