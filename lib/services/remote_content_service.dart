import 'dart:async';
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
  /// Default number of fetch attempts before giving up. A single transient TCP
  /// reset (e.g. flaky IPv4 path to the CDN) would otherwise strand a fresh
  /// install on the "connect to load" screen — retrying rides over it.
  static const int defaultMaxAttempts = 3;

  /// Delay between retries; grows linearly per attempt. Defaults to zero
  /// (immediate retry) — a fresh connection attempt clears a transient TCP
  /// reset, and immediate retries leave no dangling Timer in widget tests that
  /// fire-and-forget a load. The slower "network came back" case is handled by
  /// [CatalogProvider]'s connectivity listener, not by waiting here. Callers/
  /// tests may pass a non-zero value for real backoff.
  static const Duration defaultRetryDelay = Duration.zero;

  static Future<String> fetch({
    required String url,
    required String cacheKey,
    required int ttlMs,
    bool forceRefresh = false,
    http.Client? client,
    int maxAttempts = defaultMaxAttempts,
    Duration retryDelay = defaultRetryDelay,
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
        return _fetchAndCache(
          url: url,
          cacheKey: cacheKey,
          client: client,
          maxAttempts: maxAttempts,
          retryDelay: retryDelay,
        );

      case CacheStrategy.freshCache:
        return cached!;

      case CacheStrategy.staleCacheWithBackgroundRefresh:
        unawaited(
          _refreshInBackground(
            url: url,
            cacheKey: cacheKey,
            client: client,
            maxAttempts: maxAttempts,
            retryDelay: retryDelay,
          ),
        );
        return cached!;

      case CacheStrategy.fetchSynchronously:
        try {
          return await _fetchAndCache(
            url: url,
            cacheKey: cacheKey,
            client: client,
            maxAttempts: maxAttempts,
            retryDelay: retryDelay,
          );
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
    http.Client? client,
    int maxAttempts = defaultMaxAttempts,
    Duration retryDelay = defaultRetryDelay,
  }) async {
    try {
      await _fetchAndCache(
        url: url,
        cacheKey: cacheKey,
        client: client,
        maxAttempts: maxAttempts,
        retryDelay: retryDelay,
      );
    } catch (e) {
      debugPrint(
        'RemoteContentService: background refresh failed for $cacheKey: $e',
      );
    }
  }

  /// Fetches [url] with up to [maxAttempts] tries, linear backoff between them.
  /// One transient TCP reset (common on flaky IPv4 paths to the CDN) no longer
  /// fails the whole load — the next attempt usually lands on a good route/IP.
  static Future<String> _fetchAndCache({
    required String url,
    required String cacheKey,
    http.Client? client,
    int maxAttempts = defaultMaxAttempts,
    Duration retryDelay = defaultRetryDelay,
  }) async {
    // Reuse an injected client (tests); otherwise create + close our own so a
    // fresh connection is attempted each retry.
    final http.Client c = client ?? http.Client();
    Object? lastError;
    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final response =
              await c.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode} fetching $url');
          }

          final body = response.body;
          jsonDecode(body); // validate it's parseable JSON before caching
          await PreferencesService.instance.saveRemoteJson(cacheKey, body);
          return body;
        } catch (e) {
          lastError = e;
          // Only schedule a Timer if a real backoff was asked for; the default
          // (zero) retries immediately and leaves no pending Timer in tests.
          if (attempt < maxAttempts && retryDelay > Duration.zero) {
            await Future<void>.delayed(retryDelay * attempt);
          }
        }
      }
      throw lastError!;
    } finally {
      if (client == null) c.close();
    }
  }
}
