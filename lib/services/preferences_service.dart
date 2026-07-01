import 'dart:convert';

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

  /// Clears cached prefs — call before [init] in tests for isolation.
  @visibleForTesting
  void resetForTest() {
    _prefs = null;
  }

  SharedPreferences get _p {
    assert(
      _prefs != null,
      'PreferencesService.init() must be called before use',
    );
    return _prefs!;
  }

  // ── Progress ────────────────────────────────────────────────────────────

  /// Persists [positionSeconds] for [lectureId] and records it as last played.
  /// [prefix] namespaces the keys for a non-default series (e.g. `'ar_'`).
  Future<void> saveProgress(
    String lectureId,
    int positionSeconds, {
    String prefix = '',
  }) async {
    await Future.wait([
      _p.setInt('${prefix}progress_$lectureId', positionSeconds),
      _p.setString('${prefix}last_lecture_id', lectureId),
      _p.setInt('${prefix}last_position', positionSeconds),
    ]);
  }

  /// Returns a map of lectureId → saved position in seconds.
  Map<String, int> loadAllProgress({String prefix = ''}) {
    final progressKey = '${prefix}progress_';
    return {
      for (final key in _p.getKeys().where((k) => k.startsWith(progressKey)))
        key.substring(progressKey.length): _p.getInt(key) ?? 0,
    };
  }

  String? get lastLectureId => _p.getString('last_lecture_id');
  int get lastPositionSeconds => _p.getInt('last_position') ?? 0;

  String? lastLectureIdFor(String prefix) =>
      _p.getString('${prefix}last_lecture_id');
  int lastPositionSecondsFor(String prefix) =>
      _p.getInt('${prefix}last_position') ?? 0;

  // ── Bookmarks ───────────────────────────────────────────────────────────

  Set<String> loadBookmarks({String prefix = ''}) =>
      Set<String>.from(_p.getStringList('${prefix}bookmarks') ?? []);

  Future<void> saveBookmarks(Set<String> ids, {String prefix = ''}) =>
      _p.setStringList('${prefix}bookmarks', ids.toList());

  // ── Playback speed ──────────────────────────────────────────────────────

  double get playbackSpeed => _p.getDouble('playback_speed') ?? 1.0;

  Future<void> savePlaybackSpeed(double speed) =>
      _p.setDouble('playback_speed', speed);

  // ── Language ─────────────────────────────────────────────────────────────

  /// Returns the saved language code ('en', 'ur', 'roman'), or null if never set.
  String? get appLanguage => _p.getString('app_language');

  Future<void> saveAppLanguage(String code) =>
      _p.setString('app_language', code);

  // ── Theme ───────────────────────────────────────────────────────────────

  ThemeMode get themeMode {
    switch (_p.getString('theme_mode')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
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

  // ── Reading ─────────────────────────────────────────────────────────────

  double get bookFontSize => _p.getDouble('book_font_size') ?? 20;

  Future<void> saveBookFontSize(double size) =>
      _p.setDouble('book_font_size', size);

  // Per-chapter scroll offset (pixels), so a reader returns to where they left
  // off. Stored as a single JSON map keyed by chapter id.
  Map<String, double> get bookScrollOffsets {
    final raw = _p.getString('book_scroll_offsets');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveBookScrollOffsets(Map<String, double> offsets) =>
      _p.setString('book_scroll_offsets', jsonEncode(offsets));

  // ── Downloads ───────────────────────────────────────────────────────────

  Set<String> loadDownloadedIds({String prefix = ''}) => Set<String>.from(
        _p.getStringList('${prefix}downloaded_lecture_ids') ?? [],
      );

  Future<void> saveDownloadedIds(Set<String> ids, {String prefix = ''}) =>
      _p.setStringList('${prefix}downloaded_lecture_ids', ids.toList());

  bool get downloadOnWifiOnly => _p.getBool('download_wifi_only') ?? false;

  Future<void> saveDownloadOnWifiOnly(bool value) =>
      _p.setBool('download_wifi_only', value);

  // ── Study mode ──────────────────────────────────────────────────────────

  Set<String> loadStudiedChapterIds({String prefix = ''}) =>
      Set<String>.from(_p.getStringList('${prefix}studied_chapter_ids') ?? []);

  Future<void> saveStudiedChapterIds(Set<String> ids, {String prefix = ''}) =>
      _p.setStringList('${prefix}studied_chapter_ids', ids.toList());

  // ── Selected series ──────────────────────────────────────────────────────
  // Global (not prefixed) — identifies which series.json entry is active.

  String? get selectedSeriesId => _p.getString('selected_series_id');

  Future<void> saveSelectedSeriesId(String id) =>
      _p.setString('selected_series_id', id);

  // ── Onboarding ───────────────────────────────────────────────────────────

  bool get hasCompletedOnboarding =>
      _p.getBool('has_completed_onboarding') ?? false;

  Future<void> saveHasCompletedOnboarding() =>
      _p.setBool('has_completed_onboarding', true);

  // Per-series set of IDs whose welcome screen has been shown. Used to gate
  // the welcome screen per-series instead of using the old single global flag.
  Set<String> get seenWelcomeSeriesIds =>
      Set<String>.from(_p.getStringList('seen_welcome_series_ids') ?? []);

  Future<void> saveSeenWelcomeForSeries(String seriesId) async {
    final ids = seenWelcomeSeriesIds;
    ids.add(seriesId);
    await _p.setStringList('seen_welcome_series_ids', ids.toList());
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
      _p.setInt(
        'cache_${key}_fetched_at',
        DateTime.now().millisecondsSinceEpoch,
      ),
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
