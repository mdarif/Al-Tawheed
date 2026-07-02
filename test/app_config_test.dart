import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_config.dart';

// Guards the CDN base URL. The content CDN moved off *.pages.dev (whose
// 172.66.44.x IPv4 range is TCP-reset on some ISPs, stranding fresh installs)
// onto the custom domain content.kitabattawheed.com. See docs/gotchas.md.
void main() {
  group('AppConfig CDN URLs', () {
    test('content base is the custom domain, never *.pages.dev', () {
      expect(AppConfig.contentBaseUrl, 'https://content.kitabattawheed.com');
      expect(AppConfig.contentBaseUrl, isNot(contains('pages.dev')));
    });

    test('all remote JSON endpoints are https under the content base', () {
      final urls = [
        AppConfig.catalogUrl,
        AppConfig.appConfigUrl,
        AppConfig.featureFlagsUrl,
        AppConfig.announcementsUrl,
        AppConfig.seriesManifestUrl,
      ];
      for (final u in urls) {
        expect(u, startsWith('https://content.kitabattawheed.com/'));
      }
    });

    test('audio stays on R2 (Range-request support for seeking)', () {
      expect(AppConfig.audioBaseUrl, contains('r2.dev'));
    });
  });
}
