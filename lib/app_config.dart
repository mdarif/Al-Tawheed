class AppConfig {
  AppConfig._();

  // ── Brand ────────────────────────────────────────────────────────────────
  // Locale-invariant app/brand name — single source of truth for non-UI
  // surfaces (media/notification metadata, share text, welcome fallback).
  // Both series share this name; only the native-script title differs.
  // UI-facing copy is localised separately via the ARB (`appTitle`).
  static const String appTitle = 'Sharah Kitab at-Tawheed';

  // ── CDN base ────────────────────────────────────────────────────────────
  // Custom domain on kitabattawheed.com (Cloudflare anycast IPs reachable over
  // IPv4) rather than the *.pages.dev subdomain, whose 172.66.44.x IPv4 range
  // is TCP-reset on some ISPs and stranded fresh installs. See docs/gotchas.md.
  // NOTE: series.json's per-series catalogUrl values must also point here.
  static const String contentBaseUrl = 'https://content.kitabattawheed.com';

  // ── Remote JSON endpoints ────────────────────────────────────────────────
  static const String catalogUrl = '$contentBaseUrl/tawheed/catalog.json';
  static const String appConfigUrl = '$contentBaseUrl/tawheed/app-config.json';
  static const String featureFlagsUrl =
      '$contentBaseUrl/tawheed/feature-flags.json';
  static const String announcementsUrl =
      '$contentBaseUrl/tawheed/announcements.json';
  static const String seriesManifestUrl = '$contentBaseUrl/series.json';

  // ── Audio (Cloudflare R2 — Range requests / seeking) ────────────────────
  static const String audioBaseUrl =
      'https://pub-8a0d3971e9fd4d7c991d2300ca9bdca5.r2.dev';

  // ── Max supported schema versions ───────────────────────────────────────
  // Increment in app when Dart models support a newer schema.
  // If remote version > maxSupported, show "Please update the app."
  static const int maxSupportedCatalogVersion = 1;
  static const int maxSupportedAppConfigVersion = 1;
  static const int maxSupportedFeatureFlagsVersion = 1;
  static const int maxSupportedAnnouncementsVersion = 1;

  // ── Cache TTLs (milliseconds) ────────────────────────────────────────────
  static const int catalogCacheTtlMs = 60 * 60 * 1000; // 1 hour
  static const int appConfigCacheTtlMs = 60 * 60 * 1000; // 1 hour
  static const int featureFlagsCacheTtlMs = 5 * 60 * 1000; // 5 min
  static const int announcementsCacheTtlMs = 30 * 60 * 1000; // 30 min
  static const int seriesManifestCacheTtlMs = 60 * 60 * 1000; // 1 hour
}
