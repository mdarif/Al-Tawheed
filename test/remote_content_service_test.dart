import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/remote_content_service.dart';

// RemoteContentService.fetch implements stale-while-revalidate caching for
// remote catalog/announcement JSON — exactly the kind of subtle, easy-to-
// silently-break branching that deserves a test before it's touched again.
// The fetch path itself does real HTTP + singleton-prefs I/O (no mocking
// library in this repo), so decideCacheStrategy was extracted as the pure
// decision the I/O defers to — this exercises that decision directly.

void main() {
  group('decideCacheStrategy', () {
    test('forces a refresh when forceRefresh is true, even with a fresh cache',
        () {
      expect(
        RemoteContentService.decideCacheStrategy(
          cached: '{"a":1}',
          ageMs: 10,
          ttlMs: 1000,
          forceRefresh: true,
        ),
        CacheStrategy.forceRefresh,
      );
    });

    test('serves the cache as-is when it is within the TTL', () {
      expect(
        RemoteContentService.decideCacheStrategy(
          cached: '{"a":1}',
          ageMs: 999,
          ttlMs: 1000,
          forceRefresh: false,
        ),
        CacheStrategy.freshCache,
      );
    });

    test('serves stale cache and triggers a background refresh once age reaches the TTL',
        () {
      expect(
        RemoteContentService.decideCacheStrategy(
          cached: '{"a":1}',
          ageMs: 1000,
          ttlMs: 1000,
          forceRefresh: false,
        ),
        CacheStrategy.staleCacheWithBackgroundRefresh,
      );
    });

    test('serves stale cache and triggers a background refresh well past the TTL',
        () {
      expect(
        RemoteContentService.decideCacheStrategy(
          cached: '{"a":1}',
          ageMs: 100000,
          ttlMs: 1000,
          forceRefresh: false,
        ),
        CacheStrategy.staleCacheWithBackgroundRefresh,
      );
    });

    test('fetches synchronously when there is no cached body', () {
      expect(
        RemoteContentService.decideCacheStrategy(
          cached: null,
          ageMs: null,
          ttlMs: 1000,
          forceRefresh: false,
        ),
        CacheStrategy.fetchSynchronously,
      );
    });

    test('treats a missing age as stale even if a cached body exists', () {
      // Defensive case: loadRemoteJson/remoteJsonAgeMs read separate prefs
      // keys, so a body without a timestamp shouldn't be trusted as fresh.
      expect(
        RemoteContentService.decideCacheStrategy(
          cached: '{"a":1}',
          ageMs: null,
          ttlMs: 1000,
          forceRefresh: false,
        ),
        CacheStrategy.staleCacheWithBackgroundRefresh,
      );
    });
  });
}
