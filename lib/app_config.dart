class AppConfig {
  AppConfig._();

  // catalog.json — served from Cloudflare Pages (no Range requests needed)
  static const String contentBaseUrl = 'https://al-tawheed-content.pages.dev';
  static const String catalogUrl = '$contentBaseUrl/tawheed/catalog.json';

  // Audio files — served from Cloudflare R2 (Range requests / seeking supported)
  static const String audioBaseUrl =
      'https://pub-8a0d3971e9fd4d7c991d2300ca9bdca5.r2.dev';

  // App aborts gracefully if the catalog schema version exceeds this.
  static const int maxSupportedCatalogVersion = 1;
}
