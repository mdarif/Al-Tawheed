import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around shared_preferences.
/// Call [init] once in main() before runApp.
class PreferencesService {
  PreferencesService._();
  static final instance = PreferencesService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'PreferencesService.init() must be called before use');
    return _prefs!;
  }

  // ── Progress ────────────────────────────────────────────────────────────

  /// Persists [positionSeconds] for [lectureId] and records it as last played.
  Future<void> saveProgress(String lectureId, int positionSeconds) async {
    await Future.wait([
      _p.setInt('progress_$lectureId', positionSeconds),
      _p.setString('last_lecture_id', lectureId),
      _p.setInt('last_position', positionSeconds),
    ]);
  }

  /// Returns a map of lectureId → saved position in seconds.
  Map<String, int> loadAllProgress() {
    return {
      for (final key in _p.getKeys().where((k) => k.startsWith('progress_')))
        key.substring('progress_'.length): _p.getInt(key) ?? 0,
    };
  }

  String? get lastLectureId => _p.getString('last_lecture_id');
  int get lastPositionSeconds => _p.getInt('last_position') ?? 0;

  // ── Playback speed ──────────────────────────────────────────────────────

  double get playbackSpeed => _p.getDouble('playback_speed') ?? 1.0;

  Future<void> savePlaybackSpeed(double speed) =>
      _p.setDouble('playback_speed', speed);
}
