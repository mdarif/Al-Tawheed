import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/about_page.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

// About was split out of Settings into its own page (reached via the Settings
// "About" row). These pin the About content that used to live in Settings.
Widget _wrap() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppConfigProvider()),
      ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      // The About stats render their numbers in the active edition's numerals.
      ChangeNotifierProvider(create: (_) => SeriesProvider()..load(false)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AboutPage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    PackageInfo.setMockInitialValues(
      appName: 'Al-Tawheed',
      packageName: 'com.almarfa.tawheed',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('shows the website as a bare domain, exactly once',
      (tester) async {
    // Tall surface so the whole page builds for reliable duplicate counting.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Defaults (AppConfigModel.defaults) carry https://kitabattawheed.com.
    expect(find.text('kitabattawheed.com'), findsOneWidget);
  });

  testWidgets('shows the version once package info resolves', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('1.0.0'), findsOneWidget);
  });
}
