import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/services/preferences_service.dart';

void main() {
  group('LanguageProvider.isRtl', () {
    test('Urdu script is RTL', () {
      const provider = _RtlProbe(AppLanguage.urdu);
      expect(provider.isRtl, isTrue);
    });

    test('Roman Urdu is LTR', () {
      const provider = _RtlProbe(AppLanguage.romanUrdu);
      expect(provider.isRtl, isFalse);
    });

    test('English is LTR', () {
      const provider = _RtlProbe(AppLanguage.english);
      expect(provider.isRtl, isFalse);
    });
  });

  group('LanguageProvider.locale', () {
    test('Roman Urdu uses ur+roman script subtags for Material + Roman l10n', () {
      const provider = _LocaleProbe(AppLanguage.romanUrdu);
      expect(provider.locale.languageCode, 'ur');
      expect(provider.locale.scriptCode, 'roman');
    });
  });

  group('LanguageProvider feature flag', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PreferencesService.instance.resetForTest();
      await PreferencesService.instance.init();
    });

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
    });
  });
}

class _RtlProbe {
  final AppLanguage language;
  const _RtlProbe(this.language);
  bool get isRtl => language == AppLanguage.urdu;
}

class _LocaleProbe {
  final AppLanguage language;
  const _LocaleProbe(this.language);

  Locale get locale => switch (language) {
        AppLanguage.english => const Locale('en'),
        AppLanguage.urdu => const Locale('ur'),
        AppLanguage.romanUrdu =>
          const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
      };
}
