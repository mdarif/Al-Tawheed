import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/safe_url_launcher.dart';

// The rejection paths short-circuit before calling url_launcher's platform
// channel, so they run in a pure unit test. The success (https) path would
// hit the platform channel and is covered by widget-level tests instead.
void main() {
  group('launchExternalUrl — scheme allowlist', () {
    test('rejects tel: scheme', () async {
      expect(await launchExternalUrl('tel:+15551234'), isFalse);
    });

    test('rejects sms: scheme', () async {
      expect(await launchExternalUrl('sms:+15551234'), isFalse);
    });

    test('rejects android intent: scheme (component-escalation vector)',
        () async {
      expect(
        await launchExternalUrl(
          'intent://evil#Intent;scheme=x;package=com.evil;end',
        ),
        isFalse,
      );
    });

    test('rejects javascript: scheme', () async {
      expect(await launchExternalUrl('javascript:alert(1)'), isFalse);
    });

    test('rejects market: scheme', () async {
      expect(await launchExternalUrl('market://details?id=com.evil'), isFalse);
    });

    test('rejects http: (cleartext) scheme', () async {
      expect(await launchExternalUrl('http://example.com'), isFalse);
    });

    test('rejects empty and schemeless strings', () async {
      expect(await launchExternalUrl(''), isFalse);
      expect(await launchExternalUrl('example.com/path'), isFalse);
    });
  });
}
