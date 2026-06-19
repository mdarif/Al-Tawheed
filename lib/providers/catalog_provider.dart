import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/catalog_service.dart';
import 'package:myapp/services/content_fetch_exception.dart';

enum CatalogStatus { idle, loading, loaded, error }

enum CatalogFailureReason { none, generic, noCacheOffline }

class CatalogProvider extends ChangeNotifier {
  /// [_series] (optional) lets [load]/[reload] resolve the active series when
  /// no explicit one is passed — mirrors the [ProgressProvider]/
  /// [DownloadsProvider] pattern so a no-arg retry always targets the series
  /// the rest of the app is showing, not the legacy fallback.
  CatalogProvider([this._series]);

  final SeriesProvider? _series;

  CatalogStatus _status = CatalogStatus.idle;
  Catalog? _catalog;
  String? _error;
  CatalogFailureReason _failureReason = CatalogFailureReason.none;

  // Id of the series the currently-held [_catalog] belongs to. Used by screens
  // to detect a series/catalog desync and trigger a reload.
  String? _loadedSeriesId;

  // Id of the series an in-flight load is fetching, and a monotonic token so a
  // newer load for a different series supersedes an older one still awaiting
  // the network — the latest requested series always wins.
  String? _loadingSeriesId;
  int _loadToken = 0;

  CatalogStatus get status => _status;
  Catalog? get catalog => _catalog;
  String? get error => _error;
  CatalogFailureReason get failureReason => _failureReason;
  bool get needsOnlineToLoad =>
      _failureReason == CatalogFailureReason.noCacheOffline;
  bool get isLoading => _status == CatalogStatus.loading;

  /// Id of the series the loaded catalog belongs to, or `null` before any
  /// successful load.
  String? get loadedSeriesId => _loadedSeriesId;

  /// Language code of the active series (e.g. `'ar'`, `'ur'`).
  String get currentSeriesLanguage =>
      _series?.currentSeries.language ??
      SeriesConfig.legacyUrduFallback.language;

  Future<void> load([SeriesConfig? series]) async {
    final target =
        series ?? _series?.currentSeries ?? SeriesConfig.legacyUrduFallback;
    final targetId = target.id;

    // Already fetching this exact series — don't start a duplicate. A load for
    // a *different* series is allowed to proceed and supersede this one.
    if (_status == CatalogStatus.loading && _loadingSeriesId == targetId) {
      return;
    }

    final token = ++_loadToken;
    _loadingSeriesId = targetId;
    _status = CatalogStatus.loading;
    _error = null;
    _failureReason = CatalogFailureReason.none;
    notifyListeners();

    try {
      final catalog = await CatalogService.instance.fetchCatalog(target);
      if (token != _loadToken) return; // superseded by a newer load
      _catalog = catalog;
      _loadedSeriesId = targetId;
      _status = CatalogStatus.loaded;
    } on NoCachedContentException {
      if (token != _loadToken) return;
      _failureReason = CatalogFailureReason.noCacheOffline;
      _status = CatalogStatus.error;
    } catch (e) {
      if (token != _loadToken) return;
      _failureReason = CatalogFailureReason.generic;
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = CatalogStatus.error;
    }
    notifyListeners();
  }

  /// Injects catalog without network — for tests only.
  @visibleForTesting
  void setCatalogForTest(Catalog catalog, {String? seriesId}) {
    _catalog = catalog;
    _loadedSeriesId = seriesId ?? _loadedSeriesId;
    _status = CatalogStatus.loaded;
    _error = null;
    _failureReason = CatalogFailureReason.none;
    notifyListeners();
  }

  /// Simulates a failed load — for tests only.
  @visibleForTesting
  void setErrorForTest(Object error) {
    if (error is NoCachedContentException) {
      _failureReason = CatalogFailureReason.noCacheOffline;
      _error = null;
    } else {
      _failureReason = CatalogFailureReason.generic;
      _error = error.toString();
    }
    _status = CatalogStatus.error;
    notifyListeners();
  }
}
