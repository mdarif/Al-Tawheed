import 'package:url_launcher/url_launcher.dart';

/// Schemes we permit when opening a URL that originated from remote,
/// attacker-influenceable content (the catalog, app-config, and announcement
/// feeds are fetched over the network and could be tampered with or poisoned).
///
/// Restricting to `https`/`mailto` blocks dangerous schemes such as `tel:`,
/// `sms:`, `market:`, `javascript:`, and Android's `intent:` (which can
/// escalate to launching arbitrary components).
const _allowedSchemes = {'https', 'mailto'};

/// Launches [url] in an external app, but only if it parses cleanly and uses
/// an allowlisted scheme. Returns `true` only when the OS accepted the launch;
/// a malformed URL, a disallowed scheme, or a platform failure all yield
/// `false` so callers can show a graceful fallback instead of trusting the
/// remote string.
Future<bool> launchExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !_allowedSchemes.contains(uri.scheme)) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
