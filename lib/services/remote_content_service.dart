import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/services/content_fetch_exception.dart';
import 'package:myapp/services/preferences_service.dart';

/// What [RemoteContentService.fetch] should do given the cache state — the
/// pure stale-while-revalidate decision, kept separate from the I/O so it can
/// be unit-tested without mocking HTTP or preferences.
@visibleForTesting
enum CacheStrategy {
  /// `forceRefresh` was requested — bypass the cache entirely.
  forceRefresh,

  /// Cache exists and is within [RemoteContentService.fetch]'s `ttlMs` — serve it as-is.
  freshCache,

  /// Cache exists but is older than the TTL — serve it now, refresh in the background.
  staleCacheWithBackgroundRefresh,

  /// No cache — must fetch synchronously before returning anything.
  fetchSynchronously,
}

/// Generic stale-while-revalidate fetch for any remote JSON file.
///
/// Usage:
///   final body = await RemoteContentService.fetch(
///     url: AppConfig.appConfigUrl,
///     cacheKey: 'app_config',
///     ttlMs: AppConfig.appConfigCacheTtlMs,
///   );
class RemoteContentService {
  RemoteContentService._();

  /// Returns the latest JSON body string for [url].
  ///
  /// Strategy:
  /// 1. If cache exists AND is fresh (age < [ttlMs]) → return cache instantly.
  /// 2. If cache is stale → return cache now AND trigger a background refresh.
  /// 3. If no cache → fetch synchronously; throw on failure.
  ///
  /// The caller is responsible for parsing the returned string.
  static Future<String> fetch({
    required String url,
    required String cacheKey,
    required int ttlMs,
    bool forceRefresh = false,
  }) async {
    final prefs = PreferencesService.instance;
    final cached = prefs.loadRemoteJson(cacheKey);
    final ageMs = prefs.remoteJsonAgeMs(cacheKey);

    switch (decideCacheStrategy(
      cached: cached,
      ageMs: ageMs,
      ttlMs: ttlMs,
      forceRefresh: forceRefresh,
    )) {
      case CacheStrategy.forceRefresh:
        return _fetchAndCache(url: url, cacheKey: cacheKey);

      case CacheStrategy.freshCache:
        return cached!;

      case CacheStrategy.staleCacheWithBackgroundRefresh:
        _refreshInBackground(url: url, cacheKey: cacheKey);
        return cached!;

      case CacheStrategy.fetchSynchronously:
        try {
          return await _fetchAndCache(url: url, cacheKey: cacheKey);
        } catch (_) {
          throw NoCachedContentException(cacheKey);
        }
    }
  }

  /// Pure stale-while-revalidate decision — see [CacheStrategy].
  @visibleForTesting
  static CacheStrategy decideCacheStrategy({
    required String? cached,
    required int? ageMs,
    required int ttlMs,
    required bool forceRefresh,
  }) {
    if (forceRefresh) return CacheStrategy.forceRefresh;
    if (cached != null && ageMs != null && ageMs < ttlMs) {
      return CacheStrategy.freshCache;
    }
    if (cached != null) return CacheStrategy.staleCacheWithBackgroundRefresh;
    return CacheStrategy.fetchSynchronously;
  }

  static Future<void> _refreshInBackground({
    required String url,
    required String cacheKey,
  }) async {
    try {
      await _fetchAndCache(url: url, cacheKey: cacheKey);
    } catch (_) {
      // Background refresh failures are silent — stale cache continues serving
    }
  }

  static Future<String> _fetchAndCache({
    required String url,
    required String cacheKey,
  }) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} fetching $url');
    }

    final body = response.body;
    // Validate it's parseable JSON before caching
    jsonDecode(body);
    await PreferencesService.instance.saveRemoteJson(cacheKey, body);
    return body;
  }
}
