@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/app_config_model.dart';

/// Contract tests against the **live CDN** (`content.kitabattawheed.com`).
///
/// The app ships remote-config-driven: a bad edit in Al-Tawheed-Content reaches
/// production with no app release and no review gate. These assert the invariants
/// the app silently depends on. They are tagged `live` and **excluded from the PR
/// gate** (see `dart_test.yaml`) — network flake must never block a merge — and
/// run nightly via `.github/workflows/flutter-live-contract.yml`.
///
/// Each failure here means "the live content is about to misbehave in an app
/// nobody can hot-fix", so they are worth a human look the morning after.
void main() {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  tearDownAll(() => client.close(force: true));

  /// GETs [url] and decodes JSON, with one retry so a single dropped packet at
  /// 02:00 UTC doesn't page anyone. A hard failure after the retry is real.
  Future<dynamic> getJson(String url) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final req = await client.getUrl(Uri.parse(url));
        final res = await req.close().timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode} for $url');
        }
        final body = await res.transform(utf8.decoder).join();
        return jsonDecode(body);
      } catch (e) {
        lastError = e;
      }
    }
    fail('could not fetch $url after 2 tries: $lastError');
  }

  /// Every string anywhere in [node] that looks like a web URL.
  List<String> urlsIn(dynamic node) {
    final found = <String>[];
    void walk(dynamic n) {
      if (n is Map) {
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      } else if (n is String && RegExp(r'^https?://').hasMatch(n)) {
        found.add(n);
      }
    }

    walk(node);
    return found;
  }

  // 6.1 — the series manifest is the multi-series contract. A missing `language`
  // strands chrome resolution; a `hasBook: true` on the Urdu series would strand
  // installs older than the client that bundles the book asset (release-runbook
  // note; the client defaults `hasBook` itself and the manifest must NOT force it).
  test('series.json parses, every entry declares a language, and tawheed-ur '
      'never forces hasBook', () async {
    final manifest = await getJson(AppConfig.seriesManifestUrl);
    expect(manifest, isA<Map>());
    final series = (manifest as Map)['series'];
    expect(series, isA<List>(), reason: 'series.json must carry a `series` list');

    for (final entry in series as List) {
      final e = entry as Map;
      expect((e['language'] as String?)?.isNotEmpty, isTrue,
          reason: 'series ${e['id']} is missing `language`',);
      if (e['id'] == 'tawheed-ur') {
        expect(e['hasBook'], isNot(true),
            reason: 'tawheed-ur must NOT set hasBook:true in the manifest — the '
                'client defaults it, and forcing it here strands older installs',);
      }
    }
  });

  // 6.2 — the blank-label bug: an app_config.json that resolves branding to an
  // empty string paints a blank "Powered by" line. Parsed through the app's own
  // model so this tests the real resolution path, defaults included.
  test('app-config.json branding resolves to non-empty, https-only URLs',
      () async {
    final config = await getJson(AppConfig.appConfigUrl);
    final brandingJson =
        (config as Map)['branding'] as Map<String, dynamic>? ??
            <String, dynamic>{};
    final branding = AppConfigBranding.fromJson(brandingJson);

    expect(branding.publisher.trim(), isNotEmpty);
    expect(branding.poweredByLabel['en'], isNotEmpty);
    for (final url in [branding.appBrandUrl, branding.publisherUrl]) {
      expect(Uri.parse(url).scheme, 'https',
          reason: 'branding URL "$url" must be https or the app silently '
              'refuses to open it (safe_url_launcher allowlist)',);
    }
  });

  // 6.3 — the exact class of bug that shipped the dead "Powered by" link
  // (publisherUrl: http://almarfa.co). safe_url_launcher only opens https/mailto,
  // so any http:// URL anywhere in the live config is a silently-dead link.
  test('no live config serves an http:// URL', () async {
    final sources = {
      'app-config.json': AppConfig.appConfigUrl,
      'series.json': AppConfig.seriesManifestUrl,
      'catalog.json': AppConfig.catalogUrl,
      'feature-flags.json': AppConfig.featureFlagsUrl,
      'announcements.json': AppConfig.announcementsUrl,
    };

    final insecure = <String>[];
    for (final entry in sources.entries) {
      final json = await getJson(entry.value);
      for (final url in urlsIn(json)) {
        if (Uri.parse(url).scheme != 'https') {
          insecure.add('${entry.key}: $url');
        }
      }
    }
    expect(insecure, isEmpty,
        reason: 'non-https URLs (dead per the launcher allowlist):\n'
            '${insecure.join('\n')}',);
  });

  // 6.4 — ADR-0001: contentBaseUrl is compiled in, so a CDN move needs an app
  // release. If the manifest's catalogUrl points somewhere else, older installs
  // can't follow. Every catalogUrl host must equal the compiled base's host.
  test('every catalogUrl host matches the compiled contentBaseUrl host',
      () async {
    final baseHost = Uri.parse(AppConfig.contentBaseUrl).host;
    final manifest = await getJson(AppConfig.seriesManifestUrl) as Map;

    for (final entry in manifest['series'] as List) {
      final catalogUrl = (entry as Map)['catalogUrl'] as String;
      expect(Uri.parse(catalogUrl).host, baseHost,
          reason: '${entry['id']} catalogUrl host must be $baseHost '
              '(contentBaseUrl is compiled in — ADR-0001)',);
    }
  });
}
