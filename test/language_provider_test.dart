import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/models/series.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/services/preferences_service.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan'},
);

const _urduSeries = SeriesConfig.legacyUrduFallback;

Future<LanguageProvider> _loaded({String? saved}) async {
  SharedPreferences.setMockInitialValues(
    saved == null ? {} : {'app_language': saved},
  );
  PreferencesService.instance.resetForTest();
  await PreferencesService.instance.init();
  return LanguageProvider()..load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('LanguageProvider.isRtl', () {
    test('Urdu script is RTL', () async {
      final provider = await _loaded(saved: 'ur');
      expect(provider.isRtl, isTrue);
    });

    test('Arabic is RTL', () async {
      final provider = await _loaded(saved: 'ar');
      expect(provider.isRtl, isTrue);
    });

    test('Roman Urdu is LTR', () async {
      final provider = await _loaded(saved: 'roman');
      expect(provider.isRtl, isFalse);
    });

    test('English is LTR', () async {
      final provider = await _loaded(saved: 'en');
      expect(provider.isRtl, isFalse);
    });
  });

  group('LanguageProvider.locale', () {
    test('Roman Urdu uses ur+roman script subtags for Material + Roman l10n',
        () async {
      final provider = await _loaded(saved: 'roman');
      expect(provider.locale.languageCode, 'ur');
      expect(provider.locale.scriptCode, 'roman');
    });
  });

  group('LanguageProvider feature flag', () {
    test('resolved language and content are unaffected by the feature flag',
        () async {
      final provider = LanguageProvider()..applyLanguageFeatureFlag(true);
      await provider.setLanguage(AppLanguage.urdu);

      // Turning the switcher feature off again must not revert the
      // already-resolved language back to English.
      provider.applyLanguageFeatureFlag(false);

      expect(provider.language, AppLanguage.urdu);
      expect(provider.code, 'ur');
      expect(provider.isRtl, isTrue);
      expect(provider.locale, const Locale('ur'));
      expect(provider.resolve({'en': 'Hello', 'ur': 'سلام'}), 'سلام');
    });

    test('setLanguage is a no-op when the feature flag is off', () async {
      final provider = LanguageProvider()..applyLanguageFeatureFlag(false);
      await provider.setLanguage(AppLanguage.urdu);

      expect(provider.language, AppLanguage.english);
      expect(provider.hasExplicitPreference, isFalse);
      expect(PreferencesService.instance.appLanguage, isNull);
    });
  });

  group('chrome precedence — explicit > series > device > English', () {
    test('the Arabic edition defaults chrome to Arabic', () async {
      final lang = await _loaded();
      expect(lang.language, AppLanguage.english); // device default under test

      lang.applySeriesDefault(_arabicSeries);

      expect(lang.language, AppLanguage.arabic);
      expect(lang.locale, const Locale('ar'));
      expect(lang.isRtl, isTrue);
      expect(lang.hasExplicitPreference, isFalse);
    });

    test('an explicit pick beats the series default', () async {
      final lang = await _loaded()
        ..applyLanguageFeatureFlag(true);
      await lang.setLanguage(AppLanguage.english);

      lang.applySeriesDefault(_arabicSeries);

      expect(lang.language, AppLanguage.english);
      expect(lang.hasExplicitPreference, isTrue);
    });

    test('a pick saved in a previous session beats the series default',
        () async {
      final lang = await _loaded(saved: 'en');

      lang.applySeriesDefault(_arabicSeries);

      expect(lang.language, AppLanguage.english);
    });

    // The production case: `language` is false in the live remote config, so
    // nobody can express an explicit pick. Gating the series default on that
    // flag would make this feature a no-op exactly where it ships.
    test('the series default applies even with the language feature flag off',
        () async {
      final lang = await _loaded()..applyLanguageFeatureFlag(false);

      lang.applySeriesDefault(_arabicSeries);

      expect(lang.language, AppLanguage.arabic);
    });

    // The Urdu edition targets India, where English reads more comfortably
    // than Nastaliq — it deliberately has no chrome opinion.
    test('the Urdu edition has no opinion — chrome stays device-detected',
        () async {
      final lang = await _loaded();

      expect(LanguageProvider.chromeDefaultFor(_urduSeries), isNull);
      lang.applySeriesDefault(_urduSeries);

      expect(lang.language, AppLanguage.english);
    });

    // SeriesConfig.fromJson falls back to 'en' when a manifest omits
    // `language`. That must degrade to device detection, not hard-force
    // English, or a sloppy manifest would override an Arabic device.
    test('a series with no declared language falls through to the device',
        () async {
      final unset = SeriesConfig.fromJson({
        'id': 'mystery',
        'catalogUrl': 'https://example.com/catalog.json',
      });
      final lang = await _loaded();

      expect(unset.language, 'en');
      expect(LanguageProvider.chromeDefaultFor(unset), isNull);

      lang.applySeriesDefault(unset);
      expect(lang.language, AppLanguage.english);
    });
  });

  group('setLanguage', () {
    // Without comparing against the *explicit* pick rather than the effective
    // language, this early-returns: nothing is persisted, and the user's chrome
    // silently flips to English the day they switch editions.
    test('persists a pick that merely matches the current series default',
        () async {
      final lang = await _loaded()
        ..applyLanguageFeatureFlag(true)
        ..applySeriesDefault(_arabicSeries);

      await lang.setLanguage(AppLanguage.arabic);

      expect(lang.hasExplicitPreference, isTrue);
      expect(PreferencesService.instance.appLanguage, 'ar');

      // ...and it survives a switch to the Urdu edition.
      lang.applySeriesDefault(_urduSeries);
      expect(lang.language, AppLanguage.arabic);
    });
  });

  group('switching editions', () {
    test('flips chrome when the user has no explicit pick', () async {
      final lang = await _loaded()..applySeriesDefault(_arabicSeries);
      expect(lang.language, AppLanguage.arabic);

      lang.applySeriesDefault(_urduSeries);
      expect(lang.language, AppLanguage.english);

      lang.applySeriesDefault(_arabicSeries);
      expect(lang.language, AppLanguage.arabic);
    });

    test('notifies once per change so MaterialApp picks up the new locale',
        () async {
      final lang = await _loaded();
      var notifications = 0;
      lang.addListener(() => notifications++);

      lang.applySeriesDefault(_arabicSeries);
      expect(notifications, 1);

      lang.applySeriesDefault(_arabicSeries); // same edition — no churn
      expect(notifications, 1);
    });
  });

  // Branding and book/chapter titles resolve through `resolve`, so they follow
  // the series default for free.
  group('resolve follows the series default', () {
    test('picks the Arabic entry on the Arabic edition', () async {
      final lang = await _loaded()..applySeriesDefault(_arabicSeries);

      expect(
        lang.resolve({'en': 'Powered by Al Marfa', 'ar': 'بدعم من المرفأ'}),
        'بدعم من المرفأ',
      );
    });

    test('falls back to English when the field has no Arabic entry', () async {
      final lang = await _loaded()..applySeriesDefault(_arabicSeries);

      expect(lang.resolve({'en': 'Al Marfa Duroos'}), 'Al Marfa Duroos');
    });
  });
}
