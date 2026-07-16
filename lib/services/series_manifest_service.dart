import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/preferences_service.dart';
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
        cacheKey: _cacheKey,
        ttlMs: AppConfig.seriesManifestCacheTtlMs,
      );
      return _parse(body) ?? const [SeriesConfig.legacyUrduFallback];
    } catch (e) {
      debugPrint('SeriesManifestService: fetch failed, using fallback: $e');
      return const [SeriesConfig.legacyUrduFallback];
    }
  }

  /// The last-fetched manifest, read straight from the cache with no `await`.
  /// Null on a cold cache (fresh install) or unusable cached body.
  ///
  /// [SeriesProvider.currentSeries] resolves a saved series id against the
  /// available list, so while the manifest is only reachable asynchronously a
  /// returning Arabic reader resolves to the Urdu fallback for the first
  /// frame(s) — long enough to paint Urdu chrome, tabs and avatar before they
  /// flip. Prefs are already in memory by then, so reading them synchronously
  /// closes that window entirely.
  List<SeriesConfig>? cachedManifest() {
    final body = PreferencesService.instance.loadRemoteJson(_cacheKey);
    return body == null ? null : _parse(body);
  }

  static const _cacheKey = 'series_manifest';

  /// Null when [body] yields no usable series, so callers can distinguish
  /// "nothing here" from a real list and apply their own fallback.
  List<SeriesConfig>? _parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final raw = json['series'];
      if (raw is! List) return null;
      final list = <SeriesConfig>[];
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        try {
          list.add(SeriesConfig.fromJson(e));
        } catch (_) {
          // Skip one malformed series entry; keep the rest.
        }
      }
      return list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }
}
