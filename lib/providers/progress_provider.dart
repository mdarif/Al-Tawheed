import 'package:flutter/foundation.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';

class ProgressProvider extends ChangeNotifier {
  ProgressProvider([this._series]);

  final _prefs = PreferencesService.instance;
  final SeriesProvider? _series;

  String get _prefix =>
      (_series?.currentSeries ?? SeriesConfig.legacyUrduFallback)
          .storagePrefix;

  Map<String, int> _progress = {};
  String? _lastLectureId;
  int _lastPositionSeconds = 0;
  Set<String> _bookmarks = {};

  /// Load saved state synchronously — requires [PreferencesService.init]
  /// to have been called before this provider is created.
  void load() {
    final prefix = _prefix;
    _progress = _prefs.loadAllProgress(prefix: prefix);
    _lastLectureId = _prefs.lastLectureIdFor(prefix);
    _lastPositionSeconds = _prefs.lastPositionSecondsFor(prefix);
    _bookmarks = _prefs.loadBookmarks(prefix: prefix);
    notifyListeners();
  }

  /// Re-reads state for the current series — call after switching series.
  void reload() => load();

  // ── Getters ──────────────────────────────────────────────────────────────

  String? get lastLectureId => _lastLectureId;
  int get lastPositionSeconds => _lastPositionSeconds;

  /// Position in seconds for [lectureId], 0 if not started.
  int getPositionSeconds(String lectureId) => _progress[lectureId] ?? 0;

  /// Fraction 0.0–1.0 listened. Returns 0 if [totalSeconds] is 0.
  double getFraction(String lectureId, int totalSeconds) {
    if (totalSeconds == 0) return 0.0;
    return ((_progress[lectureId] ?? 0) / totalSeconds).clamp(0.0, 1.0);
  }

  bool hasProgress(String lectureId) =>
      (_progress[lectureId] ?? 0) > 0;

  // ── Bookmarks ─────────────────────────────────────────────────────────────

  bool isBookmarked(String lectureId) => _bookmarks.contains(lectureId);
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarks);

  Future<void> toggleBookmark(String lectureId) async {
    if (_bookmarks.contains(lectureId)) {
      _bookmarks.remove(lectureId);
    } else {
      _bookmarks.add(lectureId);
    }
    notifyListeners();
    await _prefs.saveBookmarks(_bookmarks, prefix: _prefix);
  }

  // ── Commands ─────────────────────────────────────────────────────────────

  /// Persists progress and notifies listeners (use when UI should refresh).
  Future<void> saveProgress(String lectureId, int positionSeconds) =>
      _persistProgress(lectureId, positionSeconds, notify: true);

  /// Persists progress without notifying — for periodic background saves.
  Future<void> saveProgressSilent(String lectureId, int positionSeconds) =>
      _persistProgress(lectureId, positionSeconds, notify: false);

  Future<void> _persistProgress(
    String lectureId,
    int positionSeconds, {
    required bool notify,
  }) async {
    final unchanged = _progress[lectureId] == positionSeconds &&
        _lastLectureId == lectureId &&
        _lastPositionSeconds == positionSeconds;
    if (unchanged) return;

    _progress[lectureId] = positionSeconds;
    _lastLectureId = lectureId;
    _lastPositionSeconds = positionSeconds;
    if (notify) notifyListeners();
    await _prefs.saveProgress(lectureId, positionSeconds, prefix: _prefix);
  }
}
