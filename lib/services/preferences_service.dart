import 'package:flutter/material.dart';
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

  // ── Bookmarks ───────────────────────────────────────────────────────────

  Set<String> loadBookmarks() =>
      Set<String>.from(_p.getStringList('bookmarks') ?? []);

  Future<void> saveBookmarks(Set<String> ids) =>
      _p.setStringList('bookmarks', ids.toList());

  // ── Playback speed ──────────────────────────────────────────────────────

  double get playbackSpeed => _p.getDouble('playback_speed') ?? 1.0;

  Future<void> savePlaybackSpeed(double speed) =>
      _p.setDouble('playback_speed', speed);

  // ── Theme ───────────────────────────────────────────────────────────────

  ThemeMode get themeMode {
    switch (_p.getString('theme_mode')) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    return _p.setString('theme_mode', value);
  }

  // ── Dismissed announcements ─────────────────────────────────────────────

  Set<String> loadDismissedAnnouncements() =>
      Set<String>.from(_p.getStringList('dismissed_announcements') ?? []);

  Future<void> saveDismissedAnnouncements(Set<String> ids) =>
      _p.setStringList('dismissed_announcements', ids.toList());

  // ── Remote JSON cache ────────────────────────────────────────────────────
  // Each remote file is cached as a raw JSON string + a fetch timestamp.
  // Pattern: saveRemoteJson(key, body) / loadRemoteJson(key) / remoteJsonAge(key)

  Future<void> saveRemoteJson(String key, String body) async {
    await Future.wait([
      _p.setString('cache_${key}_json', body),
      _p.setInt('cache_${key}_fetched_at', DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  String? loadRemoteJson(String key) => _p.getString('cache_${key}_json');

  /// Returns the age of the cached entry in milliseconds, or null if never cached.
  int? remoteJsonAgeMs(String key) {
    final ts = _p.getInt('cache_${key}_fetched_at');
    if (ts == null) return null;
    return DateTime.now().millisecondsSinceEpoch - ts;
  }
}
