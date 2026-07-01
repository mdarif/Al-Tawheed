import 'package:flutter/material.dart';
import 'package:myapp/services/preferences_service.dart';

class ThemeProvider extends ChangeNotifier {
  final _prefs = PreferencesService.instance;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Load saved theme synchronously — requires [PreferencesService.init]
  /// to have been called before this provider is created.
  void load() {
    _themeMode = _prefs.themeMode;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.saveThemeMode(mode);
    notifyListeners();
  }

  /// Toggle between explicit light and dark (single-switch UX).
  Future<void> setDarkMode(bool isDark) =>
      setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
}
