import 'dart:convert';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/services/remote_content_service.dart';

class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  /// Fetches the catalog using stale-while-revalidate caching.
  ///
  /// - Returns cached data instantly if available (even if stale).
  /// - Triggers a background refresh when cache is older than [AppConfig.catalogCacheTtlMs].
  /// - On first launch with no cache, fetches synchronously.
  Future<Catalog> fetchCatalog() async {
    final body = await RemoteContentService.fetch(
      url: AppConfig.catalogUrl,
      cacheKey: 'catalog',
      ttlMs: AppConfig.catalogCacheTtlMs,
    );

    final json = jsonDecode(body) as Map<String, dynamic>;
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
