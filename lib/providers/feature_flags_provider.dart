import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/feature_flags_model.dart';
import 'package:myapp/services/remote_content_service.dart';

class FeatureFlagsProvider extends ChangeNotifier {
  Map<String, dynamic> _featuresJson = const {};
  Map<String, dynamic> _experimentalJson = const {};

  // True once the async fetch has settled (success, failure, or unknown
  // schema). The ProxyProvider uses this to distinguish the initial
  // synchronous update() call — where fields still hold defaults — from a
  // real, post-fetch update. Without this guard the ProxyProvider fires
  // immediately with multiSeriesEnabled=false and SeriesProvider marks itself
  // ready with the Urdu fallback before any flags have been read.
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  /// Parsed on each read so new flags keys stay safe across hot reload and
  /// partial CDN JSON (missing keys fall back via [FeatureFlags.fromJson]).
  FeatureFlags get features => FeatureFlags.fromJson(_featuresJson);

  /// Whether multi-series support (series picker + switcher) is enabled.
  /// Defaults to `false` — until `series.json` and the Arabic catalog/audio
  /// are live, the app behaves exactly as it does today.
  bool get multiSeriesEnabled => _experimentalJson['multiSeries'] == true;

  Future<void> load() async {
    try {
      final body = await RemoteContentService.fetch(
        url: AppConfig.featureFlagsUrl,
        cacheKey: 'feature_flags',
        ttlMs: AppConfig.featureFlagsCacheTtlMs,
      );
      final raw = jsonDecode(body) as Map<String, dynamic>;
      final version = raw['version'] as int? ?? 1;

      if (version <= AppConfig.maxSupportedFeatureFlagsVersion) {
        _featuresJson = Map<String, dynamic>.from(
          raw['features'] as Map<String, dynamic>? ?? {},
        );
        _experimentalJson = Map<String, dynamic>.from(
          raw['experimental'] as Map<String, dynamic>? ?? {},
        );
      }
      // Unknown schema: keep defaults but still mark as loaded.
    } catch (e) {
      debugPrint('FeatureFlagsProvider: fetch failed: $e');
    } finally {
      _hasLoaded = true;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setFeaturesJsonForTest(Map<String, dynamic> json) {
    _featuresJson = json;
    notifyListeners();
  }

  @visibleForTesting
  void setExperimentalJsonForTest(Map<String, dynamic> json) {
    _experimentalJson = json;
    notifyListeners();
  }
}
