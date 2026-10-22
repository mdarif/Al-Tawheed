import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/services/content_fetch_exception.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/services/remote_content_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RemoteContentService.fetch implements stale-while-revalidate caching plus a
// retry-on-transient-failure fetch — both the kind of subtle branching that
// deserves tests before being touched again. decideCacheStrategy covers the
// pure cache decision; the `fetch — retries` group injects a MockClient to
// exercise the real fetch/retry path (a transient TCP reset on the CDN's flaky
// IPv4 route is what stranded fresh installs on the "connect to load" screen).

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

    test(
        'serves stale cache and triggers a background refresh once age reaches the TTL',
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

    test(
        'serves stale cache and triggers a background refresh well past the TTL',
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

  group('fetch — retries transient failures', () {
    const url = 'https://cdn.example/catalog.json';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PreferencesService.instance.resetForTest();
      await PreferencesService.instance.init();
    });

    test('returns the body on first success (one call)', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"ok":1}', 200);
      });
      final body = await RemoteContentService.fetch(
        url: url,
        cacheKey: 'k',
        ttlMs: 1,
        forceRefresh: true,
        client: client,
        retryDelay: Duration.zero,
      );
      expect(calls, 1);
      expect(body, contains('ok'));
    });

    test('rides over a transient reset and succeeds on a later attempt',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls < 3) {
          throw http.ClientException('Connection reset by peer');
        }
        return http.Response('{"ok":1}', 200);
      });
      final body = await RemoteContentService.fetch(
        url: url,
        cacheKey: 'k',
        ttlMs: 1,
        forceRefresh: true,
        client: client,
        retryDelay: Duration.zero,
      );
      expect(calls, 3);
      expect(body, contains('ok'));
    });

    test('retries a non-200 then succeeds', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls < 2
            ? http.Response('busy', 503)
            : http.Response('{"ok":1}', 200);
      });
      final body = await RemoteContentService.fetch(
        url: url,
        cacheKey: 'k',
        ttlMs: 1,
        forceRefresh: true,
        client: client,
        retryDelay: Duration.zero,
      );
      expect(calls, 2);
      expect(body, contains('ok'));
    });

    test(
        'no cache + all attempts fail → NoCachedContentException after maxAttempts',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw http.ClientException('Connection reset by peer');
      });
      await expectLater(
        RemoteContentService.fetch(
          url: url,
          cacheKey: 'k', // no cache → fetchSynchronously
          ttlMs: 1,
          client: client,
          retryDelay: Duration.zero,
          maxAttempts: 3,
        ),
        throwsA(isA<NoCachedContentException>()),
      );
      expect(calls, 3);
    });
  });

  group('fetch — startup deadline', () {
    const url = 'https://cdn.example/feature-flags.json';
    const deadline = Duration(milliseconds: 50);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PreferencesService.instance.resetForTest();
      await PreferencesService.instance.init();
    });

    // A connection that never answers must not hold a no-cache caller for
    // maxAttempts x 10 s: past the deadline it fails like any other fetch.
    test('gives up on a fetch that never answers once the deadline passes',
        () async {
      final client = MockClient((_) => Completer<http.Response>().future);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        RemoteContentService.fetch(
          url: url,
          cacheKey: 'k',
          ttlMs: 1,
          client: client,
          deadline: deadline,
        ),
        throwsA(isA<NoCachedContentException>()),
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('a slow fetch that lands inside the deadline is still returned',
        () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return http.Response('{"ok":1}', 200);
      });

      final body = await RemoteContentService.fetch(
        url: url,
        cacheKey: 'k',
        ttlMs: 1,
        client: client,
        deadline: const Duration(seconds: 5),
      );

      expect(body, contains('ok'));
    });

    // The abandoned request is not cancelled: if it lands later it fills the
    // cache, so the next launch starts warm.
    test('a fetch that lands after the deadline still fills the cache',
        () async {
      final late = Completer<http.Response>();
      final client = MockClient((_) => late.future);

      await expectLater(
        RemoteContentService.fetch(
          url: url,
          cacheKey: 'k',
          ttlMs: 1,
          client: client,
          deadline: deadline,
        ),
        throwsA(isA<NoCachedContentException>()),
      );
      expect(PreferencesService.instance.loadRemoteJson('k'), isNull);

      late.complete(http.Response('{"ok":1}', 200));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(PreferencesService.instance.loadRemoteJson('k'), contains('ok'));
    });

    test('a cached body is served instantly; the deadline never applies',
        () async {
      await PreferencesService.instance.saveRemoteJson('k', '{"cached":1}');
      final client = MockClient((_) => Completer<http.Response>().future);

      final body = await RemoteContentService.fetch(
        url: url,
        cacheKey: 'k',
        ttlMs: 60 * 60 * 1000,
        client: client,
        deadline: deadline,
      );

      expect(body, contains('cached'));
    });
  });
}
