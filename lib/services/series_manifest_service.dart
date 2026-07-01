import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      final raw = json['series'];
      final list = <SeriesConfig>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map<String, dynamic>) continue;
          try {
            list.add(SeriesConfig.fromJson(e));
          } catch (_) {
            // Skip one malformed series entry; keep the rest.
          }
        }
      }
      if (list.isEmpty) return const [SeriesConfig.legacyUrduFallback];
      return list;
    } catch (e) {
      debugPrint('SeriesManifestService: fetch failed, using fallback: $e');
      return const [SeriesConfig.legacyUrduFallback];
    }
  }
}
