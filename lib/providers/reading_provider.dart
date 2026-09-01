import 'package:flutter/material.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';

class ReadingProvider extends ChangeNotifier {
  ReadingProvider([this._series]);

  final _prefs = PreferencesService.instance;
  final SeriesProvider? _series;

  String get _prefix =>
      (_series?.currentSeries ?? SeriesConfig.legacyUrduFallback)
          .storagePrefix;

  // Reading comfort setting — global, not per-edition content state.
  double _bookFontSize = 20;
  double get bookFontSize => _bookFontSize;

  Map<String, double> _scrollOffsets = {};
  String? _lastChapterId;

  /// The chapter id last opened for the current edition, or null if none —
  /// drives the "Continue reading" banner. Independent of scroll depth: set
  /// whenever the reader navigates to a *different* chapter, not on every
  /// scroll update.
  String? get lastChapterId => _lastChapterId;

  void load() {
    final prefix = _prefix;
    _bookFontSize = _prefs.bookFontSize;
    _scrollOffsets = _prefs.bookScrollOffsets(prefix: prefix);
    _lastChapterId = _prefs.lastChapterIdFor(prefix);
    notifyListeners();
  }

  /// Re-reads state for the current series — call after switching series, so
  /// a reading position never carries over from a different edition (chapter
  /// ids like "ch-01" are not globally unique across editions).
  void reload() => load();

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
  /// callers are scroll handlers that must not trigger a rebuild. Updates
  /// [lastChapterId] (and does notify for that) whenever the chapter itself
  /// changes, so the "Continue reading" banner reflects the chapter last
  /// opened rather than the deepest-scrolled one.
  Future<void> setBookScrollOffset(String chapterId, double offset) async {
    final chapterChanged = _lastChapterId != chapterId;
    if (_scrollOffsets[chapterId] == offset && !chapterChanged) return;
    final prefix = _prefix;
    _scrollOffsets = {..._scrollOffsets, chapterId: offset};
    final writes = [_prefs.saveBookScrollOffsets(_scrollOffsets, prefix: prefix)];
    if (chapterChanged) {
      _lastChapterId = chapterId;
      writes.add(_prefs.saveLastChapterId(chapterId, prefix: prefix));
    }
    await Future.wait(writes);
    if (chapterChanged) notifyListeners();
  }
}
