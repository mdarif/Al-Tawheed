import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/catalog_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real catalog fetch/cache/version path. `catalog_provider_test` injects a
/// `_SpyCatalog` and bypasses `CatalogService` entirely, so its cache-key
/// namespacing and version guard were unguarded — the same shape as the 2.3.0
/// outage (pure logic tested, the I/O wasn't).
///
/// Seeding via `saveRemoteJson` stamps a fresh timestamp, so `fetch` resolves
/// through the freshCache branch and never touches the network.

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

String _catalogJson({int version = 1, required String bookTitle}) =>
    jsonEncode({
      'version': version,
      'book': {
        'id': 'book-1',
        'title': {'en': bookTitle},
        'speaker': {'en': 'Speaker'},
        'totalDurationSeconds': 120,
        'lectureCount': 1,
        'coverImageUrl': 'https://example.com/cover.jpg',
        'language': 'ur',
      },
      'chapters': [
        {'id': 'ch-01', 'number': 1, 'title': {'en': 'One'}, 'lectureCount': 1},
      ],
      'lectures': [
        {
          'id': 'lec-001',
          'number': 1,
          'chapterId': 'ch-01',
          'title': {'en': 'Lecture 1'},
          'audioUrl': 'https://example.com/1.mp3',
          'durationSeconds': 60,
          'fileSizeBytes': 1000,
        },
      ],
      'dailyBenefits': <dynamic>[],
    });

Future<void> _seed(String cacheKey, String body) =>
    PreferencesService.instance.saveRemoteJson(cacheKey, body);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  test('the legacy series reads the un-namespaced "catalog" key', () async {
    // The legacy Urdu series keeps cache key 'catalog' for a zero cache-miss
    // upgrade — this is the contract that keeps pre-v3 installs working.
    await _seed('catalog', _catalogJson(bookTitle: 'Urdu Book'));

    final catalog = await CatalogService.instance.fetchCatalog();

    expect(catalog.book.title['en'], 'Urdu Book');
    expect(catalog.lectures, hasLength(1));
  });

  test('a non-legacy series reads its id-namespaced key, not the legacy one',
      () async {
    // Decoy under the legacy key; the real Arabic data under the namespaced
    // key. If fetchCatalog fell back to 'catalog', it would return the decoy.
    await _seed('catalog', _catalogJson(bookTitle: 'WRONG — legacy'));
    await _seed('catalog_tawheed-ar', _catalogJson(bookTitle: 'Arabic Book'));

    final catalog = await CatalogService.instance.fetchCatalog(_arabicSeries);

    expect(catalog.book.title['en'], 'Arabic Book');
  });

  test('rejects a catalog newer than the app can parse', () async {
    // maxSupportedCatalogVersion is 1 — a v2 catalog means "update the app".
    await _seed('catalog', _catalogJson(version: 2, bookTitle: 'Future'));

    expect(
      () => CatalogService.instance.fetchCatalog(),
      throwsA(isA<Exception>()),
    );
  });

  test('accepts a catalog at exactly the max supported version', () async {
    await _seed('catalog', _catalogJson(version: 1, bookTitle: 'Current'));

    final catalog = await CatalogService.instance.fetchCatalog();
    expect(catalog.version, 1);
  });
}
