import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/services/remote_content_service.dart';

enum RemoteStatus { idle, loading, loaded, error }

class AppConfigProvider extends ChangeNotifier {
  AppConfigModel _config = AppConfigModel.defaults;
  RemoteStatus _status = RemoteStatus.idle;

  AppConfigModel get config => _config;
  RemoteStatus get status => _status;

  Future<void> load() async {
    if (_status == RemoteStatus.loading) return;
    _status = RemoteStatus.loading;
    notifyListeners();

    try {
      final body = await RemoteContentService.fetch(
        url: AppConfig.appConfigUrl,
        cacheKey: 'app_config',
        ttlMs: AppConfig.appConfigCacheTtlMs,
      );
      final raw = jsonDecode(body) as Map<String, dynamic>;
      final model = AppConfigModel.fromJson(raw);

      if (model.version > AppConfig.maxSupportedAppConfigVersion) {
        // Version too new — keep defaults, don't crash
        _status = RemoteStatus.loaded;
        notifyListeners();
        return;
      }

      _config = model;
      _status = RemoteStatus.loaded;
    } catch (e) {
      debugPrint('AppConfigProvider: fetch failed: $e');
      _status = RemoteStatus.error;
    }
    notifyListeners();
  }
}
