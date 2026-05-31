import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/feature_flags_model.dart';
import 'package:myapp/services/remote_content_service.dart';

class FeatureFlagsProvider extends ChangeNotifier {
  FeatureFlagsModel _model = FeatureFlagsModel.defaults;

  FeatureFlags get features => _model.features;

  Future<void> load() async {
    try {
      final body = await RemoteContentService.fetch(
        url: AppConfig.featureFlagsUrl,
        cacheKey: 'feature_flags',
        ttlMs: AppConfig.featureFlagsCacheTtlMs,
      );
      final raw = jsonDecode(body) as Map<String, dynamic>;
      final model = FeatureFlagsModel.fromJson(raw);

      if (model.version > AppConfig.maxSupportedFeatureFlagsVersion) {
        return; // Keep defaults — unknown schema
      }

      _model = model;
      notifyListeners();
    } catch (_) {
      // Fetch failed — defaults remain active; no UI impact
    }
  }
}
