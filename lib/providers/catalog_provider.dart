import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/services/catalog_service.dart';

enum CatalogStatus { idle, loading, loaded, error }

class CatalogProvider extends ChangeNotifier {
  CatalogStatus _status = CatalogStatus.idle;
  Catalog? _catalog;
  String? _error;

  CatalogStatus get status => _status;
  Catalog? get catalog => _catalog;
  String? get error => _error;
  bool get isLoading => _status == CatalogStatus.loading;

  Future<void> load() async {
    if (_status == CatalogStatus.loading) return;
    _status = CatalogStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _catalog = await CatalogService.instance.fetchCatalog();
      _status = CatalogStatus.loaded;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = CatalogStatus.error;
    }
    notifyListeners();
  }
}
