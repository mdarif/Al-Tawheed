import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: false,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('load — multiSeries disabled', () {
    test('always resolves to the legacy Urdu series, even with saved prefs',
        () async {
      await PreferencesService.instance.saveSelectedSeriesId('tawheed-ar');

      final provider = SeriesProvider()..load(false);

      expect(provider.currentSeries.id, SeriesConfig.legacyId);
      expect(provider.hasSelectedSeries, isTrue);
    });
  });

  group('load — multiSeries enabled', () {
    test('genuinely fresh install has no selection (picker shown)', () {
      final provider = SeriesProvider()..load(true);

      expect(provider.hasSelectedSeries, isFalse);
    });

    test('respects a previously saved selection', () async {
      await PreferencesService.instance.saveSelectedSeriesId('tawheed-ar');

      final provider = SeriesProvider()..load(true);

      expect(provider.hasSelectedSeries, isTrue);
    });

    test('existing progress silently pins to Urdu and persists it', () async {
      await PreferencesService.instance.saveProgress('lec-001', 30);

      final provider = SeriesProvider()..load(true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.hasSelectedSeries, isTrue);
      expect(provider.currentSeries.id, SeriesConfig.legacyId);
      expect(
          PreferencesService.instance.selectedSeriesId, SeriesConfig.legacyId);
    });

    test('existing bookmarks alone count as legacy data', () async {
      await PreferencesService.instance.saveBookmarks({'lec-001'});

      final provider = SeriesProvider()..load(true);

      expect(provider.currentSeries.id, SeriesConfig.legacyId);
      expect(provider.hasSelectedSeries, isTrue);
    });

    test('existing downloaded ids alone count as legacy data', () async {
      await PreferencesService.instance.saveDownloadedIds({'lec-001'});

      final provider = SeriesProvider()..load(true);

      expect(provider.currentSeries.id, SeriesConfig.legacyId);
      expect(provider.hasSelectedSeries, isTrue);
    });

    test('existing studied chapters alone count as legacy data', () async {
      await PreferencesService.instance.saveStudiedChapterIds({'ch-01'});

      final provider = SeriesProvider()..load(true);

      expect(provider.currentSeries.id, SeriesConfig.legacyId);
      expect(provider.hasSelectedSeries, isTrue);
    });
  });

  group('selectSeries', () {
    test('persists the new id and updates currentSeries', () async {
      final provider = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(
            const [SeriesConfig.legacyUrduFallback, _arabicSeries]);

      await provider.selectSeries(_arabicSeries);

      expect(provider.currentSeries.id, 'tawheed-ar');
      expect(PreferencesService.instance.selectedSeriesId, 'tawheed-ar');
    });

    test('is a no-op when selecting the already-current series', () async {
      final provider = SeriesProvider()..load(false);

      await provider.selectSeries(SeriesConfig.legacyUrduFallback);

      expect(PreferencesService.instance.selectedSeriesId, isNull);
    });
  });

  group('loadManifest', () {
    test('parses series.json into availableSeries', () async {
      await PreferencesService.instance.saveRemoteJson(
        'series_manifest',
        jsonEncode({
          'version': 1,
          'series': [
            {
              'id': 'tawheed-ur',
              'catalogUrl': 'https://example.com/tawheed/catalog.json',
              'storagePrefix': '',
              'hasStudyMode': true,
              'language': 'ur',
              'displayName': {'en': 'Kitab at-Tawheed (Urdu)'},
              'speakerName': {'en': 'Shaikh Abdullah Nasir Rahmani'},
            },
            {
              'id': 'tawheed-ar',
              'catalogUrl': 'https://example.com/tawheed-ar/catalog.json',
              'storagePrefix': 'ar_',
              'hasStudyMode': false,
              'language': 'ar',
              'displayName': {'en': 'Kitab at-Tawheed (Arabic)'},
              'speakerName': {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
            },
          ],
        }),
      );

      final provider = SeriesProvider();
      await provider.loadManifest();

      expect(provider.availableSeries.map((s) => s.id),
          ['tawheed-ur', 'tawheed-ar']);
    });

    test('falls back to the legacy series when the manifest list is empty',
        () async {
      await PreferencesService.instance.saveRemoteJson(
        'series_manifest',
        jsonEncode({'version': 1, 'series': <Map<String, dynamic>>[]}),
      );

      final provider = SeriesProvider();
      await provider.loadManifest();

      expect(provider.availableSeries, [SeriesConfig.legacyUrduFallback]);
    });

    test('falls back to the legacy series when the manifest JSON is malformed',
        () async {
      await PreferencesService.instance
          .saveRemoteJson('series_manifest', '{"not-series": true}');

      final provider = SeriesProvider();
      await provider.loadManifest();

      expect(provider.availableSeries, [SeriesConfig.legacyUrduFallback]);
    });
  });
}
