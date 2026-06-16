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
  AppLanguage _language = AppLanguage.english;
  bool _featureEnabled = false;

  /// Whether the remote [language] feature flag is on — gates the manual
  /// switcher in Settings ([setLanguage]) only. The effective [language]
  /// itself (auto-detected from the device locale, or a previously saved
  /// preference) always applies, flag or no flag.
  bool get isLanguageFeatureEnabled => _featureEnabled;

  /// Effective language — auto-detected/saved, independent of the feature flag.
  AppLanguage get language => _language;

  String get code => language.code;

  /// Roman Urdu uses `ur` + script `roman` so Flutter Material localizations
  /// load via the standard `ur` locale while [AppLocalizations] serves Roman
  /// Urdu strings from app_ur_roman.arb.
  Locale get locale {
    return switch (_language) {
      AppLanguage.english   => const Locale('en'),
      AppLanguage.urdu      => const Locale('ur'),
      AppLanguage.romanUrdu =>
        const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
      AppLanguage.arabic    => const Locale('ar'),
    };
  }

  /// Whether the current language is right-to-left.
  bool get isRtl =>
      _language == AppLanguage.urdu || _language == AppLanguage.arabic;

  /// Load saved language synchronously — requires [PreferencesService.init]
  /// to have been called before this provider is created.
  void load() {
    final saved = PreferencesService.instance.appLanguage;
    _language = AppLanguage.values.firstWhere(
      (l) => l.code == saved,
      orElse: () => _detectFromSystem(),
    );
    notifyListeners();
  }

  /// Sync with remote feature flag — only affects whether [setLanguage] (the
  /// manual switcher) is allowed; the resolved [language] is unaffected.
  void applyLanguageFeatureFlag(bool enabled) {
    if (_featureEnabled == enabled) return;
    _featureEnabled = enabled;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (!_featureEnabled) return;
    if (_language == language) return;
    _language = language;
    await PreferencesService.instance.saveAppLanguage(language.code);
    notifyListeners();
  }

  /// Auto-sync the UI language when the active series changes.
  /// Bypasses the manual feature flag — this is a system-triggered change,
  /// not a user-initiated one from the Settings picker.
  Future<void> applySeriesLanguage(String languageCode) async {
    final lang =
        languageCode == 'ar' ? AppLanguage.arabic : AppLanguage.english;
    if (_language == lang) return;
    _language = lang;
    await PreferencesService.instance.saveAppLanguage(lang.code);
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
    final code = _language.code;

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

  static AppLanguage _detectFromSystem() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'ur') return AppLanguage.urdu;
    if (locale.languageCode == 'ar') return AppLanguage.arabic;
    // roman is never auto-detected
    return AppLanguage.english;
  }
}
