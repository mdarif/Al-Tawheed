class AppConfig {
  AppConfig._();

  static const String contentBaseUrl = 'https://al-tawheed-content.pages.dev';
  static const String catalogUrl = '$contentBaseUrl/tawheed/catalog.json';

  // App aborts gracefully if the catalog schema version exceeds this.
  static const int maxSupportedCatalogVersion = 1;
}
