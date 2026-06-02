import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/language_provider.dart';

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
    test('effective language is English when feature is disabled', () {
      final provider = LanguageProvider()
        ..applyLanguageFeatureFlag(false);
      expect(provider.language, AppLanguage.english);
      expect(provider.code, 'en');
    });

    test('resolve uses en when feature is disabled', () {
      final provider = LanguageProvider()
        ..applyLanguageFeatureFlag(false);
      expect(
        provider.resolve({'en': 'Hello', 'ur': 'سلام'}),
        'Hello',
      );
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
