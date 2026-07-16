import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cold-start CHROME resolution (test-plan §5.2 / §5.3).
///
/// `series_provider_test` already proves the right *edition* resolves on frame
/// one (returning reader from cache; fresh Arabic-device default). What nothing
/// checked is the other half of the Middle-East first-run promise: that the
/// resolved edition also produces Arabic *chrome* on that same first frame, with
/// no flash of English/Urdu and without the picker. That is the SeriesProvider →
/// LanguageProvider seam, exercised here through the exact calls `app.dart`
/// makes — not a reimplementation of them.

/// Seeds the cache entry `SeriesManifestService.fetchManifest` writes, so a
/// returning user's device state is on disk before `load()`.
Future<void> _seedManifest() => PreferencesService.instance.saveRemoteJson(
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
            'hasBook': true,
            'language': 'ar',
            'displayName': {'en': 'Kitab at-Tawheed (Arabic)'},
            'speakerName': {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
          },
        ],
      }),
    );

/// Mirrors `lib/app.dart`'s `LanguageProvider` ProxyProvider `update` callback
/// verbatim — feature flag first, then the series default — so this tests the
/// real wiring. If app.dart's callback changes, change this with it; keeping the
/// two in lock-step in one place is what stops the "probe reimplements the
/// provider and drifts" bug this repo has hit before.
LanguageProvider _chromeFor(SeriesProvider series, {bool languageFlag = false}) {
  final lang = LanguageProvider()..load();
  lang.applyLanguageFeatureFlag(languageFlag);
  lang.applySeriesDefault(series.currentSeries);
  return lang;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  // 5.2 — returning Arabic reader. `load()` hydrates the edition from cache
  // SYNCHRONOUSLY (deea15a), so there is no await here: the chrome asserted is
  // literally frame-one state. If the edition flashed the Urdu fallback first
  // (the bug), the series default would be null and `language` would fall
  // through to the device (English in the harness) — not Arabic.
  test('returning Arabic reader gets Arabic chrome on frame one (no flash)',
      () async {
    await _seedManifest();
    await PreferencesService.instance.saveSelectedSeriesId('tawheed-ar');

    final series = SeriesProvider()..load(true); // multiSeries enabled
    final chrome = _chromeFor(series);

    expect(series.currentSeries.id, 'tawheed-ar');
    expect(chrome.language, AppLanguage.arabic);
    expect(chrome.locale, const Locale('ar'));
    expect(chrome.isRtl, isTrue);
    expect(chrome.hasExplicitPreference, isFalse,
        reason: 'chrome comes from the edition default, not a saved pick',);
  });

  // 5.3 — fresh install on an Arabic device. The edition auto-defaults to Arabic
  // (no picker), AND the chrome must be Arabic too. The two together are the
  // promise; each was half-checked before.
  test('fresh Arabic-device install: Arabic edition + Arabic chrome, no picker',
      () async {
    await _seedManifest();

    final series = SeriesProvider()
      ..load(true)
      ..setDeviceLanguageCodeForTest('ar');
    await series.loadManifest(); // _maybeDefaultToArabic runs here
    await Future<void>.delayed(Duration.zero);

    // Edition + picker
    expect(series.currentSeries.id, 'tawheed-ar');
    expect(series.hasSelectedSeries, isTrue,
        reason: 'auto-defaulted → /choose-series must never show',);

    // Chrome
    final chrome = _chromeFor(series);
    expect(chrome.language, AppLanguage.arabic);
    expect(chrome.isRtl, isTrue);
  });

  // The guard on the guard: chrome default is Arabic-only. A returning Urdu
  // reader keeps device-detected chrome (English in the harness) — the Urdu
  // edition deliberately does NOT force Urdu chrome (ADR-0002). Without this, a
  // "default to the edition's language" over-correction would pass 5.2/5.3.
  test('returning Urdu reader does NOT get forced Urdu chrome', () async {
    await _seedManifest();
    await PreferencesService.instance.saveSelectedSeriesId('tawheed-ur');

    final series = SeriesProvider()..load(true);
    final chrome = _chromeFor(series);

    expect(series.currentSeries.id, 'tawheed-ur');
    expect(chrome.language, isNot(AppLanguage.arabic));
    expect(chrome.isRtl, isFalse);
  });
}
