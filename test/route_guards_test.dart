import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/navigation/route_guards.dart';

/// The redirect matrix for `lib/app.dart`. `app.dart` itself has no test — the
/// `AudioService` singleton makes `MyApp` unmountable in the test harness — so
/// before this file every routing decision (does a deep link into /book on the
/// Arabic-only-book edition open, or bounce?) shipped unguarded.
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
  group('RouteGuards.book (/book)', () {
    test('allows the route when the series bundles a book', () {
      final series = _series(hasBook: true, hasStudyMode: false);
      expect(RouteGuards.book(series), isNull);
    });

    test('bounces to /lectures when the series has no book', () {
      final series = _series(hasBook: false, hasStudyMode: true);
      expect(RouteGuards.book(series), '/lectures');
    });
  });

  group('RouteGuards.study (/study)', () {
    test('allows the route when the series has study mode', () {
      final series = _series(hasBook: false, hasStudyMode: true);
      expect(RouteGuards.study(series), isNull);
    });

    test('bounces to /lectures when the series has no study mode', () {
      final series = _series(hasBook: true, hasStudyMode: false);
      expect(RouteGuards.study(series), '/lectures');
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

  // The guards are independent: /book keys off hasBook alone, /study off
  // hasStudyMode alone. This pins that they don't cross-wire — the real Arabic
  // edition (book, no study) and Urdu edition (both) must each land right.
  group('the shipped editions land correctly', () {
    test('Arabic edition: /book opens, /study bounces', () {
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
      expect(RouteGuards.book(arabic), isNull);
      expect(RouteGuards.study(arabic), '/lectures');
    });

    test('Urdu edition: both /book and /study open', () {
      const urdu = SeriesConfig.legacyUrduFallback;
      expect(RouteGuards.book(urdu), isNull);
      expect(RouteGuards.study(urdu), isNull);
    });
  });
}
