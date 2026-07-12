import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
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

  /// Device system language at startup — used by [loadManifest] to silently
  /// default a fresh install to the Arabic series when the device itself is
  /// set to Arabic. Overridable in tests via [setDeviceLanguageCodeForTest].
  String _deviceLanguageCode =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;

  bool _hasCompletedOnboarding = false;

  Set<String> _seenWelcomeSeriesIds = {};

  // True while the definitive series is still being determined (flags loading
  // or manifest in flight). WelcomeScreen hides its content until this is false
  // to avoid flashing the Urdu fallback on Arabic-device cold starts.
  bool _isLoading = true;

  List<SeriesConfig> get availableSeries => _available;

  /// `false` only when multi-series is enabled and this is a genuinely fresh
  /// install that hasn't picked a series yet — the only case where
  /// `/choose-series` should be shown.
  bool get hasSelectedSeries => _currentId != null;

  /// `true` once the user has tapped "Start Listening" on the WelcomeScreen.
  /// Returning users (prefs restored at load) bypass the WelcomeScreen
  /// entirely and go straight to /lectures.
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  /// `true` when the device system language is Arabic.
  bool get isArabicDevice => _deviceLanguageCode == 'ar';

  /// `true` once the series is definitively known — either the manifest has
  /// loaded, a saved selection was found in prefs, or the flags confirmed that
  /// multi-series is disabled. WelcomeScreen waits for this before showing
  /// content to avoid flashing the Urdu fallback on Arabic devices.
  bool get isSeriesReady => !_isLoading;

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
  /// [definitive] must be `true` when called from the ProxyProvider `update`
  /// callback — i.e., after [FeatureFlagsProvider] has resolved. The initial
  /// `create` call passes the default `false` so [_isLoading] stays `true`
  /// until the flags are confirmed and, if needed, the manifest has loaded.
  /// Returns `true` if the welcome screen should be shown for [currentSeries].
  ///
  /// Rules:
  /// - Arabic welcome: shown the first time the user encounters the Arabic
  ///   series (whether on first launch or after switching from Urdu).
  /// - Urdu welcome: shown only to Urdu-first users — skipped for anyone who
  ///   has already encountered Arabic (i.e., Arabic-first users switching to
  ///   Urdu should not see a second welcome).
  bool get shouldShowWelcomeForCurrentSeries {
    final current = currentSeries;
    if (_seenWelcomeSeriesIds.contains(current.id)) return false;
    // Native Arabic-device users switching to a non-RTL (Urdu) series skip
    // the Urdu welcome — Arabic is their primary language. Urdu-first users
    // who explored Arabic still see the Urdu welcome because their device
    // language is not Arabic.
    if (!current.isRtl && isArabicDevice) return false;
    return true;
  }

  /// Records that the welcome screen for [currentSeries] has been seen.
  void markWelcomeSeenForCurrentSeries() {
    if (_seenWelcomeSeriesIds.contains(currentSeries.id)) return;
    _seenWelcomeSeriesIds = {..._seenWelcomeSeriesIds, currentSeries.id};
    unawaited(_prefs.saveSeenWelcomeForSeries(currentSeries.id));
    notifyListeners();
  }

  void load(bool multiSeriesEnabled, {bool definitive = false}) {
    _hasCompletedOnboarding = _prefs.hasCompletedOnboarding;
    _seenWelcomeSeriesIds = _prefs.seenWelcomeSeriesIds;
    // Migration: users who completed onboarding under the old single-flag
    // system have seen the Urdu welcome — seed the new set so they don't
    // see Urdu welcome again, but can still see Arabic welcome on first switch.
    if (_seenWelcomeSeriesIds.isEmpty && _hasCompletedOnboarding) {
      _seenWelcomeSeriesIds = {SeriesConfig.legacyId};
      unawaited(_prefs.saveSeenWelcomeForSeries(SeriesConfig.legacyId));
    }
    if (!multiSeriesEnabled) {
      _currentId = SeriesConfig.legacyId;
      if (definitive) _isLoading = false; // Urdu-only mode confirmed
      notifyListeners();
      return;
    }

    final saved = _prefs.selectedSeriesId;
    if (saved != null) {
      _currentId = saved;
      _isLoading = false; // Saved selection is authoritative
    } else if (_hasLegacyData()) {
      _currentId = SeriesConfig.legacyId;
      _isLoading = false; // Legacy data → Urdu is authoritative
      unawaited(_prefs.saveSelectedSeriesId(SeriesConfig.legacyId));
    } else {
      _currentId = null;
      _isLoading = true; // Wait for loadManifest() to pick the right series
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
    _maybeDefaultToArabic();
    _isLoading = false;
    notifyListeners();
  }

  /// On a genuinely fresh install (no selection yet), silently default to
  /// the Arabic series when the device's system language is Arabic — its
  /// screens are already fully localized to Arabic regardless of the app's
  /// UI-chrome language, so an Arabic-speaking user lands directly in a
  /// native experience without seeing the series picker.
  void _maybeDefaultToArabic() {
    if (_currentId != null || _deviceLanguageCode != 'ar') return;
    for (final series in _available) {
      if (series.isRtl) {
        _currentId = series.id;
        unawaited(_prefs.saveSelectedSeriesId(series.id));
        return;
      }
    }
  }

  /// Marks the WelcomeScreen as seen. Returning users (flag restored from prefs
  /// in [load]) are routed directly to /lectures, bypassing the welcome flow.
  void completeOnboarding() {
    if (_hasCompletedOnboarding) return;
    _hasCompletedOnboarding = true;
    unawaited(_prefs.saveHasCompletedOnboarding());
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
    _isLoading = false;
    notifyListeners();
  }

  /// Overrides the detected device system language — for tests only.
  @visibleForTesting
  void setDeviceLanguageCodeForTest(String code) {
    _deviceLanguageCode = code;
  }

  /// Sets the current series (adding it to [availableSeries] if needed) — for
  /// tests only.
  @visibleForTesting
  void setCurrentSeriesForTest(SeriesConfig series) {
    if (!_available.any((s) => s.id == series.id)) {
      _available = [..._available, series];
    }
    _currentId = series.id;
    _isLoading = false;
    notifyListeners();
  }
}

/// Re-scopes all per-series providers to [newSeries]: stops playback,
/// persists the selection, and reloads the catalog/progress/study/downloads
/// state for the new series.
Future<void> switchSeries(BuildContext context, SeriesConfig newSeries) async {
  final player = context.read<PlayerNotifier>();
  final series = context.read<SeriesProvider>();
  final catalog = context.read<CatalogProvider>();
  final progress = context.read<ProgressProvider>();
  final study = context.read<StudyProgressProvider>();
  final downloads = context.read<DownloadsProvider>();
  final book = context.read<BookProvider>();
  final lang = context.read<LanguageProvider>();

  await player.stop();
  await series.selectSeries(newSeries);
  await catalog.load(newSeries);
  progress.reload();
  study.reload();
  await downloads.reload();
  book.reload(); // clears the stale book; Book tab lazy-loads the new series'
  await lang.applySeriesLanguage(newSeries.language);
}
