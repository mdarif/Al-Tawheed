import 'package:flutter/foundation.dart';
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

  /// Font family used to render this series' bundled Book text (chapter list +
  /// reader). Urdu content renders in **Nastaliq** (Noto Nastaliq Urdu) to
  /// match the print; Arabic content uses Naskh. The Book screens resolve the
  /// font from here rather than hardcoding it.
  String get bookFontFamily =>
      language == 'ur' ? 'NotoNastaliqUrdu' : 'NotoNaskhArabic';

  factory SeriesConfig.fromJson(Map<String, dynamic> json) {
    // id keys all per-series state and catalogUrl is the fetch target — a
    // series missing either is unusable, so throw and let the manifest parser
    // skip just this entry rather than defaulting to a broken series.
    final id = json['id'];
    final catalogUrl = json['catalogUrl'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('series: missing "id"');
    }
    if (catalogUrl is! String || catalogUrl.isEmpty) {
      throw const FormatException('series: missing "catalogUrl"');
    }
    return SeriesConfig(
      id: id,
      catalogUrl: catalogUrl,
      storagePrefix: json['storagePrefix'] as String? ?? '',
      hasStudyMode: json['hasStudyMode'] as bool? ?? false,
      // The legacy Urdu series ships its Book as a bundled asset in this app
      // version, so it defaults to having a Book tab even when series.json
      // omits the flag. This ties the Book tab to what the app ACTUALLY
      // bundles (older app versions have neither this default nor the asset,
      // so they stay unaffected) instead of a coordinated series.json deploy.
      // An explicit `hasBook: false` in the manifest still wins.
      hasBook: json['hasBook'] as bool? ?? (id == legacyId),
      // `language` drives the default chrome language and the Book font, so a
      // manifest omitting it is a content bug — but deliberately neither fatal
      // nor an assert. Throwing makes the manifest parser skip the whole entry
      // (see SeriesManifestService), which would demote a returning Arabic
      // reader into the Urdu edition with their downloads orphaned: losing an
      // edition is far worse than this fallback, which merely degrades to
      // device-detected chrome — today's behaviour — rather than to anything
      // wrong. An assert would additionally make this branch unreachable from
      // tests, which run in debug. Complain in the log and stay visible in the
      // UI instead: 'en' yields Western digits, which read as obviously-unset
      // rather than as a deliberate script. `language` is documented required.
      language: () {
        final language = json['language'];
        if (language is String && language.isNotEmpty) return language;
        debugPrint('series "$id": manifest omits "language" — assuming "en"');
        return 'en';
      }(),
      displayName: toI18nMap(json['displayName']),
      speakerName: toI18nMap(json['speakerName']),
    );
  }

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
    // The Urdu series now ships a Book tab. Interim: `book_tawheed-ur.json` is
    // a placeholder copy of the Arabic matn until the clean Urdu text lands
    // (swap the asset, no code change). Production reveals the tab via
    // series.json's `hasBook` once an asset-bearing release has rolled out.
    hasBook: true,
    language: 'ur',
    displayName: {'en': 'Kitab at-Tawheed (Urdu)'},
    speakerName: {'en': 'Shaikh Abdullah Nasir Rahmani Hafizahullah'},
  );
}
