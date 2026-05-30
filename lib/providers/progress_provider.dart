import 'package:flutter/foundation.dart';
import 'package:myapp/services/preferences_service.dart';

class ProgressProvider extends ChangeNotifier {
  final _prefs = PreferencesService.instance;

  Map<String, int> _progress = {};
  String? _lastLectureId;
  int _lastPositionSeconds = 0;

  /// Load saved progress synchronously — requires [PreferencesService.init]
  /// to have been called before this provider is created.
  void load() {
    _progress = _prefs.loadAllProgress();
    _lastLectureId = _prefs.lastLectureId;
    _lastPositionSeconds = _prefs.lastPositionSeconds;
    notifyListeners();
  }

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

  // ── Commands ─────────────────────────────────────────────────────────────

  Future<void> saveProgress(String lectureId, int positionSeconds) async {
    _progress[lectureId] = positionSeconds;
    _lastLectureId = lectureId;
    _lastPositionSeconds = positionSeconds;
    notifyListeners();
    await _prefs.saveProgress(lectureId, positionSeconds);
  }
}
