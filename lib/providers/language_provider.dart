import 'package:flutter/material.dart';
import 'package:myapp/services/preferences_service.dart';

/// Supported language codes.
/// Values must match the JSON keys in catalog.json, benefits.json, etc.
enum AppLanguage {
  english('en', 'English', 'English'),
  urdu('ur', 'اردو', 'Urdu'),
  romanUrdu('roman', 'Roman Urdu', 'Roman Urdu'); // Phase 2

  const AppLanguage(this.code, this.nativeName, this.englishName);
  final String code;
  final String nativeName;
  final String englishName;
}

class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  String get code => _language.code;

  /// Flutter Locale for this language — used in MaterialApp.locale.
  Locale get locale {
    return switch (_language) {
      AppLanguage.english   => const Locale('en'),
      AppLanguage.urdu      => const Locale('ur'),
      AppLanguage.romanUrdu => const Locale('ur', 'ROMAN'),
    };
  }

  /// Whether the current language is right-to-left.
  bool get isRtl => _language == AppLanguage.urdu;

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

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
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

  // ── Private helpers ───────────────────────────────────────────────────────

  static AppLanguage _detectFromSystem() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'ur') return AppLanguage.urdu;
    // roman is never auto-detected
    return AppLanguage.english;
  }
}
