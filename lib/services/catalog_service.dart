import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myapp/app_config.dart';
import 'package:myapp/models/catalog.dart';

class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  Future<Catalog> fetchCatalog() async {
    final response = await http
        .get(Uri.parse(AppConfig.catalogUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load catalog (HTTP ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final catalog = Catalog.fromJson(json);

    if (catalog.version > AppConfig.maxSupportedCatalogVersion) {
      throw Exception(
        'Catalog version ${catalog.version} requires a newer app. '
        'Please update from the Play Store.',
      );
    }

    return catalog;
  }
}
