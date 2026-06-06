import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/feature_flags_model.dart';
import 'package:myapp/services/remote_content_service.dart';

class FeatureFlagsProvider extends ChangeNotifier {
  Map<String, dynamic> _featuresJson = const {};

  /// Parsed on each read so new flags keys stay safe across hot reload and
  /// partial CDN JSON (missing keys fall back via [FeatureFlags.fromJson]).
  FeatureFlags get features => FeatureFlags.fromJson(_featuresJson);

  Future<void> load() async {
    try {
      final body = await RemoteContentService.fetch(
        url: AppConfig.featureFlagsUrl,
        cacheKey: 'feature_flags',
        ttlMs: AppConfig.featureFlagsCacheTtlMs,
      );
      final raw = jsonDecode(body) as Map<String, dynamic>;
      final version = raw['version'] as int? ?? 1;

      if (version > AppConfig.maxSupportedFeatureFlagsVersion) {
        return; // Keep defaults — unknown schema
      }

      _featuresJson = Map<String, dynamic>.from(
        raw['features'] as Map<String, dynamic>? ?? {},
      );
      notifyListeners();
    } catch (_) {
      // Fetch failed — defaults remain active; no UI impact
    }
  }

  @visibleForTesting
  void setFeaturesJsonForTest(Map<String, dynamic> json) {
    _featuresJson = json;
    notifyListeners();
  }
}
