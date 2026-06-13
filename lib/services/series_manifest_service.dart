import 'dart:convert';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/remote_content_service.dart';

class SeriesManifestService {
  SeriesManifestService._();
  static final SeriesManifestService instance = SeriesManifestService._();

  /// Fetches the list of available series from `series.json`, using the same
  /// stale-while-revalidate caching as the catalog.
  ///
  /// Falls back to `[SeriesConfig.legacyUrduFallback]` on any fetch/parse
  /// failure, or if the manifest is empty — onboarding never blocks on the
  /// network.
  Future<List<SeriesConfig>> fetchManifest() async {
    try {
      final body = await RemoteContentService.fetch(
        url: AppConfig.seriesManifestUrl,
        cacheKey: 'series_manifest',
        ttlMs: AppConfig.seriesManifestCacheTtlMs,
      );
      final json = jsonDecode(body) as Map<String, dynamic>;
      final list = (json['series'] as List<dynamic>)
          .map((e) => SeriesConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) return const [SeriesConfig.legacyUrduFallback];
      return list;
    } catch (_) {
      return const [SeriesConfig.legacyUrduFallback];
    }
  }
}
