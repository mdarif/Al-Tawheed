import 'package:flutter/material.dart';
import 'package:myapp/services/preferences_service.dart';

class ReadingProvider extends ChangeNotifier {
  final _prefs = PreferencesService.instance;

  double _bookFontSize = 20;
  double get bookFontSize => _bookFontSize;

  void load() {
    _bookFontSize = _prefs.bookFontSize;
    notifyListeners();
  }

  Future<void> setBookFontSize(double size) async {
    if (_bookFontSize == size) return;
    _bookFontSize = size;
    await _prefs.saveBookFontSize(size);
    notifyListeners();
  }
}
