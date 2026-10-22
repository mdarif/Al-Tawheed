import 'dart:async';
import 'dart:io';

/// An [HttpOverrides] whose connections never complete: no refusal, no reset,
/// no response. This is what a captive portal, a dropped Wi-Fi uplink, a
/// DNS server that never answers, or a CDN route that swallows packets looks
/// like to the app — the failure mode where a fetch does not *fail*, it just
/// never finishes. (Offline is the easy case: it fails fast.)
///
/// Install with `HttpOverrides.global = BlackHoleHttpOverrides();` and restore
/// the previous value in a `tearDown`.
class BlackHoleHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) =>
        Completer<ConnectionTask<Socket>>().future;
    return client;
  }
}
