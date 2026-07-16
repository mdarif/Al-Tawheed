import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/language_provider.dart';
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

  // Branding labels moved from plain strings to i18n maps. Every published
  // app_config.json still sends plain strings, so the legacy shape has to keep
  // working indefinitely — an app that blanks its own footer on old config is
  // worse than one that never translated it.
  group('AppConfigBranding — localizable labels', () {
    test('reads the legacy plain-string shape', () {
      final b = AppConfigBranding.fromJson({
        'appBrand': 'Al Marfa Duroos',
        'poweredByLabel': 'Powered by Al Marfa Technologies',
      });

      expect(b.appBrand['en'], 'Al Marfa Duroos');
      expect(b.poweredByLabel['en'], 'Powered by Al Marfa Technologies');
    });

    test('reads an i18n map', () {
      final b = AppConfigBranding.fromJson({
        'poweredByLabel': {'en': 'Powered by X', 'ar': 'بدعم من س'},
      });

      expect(b.poweredByLabel['en'], 'Powered by X');
      expect(b.poweredByLabel['ar'], 'بدعم من س');
    });

    test('an absent field keeps the bundled default, not a blank label', () {
      final b = AppConfigBranding.fromJson({});

      expect(b.appBrand, AppConfigBranding.defaults.appBrand);
      expect(b.poweredByLabel, AppConfigBranding.defaults.poweredByLabel);
      expect(b.poweredByLabel['en'], isNotEmpty);
    });

    // toI18nMap yields {'en': ''} for a malformed value — merging over the
    // default rather than replacing it is what stops that blanking the footer.
    test('a malformed field cannot blank the label', () {
      final b = AppConfigBranding.fromJson({'poweredByLabel': 42});

      expect(b.poweredByLabel['en'], isNotEmpty);
    });

    test('a remote map without `en` still resolves through the default',
        () async {
      final b = AppConfigBranding.fromJson({
        'poweredByLabel': {'ar': 'بدعم من المرفأ'},
      });
      SharedPreferences.setMockInitialValues({});
      PreferencesService.instance.resetForTest();
      await PreferencesService.instance.init();

      expect(b.poweredByLabel['ar'], 'بدعم من المرفأ');
      // English readers fall back to the bundled label rather than an empty
      // string, because the remote map is merged over the default.
      expect(LanguageProvider().resolve(b.poweredByLabel),
          AppConfigBranding.defaults.poweredByLabel['en'],);
    });
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
