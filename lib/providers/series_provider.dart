import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/services/series_manifest_service.dart';

/// Tracks which content series (e.g. Urdu vs Arabic Kitab at-Tawheed) is
/// currently active, and the list of series offered by the remote
/// `series.json` manifest.
class SeriesProvider extends ChangeNotifier {
  final PreferencesService _prefs = PreferencesService.instance;

  List<SeriesConfig> _available = const [SeriesConfig.legacyUrduFallback];
  String? _currentId;

  List<SeriesConfig> get availableSeries => _available;

  /// `false` only when multi-series is enabled and this is a genuinely fresh
  /// install that hasn't picked a series yet — the only case where
  /// `/choose-series` should be shown.
  bool get hasSelectedSeries => _currentId != null;

  SeriesConfig get currentSeries => _available.firstWhere(
        (s) => s.id == _currentId,
        orElse: () => SeriesConfig.legacyUrduFallback,
      );

  /// Synchronous onboarding decision — call at startup (like
  /// [ProgressProvider.load]) and again whenever [multiSeriesEnabled] changes.
  ///
  /// When the flag is off, [currentSeries] is always the legacy Urdu series —
  /// byte-identical to the pre-v3 app. When it's on, an existing user
  /// (detected via [_hasLegacyData]) is silently pinned to Urdu; only a
  /// genuinely empty install reaches `/choose-series`.
  void load(bool multiSeriesEnabled) {
    if (!multiSeriesEnabled) {
      _currentId = SeriesConfig.legacyId;
      notifyListeners();
      return;
    }

    final saved = _prefs.selectedSeriesId;
    if (saved != null) {
      _currentId = saved;
    } else if (_hasLegacyData()) {
      _currentId = SeriesConfig.legacyId;
      unawaited(_prefs.saveSelectedSeriesId(SeriesConfig.legacyId));
    } else {
      _currentId = null;
    }
    notifyListeners();
  }

  bool _hasLegacyData() =>
      _prefs.lastLectureId != null ||
      _prefs.loadAllProgress().isNotEmpty ||
      _prefs.loadBookmarks().isNotEmpty ||
      _prefs.loadDownloadedIds().isNotEmpty ||
      _prefs.loadStudiedChapterIds().isNotEmpty;

  /// Fetches the `series.json` manifest. Falls back to
  /// `[SeriesConfig.legacyUrduFallback]` on any failure — never blocks
  /// onboarding on the network.
  Future<void> loadManifest() async {
    _available = await SeriesManifestService.instance.fetchManifest();
    notifyListeners();
  }

  /// Persists [series] as the active series and notifies listeners.
  Future<void> selectSeries(SeriesConfig series) async {
    if (_currentId == series.id) return;
    _currentId = series.id;
    await _prefs.saveSelectedSeriesId(series.id);
    notifyListeners();
  }

  /// Injects the available series list — for tests only.
  @visibleForTesting
  void setAvailableSeriesForTest(List<SeriesConfig> series) {
    _available = series;
    notifyListeners();
  }

  /// Sets the current series (adding it to [availableSeries] if needed) — for
  /// tests only.
  @visibleForTesting
  void setCurrentSeriesForTest(SeriesConfig series) {
    if (!_available.any((s) => s.id == series.id)) {
      _available = [..._available, series];
    }
    _currentId = series.id;
    notifyListeners();
  }
}

/// Re-scopes all per-series providers to [newSeries]: stops playback,
/// persists the selection, and reloads the catalog/progress/study/downloads
/// state for the new series.
Future<void> switchSeries(BuildContext context, SeriesConfig newSeries) async {
  await context.read<PlayerNotifier>().stop();
  await context.read<SeriesProvider>().selectSeries(newSeries);
  await context.read<CatalogProvider>().load(newSeries);
  context.read<ProgressProvider>().reload();
  context.read<StudyProgressProvider>().reload();
  await context.read<DownloadsProvider>().reload();
}
