class AppConfig {
  AppConfig._();

  // ── CDN base ────────────────────────────────────────────────────────────
  static const String contentBaseUrl = 'https://al-tawheed-content.pages.dev';

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
