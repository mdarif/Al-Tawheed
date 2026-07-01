import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/services/preferences_service.dart';

Map<String, dynamic> _configJson({
  int version = 1,
  String email = 'test@example.com',
  String website = 'https://test.example.com',
}) =>
    {
      'version': version,
      'links': {'website': website},
      'contact': {'email': email, 'subject': 'Test'},
      'share': {'message': 'Test message'},
      'about': {
        'appName': 'Test App',
        'lectureCount': 10,
        'classCount': 5,
        'totalDuration': '5h',
      },
      'branding': {'appBrand': 'Test Brand'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('AppConfigProvider — initial state', () {
    test('starts idle with the hardcoded defaults', () {
      final p = AppConfigProvider();
      expect(p.status, RemoteStatus.idle);
      // Hardcoded defaults are always safe as the fallback.
      expect(p.config.contact.email, AppConfigModel.defaults.contact.email);
      expect(p.config.links.website, AppConfigModel.defaults.links.website);
    });
  });

  group('AppConfigProvider — load()', () {
    test('applies the config from the seeded cache', () async {
      await PreferencesService.instance.saveRemoteJson(
        'app_config',
        jsonEncode(_configJson(email: 'cached@example.com')),
      );

      final p = AppConfigProvider();
      await p.load();

      expect(p.status, RemoteStatus.loaded);
      expect(p.config.contact.email, 'cached@example.com');
      expect(p.config.links.website, 'https://test.example.com');
    });

    test('keeps defaults and status=loaded when version exceeds the supported maximum',
        () async {
      // AppConfig.maxSupportedAppConfigVersion == 1; version 999 must be ignored.
      await PreferencesService.instance.saveRemoteJson(
        'app_config',
        jsonEncode(_configJson(version: 999, email: 'new-schema@example.com')),
      );

      final p = AppConfigProvider();
      await p.load();

      // Graceful skip: status = loaded (not an error), config untouched.
      expect(p.status, RemoteStatus.loaded);
      expect(p.config.contact.email, AppConfigModel.defaults.contact.email);
    });

    test('sets status=error and keeps defaults when the fetch fails', () async {
      // No cache seeded — RemoteContentService throws; load() must not rethrow.
      final p = AppConfigProvider();
      await p.load();

      expect(p.status, RemoteStatus.error);
      expect(p.config.contact.email, AppConfigModel.defaults.contact.email);
    });

    test('a concurrent call while already loading is a no-op', () async {
      await PreferencesService.instance.saveRemoteJson(
        'app_config',
        jsonEncode(_configJson()),
      );

      final p = AppConfigProvider();
      final f1 = p.load();
      // Second call: status is already loading, so it returns immediately.
      final f2 = p.load();
      await Future.wait([f1, f2]);

      expect(p.status, RemoteStatus.loaded);
    });
  });
}
