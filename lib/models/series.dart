import 'package:myapp/app_config.dart';
import 'package:myapp/models/i18n_field.dart';

/// Describes one content series (e.g. "Kitab at-Tawheed (Urdu)" or
/// "Kitab at-Tawheed (Arabic)") as published in the remote `series.json`
/// manifest.
class SeriesConfig {
  final String id;
  final String catalogUrl;
  final String storagePrefix;
  final bool hasStudyMode;
  final bool hasBook;
  final String language;
  final Map<String, dynamic> displayName;
  final Map<String, dynamic> speakerName;

  const SeriesConfig({
    required this.id,
    required this.catalogUrl,
    required this.storagePrefix,
    required this.hasStudyMode,
    required this.hasBook,
    required this.language,
    required this.displayName,
    required this.speakerName,
  });

  /// Whether this series' content (titles, speaker names, lecture
  /// titles, etc.) is right-to-left Arabic — used to force Arabic-script
  /// display for that content independent of the app's UI language, which
  /// governs navigation/chrome separately.
  bool get isRtl => language == 'ar';

  factory SeriesConfig.fromJson(Map<String, dynamic> json) => SeriesConfig(
        id: json['id'] as String,
        catalogUrl: json['catalogUrl'] as String,
        storagePrefix: json['storagePrefix'] as String? ?? '',
        hasStudyMode: json['hasStudyMode'] as bool? ?? false,
        hasBook: json['hasBook'] as bool? ?? false,
        language: json['language'] as String? ?? 'en',
        displayName: toI18nMap(json['displayName']),
        speakerName: toI18nMap(json['speakerName']),
      );

  /// Id of the legacy Urdu series — used as a default-parameter constant
  /// since `legacyUrduFallback.id` is not itself a constant expression.
  static const String legacyId = 'tawheed-ur';

  /// Bundled fallback mirroring today's Urdu series — used when the
  /// multi-series feature flag is off, or when the `series.json` manifest
  /// cannot be fetched and no cache exists yet.
  static const legacyUrduFallback = SeriesConfig(
    id: legacyId,
    catalogUrl: AppConfig.catalogUrl,
    storagePrefix: '',
    hasStudyMode: true,
    hasBook: false,
    language: 'ur',
    displayName: {'en': 'Kitab at-Tawheed (Urdu)'},
    speakerName: {'en': 'Shaikh Abdullah Nasir Rahmani Hafizahullah'},
  );
}
