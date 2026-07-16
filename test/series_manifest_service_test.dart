import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/services/series_manifest_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SeriesManifestService` had no direct test, yet `cachedManifest()` now runs
/// on **every** cold start (it's what lets a returning Arabic reader resolve the
/// right edition on frame one). These pin its parse/skip/fallback rules.
///
/// Everything here goes through the cache (`saveRemoteJson` stamps a fresh
/// timestamp), so nothing touches the network.

const _cacheKey = 'series_manifest';

Map<String, dynamic> _entry(String id, String language, {String? catalogUrl}) =>
    {
      'id': id,
      if (catalogUrl != null) 'catalogUrl': catalogUrl,
      'storagePrefix': '',
      'hasStudyMode': true,
      'language': language,
      'displayName': {'en': id},
      'speakerName': {'en': 'Speaker'},
    };

Future<void> _seed(Object manifest) => PreferencesService.instance
    .saveRemoteJson(_cacheKey, jsonEncode(manifest));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  final service = SeriesManifestService.instance;

  group('cachedManifest', () {
    test('returns null on a cold cache (fresh install)', () {
      expect(service.cachedManifest(), isNull);
    });

    test('parses a well-formed manifest, preserving order', () async {
      await _seed({
        'series': [
          _entry('tawheed-ur', 'ur',
              catalogUrl: 'https://example.com/ur/catalog.json',),
          _entry('tawheed-ar', 'ar',
              catalogUrl: 'https://example.com/ar/catalog.json',),
        ],
      });

      final manifest = service.cachedManifest();
      expect(manifest, isNotNull);
      expect(manifest!.map((s) => s.id), ['tawheed-ur', 'tawheed-ar']);
      expect(manifest.map((s) => s.language), ['ur', 'ar']);
    });

    test('returns null on malformed JSON rather than throwing', () async {
      await PreferencesService.instance.saveRemoteJson(_cacheKey, '{not json');
      expect(service.cachedManifest(), isNull);
    });

    test('returns null when "series" is not a list', () async {
      await _seed({'series': 'nope'});
      expect(service.cachedManifest(), isNull);
    });

    test('skips a malformed entry (no catalogUrl) but keeps the valid one',
        () async {
      await _seed({
        'series': [
          _entry('broken', 'ar'), // no catalogUrl → SeriesConfig.fromJson throws
          _entry('tawheed-ur', 'ur',
              catalogUrl: 'https://example.com/ur/catalog.json',),
        ],
      });

      final manifest = service.cachedManifest();
      expect(manifest, isNotNull);
      expect(manifest!.map((s) => s.id), ['tawheed-ur']);
    });

    test('returns null when every entry is malformed (empty result)', () async {
      await _seed({
        'series': [
          _entry('broken-1', 'ar'), // no catalogUrl
          _entry('broken-2', 'ur'), // no catalogUrl
        ],
      });
      expect(service.cachedManifest(), isNull);
    });
  });

  group('fetchManifest', () {
    test('returns the parsed manifest from a fresh cache (no network)',
        () async {
      await _seed({
        'series': [
          _entry('tawheed-ar', 'ar',
              catalogUrl: 'https://example.com/ar/catalog.json',),
        ],
      });

      final manifest = await service.fetchManifest();
      expect(manifest.map((s) => s.id), ['tawheed-ar']);
    });

    test('falls back to the legacy Urdu series when the manifest is empty',
        () async {
      // A fresh cache that parses to nothing → fetchManifest must never return
      // an empty list (onboarding would have no series). Tested via the cache
      // so the fallback path runs without hitting the network.
      await _seed({'series': <dynamic>[]});

      final manifest = await service.fetchManifest();
      expect(manifest, [SeriesConfig.legacyUrduFallback]);
    });
  });
}
