import 'package:flutter/material.dart';
import 'package:myapp/services/preferences_service.dart';

class ReadingProvider extends ChangeNotifier {
  final _prefs = PreferencesService.instance;

  double _bookFontSize = 20;
  double get bookFontSize => _bookFontSize;

  Map<String, double> _scrollOffsets = {};

  void load() {
    _bookFontSize = _prefs.bookFontSize;
    _scrollOffsets = _prefs.bookScrollOffsets;
    notifyListeners();
  }

  Future<void> setBookFontSize(double size) async {
    if (_bookFontSize == size) return;
    _bookFontSize = size;
    await _prefs.saveBookFontSize(size);
    notifyListeners();
  }

  /// Updates the font size for the live UI **without** persisting — for the
  /// pinch-to-zoom gesture, which fires continuously. Rebuilds the reader but
  /// leaves the disk alone until [commitBookFontSize] runs at the end of the
  /// gesture. Without this split, a single pinch is dozens of prefs writes.
  void setBookFontSizeLive(double size) {
    if (_bookFontSize == size) return;
    _bookFontSize = size;
    notifyListeners();
  }

  /// Persists whatever [bookFontSize] the live updates left — call once when a
  /// pinch ends.
  Future<void> commitBookFontSize() => _prefs.saveBookFontSize(_bookFontSize);

  /// Saved scroll offset (pixels) for [chapterId], or 0 if none.
  double bookScrollOffsetFor(String chapterId) =>
      _scrollOffsets[chapterId] ?? 0;

  /// Persists the reader's scroll offset for [chapterId]. Does not notify —
  /// callers are scroll handlers that must not trigger a rebuild.
  Future<void> setBookScrollOffset(String chapterId, double offset) async {
    if (_scrollOffsets[chapterId] == offset) return;
    _scrollOffsets = {..._scrollOffsets, chapterId: offset};
    await _prefs.saveBookScrollOffsets(_scrollOffsets);
  }
}
