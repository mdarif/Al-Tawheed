import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

// Both series carry an 'ur' translation in displayName that differs from the
// canonical 'en' name — proving the picker shows the canonical name even
// when the UI language is Urdu.
const _seriesUrdu = SeriesConfig(
  id: 'tawheed-ur',
  catalogUrl: 'https://example.com/tawheed-ur/catalog.json',
  storagePrefix: '',
  hasStudyMode: true,
  hasBook: false,
  language: 'ur',
  displayName: {
    'en': 'Kitab at-Tawheed (Urdu)',
    'ur': 'کتاب التوحید (اردو)',
  },
  speakerName: {'en': 'Shaikh Abdullah Nasir Rahmani Hafizahullah'},
);

const _seriesArabic = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

Widget _wrap({required SeriesProvider series, LanguageProvider? language}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppConfigProvider()),
      ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ChangeNotifierProvider(
        create: (_) => FeatureFlagsProvider()
          ..setExperimentalJsonForTest({'multiSeries': true}),
      ),
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider.value(
          value: language ?? (LanguageProvider()..load())),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ChangeNotifierProvider(
        create: (ctx) => PlayerNotifier(
          TawheedAudioHandler(),
          ctx.read<ProgressProvider>(),
          ctx.read<DownloadsProvider>(),
          ctx.read<ConnectivityProvider>(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
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

  group('SettingsScreen — series picker canonical names', () {
    testWidgets(
        'series section shows the canonical English name, even with Urdu UI',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      final language = LanguageProvider()..load();
      language.applyLanguageFeatureFlag(true);
      await language.setLanguage(AppLanguage.urdu);

      await tester.pumpWidget(_wrap(series: series, language: language));
      await tester.pumpAndSettle();

      expect(find.text('Kitab at-Tawheed (Urdu)'), findsOneWidget);
      expect(find.text('کتاب التوحید (اردو)'), findsNothing);
    });

    testWidgets('picker sheet lists canonical names for both series',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kitab at-Tawheed (Urdu)'));
      await tester.pumpAndSettle();

      // Section title (page body) + picker entry.
      expect(find.text('Kitab at-Tawheed (Urdu)'), findsNWidgets(2));
      expect(find.text('Kitab at-Tawheed (Arabic)'), findsOneWidget);
    });

    testWidgets('confirm dialog names the chosen series by its canonical name',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kitab at-Tawheed (Urdu)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kitab at-Tawheed (Arabic)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"Kitab at-Tawheed (Arabic)"'),
          findsOneWidget);
    });
  });
}
