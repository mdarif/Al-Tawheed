import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/services/catalog_service.dart';
import 'package:myapp/services/content_fetch_exception.dart';

enum CatalogStatus { idle, loading, loaded, error }

enum CatalogFailureReason { none, generic, noCacheOffline }

class CatalogProvider extends ChangeNotifier {
  CatalogStatus _status = CatalogStatus.idle;
  Catalog? _catalog;
  String? _error;
  CatalogFailureReason _failureReason = CatalogFailureReason.none;

  CatalogStatus get status => _status;
  Catalog? get catalog => _catalog;
  String? get error => _error;
  CatalogFailureReason get failureReason => _failureReason;
  bool get needsOnlineToLoad =>
      _failureReason == CatalogFailureReason.noCacheOffline;
  bool get isLoading => _status == CatalogStatus.loading;

  Future<void> load() async {
    if (_status == CatalogStatus.loading) return;
    _status = CatalogStatus.loading;
    _error = null;
    _failureReason = CatalogFailureReason.none;
    notifyListeners();

    try {
      _catalog = await CatalogService.instance.fetchCatalog();
      _status = CatalogStatus.loaded;
    } on NoCachedContentException {
      _failureReason = CatalogFailureReason.noCacheOffline;
      _status = CatalogStatus.error;
    } catch (e) {
      _failureReason = CatalogFailureReason.generic;
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = CatalogStatus.error;
    }
    notifyListeners();
  }

  /// Injects catalog without network — for tests only.
  @visibleForTesting
  void setCatalogForTest(Catalog catalog) {
    _catalog = catalog;
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
