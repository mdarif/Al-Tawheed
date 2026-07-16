import 'package:flutter/material.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/preferences_service.dart';

/// Supported language codes.
/// Values must match the JSON keys in catalog.json, benefits.json, etc.
enum AppLanguage {
  english('en', 'English', 'English'),
  urdu('ur', 'اردو', 'Urdu'),
  romanUrdu('roman', 'Roman Urdu', 'Roman Urdu'),
  arabic('ar', 'العربية', 'Arabic');

  const AppLanguage(this.code, this.nativeName, this.englishName);
  final String code;
  final String nativeName;
  final String englishName;
}

class LanguageProvider extends ChangeNotifier {
  /// The user's saved pick. Null until they choose one in Settings — nothing
  /// else ever writes it, so "non-null" *is* the has-an-explicit-preference
  /// bit. No separate flag to keep in sync.
  AppLanguage? _explicit;

  /// Chrome language the active content edition asks for; null when the edition
  /// has no opinion. See [chromeDefaultFor].
  AppLanguage? _seriesDefault;

  AppLanguage _detected = AppLanguage.english;
  bool _featureEnabled = false;

  /// Whether the remote [language] feature flag is on — gates the manual
  /// switcher in Settings ([setLanguage]) only. The effective [language]
  /// itself always applies, flag or no flag.
  bool get isLanguageFeatureEnabled => _featureEnabled;

  /// Effective chrome language, in precedence order:
  ///
  ///   explicit pick  >  series default  >  device  >  English
  ///
  /// The user's pick always wins and always sticks: switching editions must
  /// never silently discard it (that regression is why 5cc657e decoupled chrome
  /// from the edition wholesale). The series only supplies the *default* — what
  /// you get before you have ever expressed a preference. See ADR-0002.
  AppLanguage get language => _explicit ?? _seriesDefault ?? _detected;

  /// Whether the user has explicitly chosen a chrome language.
  bool get hasExplicitPreference => _explicit != null;

  String get code => language.code;

  /// Roman Urdu uses `ur` + script `roman` so Flutter Material localizations
  /// load via the standard `ur` locale while [AppLocalizations] serves Roman
  /// Urdu strings from app_ur_roman.arb.
  Locale get locale {
    return switch (language) {
      AppLanguage.english => const Locale('en'),
      AppLanguage.urdu => const Locale('ur'),
      AppLanguage.romanUrdu =>
        const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
      AppLanguage.arabic => const Locale('ar'),
    };
  }

  /// Whether the current language is right-to-left.
  bool get isRtl =>
      language == AppLanguage.urdu || language == AppLanguage.arabic;

  /// Load saved language synchronously — requires [PreferencesService.init]
  /// to have been called before this provider is created.
  void load() {
    _explicit = _byCode(PreferencesService.instance.appLanguage);
    _detected = _detectFromSystem();
    notifyListeners();
  }

  /// Sync with remote feature flag — only affects whether [setLanguage] (the
  /// manual switcher) is allowed; the resolved [language] is unaffected.
  void applyLanguageFeatureFlag(bool enabled) {
    if (_featureEnabled == enabled) return;
    _featureEnabled = enabled;
    notifyListeners();
  }

  /// Adopt the chrome language [series] defaults to. Never overrides an
  /// explicit pick — [language] resolves the precedence.
  ///
  /// Deliberately NOT gated on [isLanguageFeatureEnabled]: that flag governs
  /// the manual switcher, not the effective language. Gating here would make
  /// the Arabic edition ship English chrome wherever the flag is off — which
  /// is everywhere, today.
  void applySeriesDefault(SeriesConfig series) {
    final next = chromeDefaultFor(series);
    if (_seriesDefault == next) return;
    _seriesDefault = next;
    notifyListeners();
  }

  /// The chrome language an edition *defaults* to; null means "no opinion",
  /// falling through to device detection.
  ///
  /// Only Arabic opts in. The Arabic edition targets the Middle East, where the
  /// audience reads Arabic — English chrome around Arabic duroos is simply
  /// wrong there. The Urdu edition deliberately does NOT default to Urdu
  /// chrome: its largely Indian audience reads English more comfortably than
  /// Nastaliq, so it keeps device-detected chrome. See ADR-0002.
  static AppLanguage? chromeDefaultFor(SeriesConfig series) =>
      switch (series.language) {
        'ar' => AppLanguage.arabic,
        _ => null,
      };

  Future<void> setLanguage(AppLanguage language) async {
    if (!_featureEnabled) return;
    // Compare against the *explicit* pick, not the effective language: an
    // Arabic-edition user tapping "العربية" is already seeing Arabic via the
    // series default, and early-returning here would persist nothing — their
    // chrome would then silently flip to English the day they switch editions.
    if (_explicit == language) return;
    _explicit = language;
    await PreferencesService.instance.saveAppLanguage(language.code);
    notifyListeners();
  }

  // ── Content resolution ────────────────────────────────────────────────────

  /// Resolve a multilingual field map to the best string for the current
  /// language, following the fallback chain:
  ///   roman → ur → en
  ///   ur    → en
  ///   en    → (terminal)
  ///
  /// Returns an empty string only if the field map is null or entirely empty.
  String resolve(Map<String, dynamic>? field) {
    if (field == null) return '';
    final code = language.code;

    // Primary
    final primary = field[code];
    if (primary is String && primary.isNotEmpty) return primary;

    // Fallback chain
    if (code == 'roman') {
      final ur = field['ur'];
      if (ur is String && ur.isNotEmpty) return ur;
    }

    // Terminal — English always exists
    final en = field['en'];
    return en is String ? en : '';
  }

  /// Resolve a multilingual field map for content belonging to [series].
  ///
  /// Arabic-series content (`series.isRtl`) displays in Arabic regardless of
  /// the app's UI language — navigation/chrome stay governed by [resolve].
  /// Falls back to [resolve] when no `ar` entry exists.
  String resolveForSeries(Map<String, dynamic>? field, SeriesConfig series) {
    if (series.isRtl) {
      final ar = field?['ar'];
      if (ar is String && ar.isNotEmpty) return ar;
    }
    return resolve(field);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// The language saved under [code], or null when nothing matches — including
  /// the never-saved case, which is what makes [_explicit] a reliable
  /// has-a-preference signal.
  static AppLanguage? _byCode(String? code) {
    for (final language in AppLanguage.values) {
      if (language.code == code) return language;
    }
    return null;
  }

  static AppLanguage _detectFromSystem() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'ur') return AppLanguage.urdu;
    if (locale.languageCode == 'ar') return AppLanguage.arabic;
    // roman is never auto-detected
    return AppLanguage.english;
  }
}
