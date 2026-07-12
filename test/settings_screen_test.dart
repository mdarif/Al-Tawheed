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

Widget _wrap({
  required SeriesProvider series,
  LanguageProvider? language,
  bool seriesSwitcher = true,
  bool appLinks = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppConfigProvider()),
      ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ChangeNotifierProvider(
        create: (_) => FeatureFlagsProvider()
          ..setExperimentalJsonForTest({'multiSeries': true})
          ..setFeaturesJsonForTest({
            'seriesSwitcher': seriesSwitcher,
            'appLinks': appLinks,
          }),
      ),
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider.value(
          value: language ?? (LanguageProvider()..load()),),
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

  group('SettingsScreen — content language selector', () {
    testWidgets('lists each edition as a language endonym with the teacher',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // Language endonyms as titles — not the internal edition/series name.
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('Kitab at-Tawheed (Urdu)'), findsNothing);

      // Teacher carried as the row subtitle for each edition.
      expect(
        find.text('Shaikh Abdullah Nasir Rahmani Hafizahullah'),
        findsOneWidget,
      );
      expect(
        find.text('Shaikh Salih al-Fawzan Hafizhahullah'),
        findsOneWidget,
      );
    });

    testWidgets('switching editions confirms with a language-worded dialog',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // Tap the non-current (Arabic) edition.
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      // Dialog is worded around language, not "series".
      expect(find.text('Change language?'), findsOneWidget);
      expect(find.textContaining('العربية'), findsWidgets);
    });
  });

  group('SettingsScreen — content language feature flag', () {
    testWidgets('language section is hidden when seriesSwitcher flag is off',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, seriesSwitcher: false));
      await tester.pumpAndSettle();

      // No edition rows (and the manual Language picker is off by default too).
      expect(find.text('اردو'), findsNothing);
      expect(find.text('العربية'), findsNothing);
    });

    testWidgets('language section is shown when seriesSwitcher flag is on',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, seriesSwitcher: true));
      await tester.pumpAndSettle();

      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });
  });

  group('SettingsScreen — App section feature flag', () {
    testWidgets('App section is hidden when appLinks flag is off (default)',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, appLinks: false));
      await tester.pumpAndSettle();

      // Section header and its rows are gone.
      expect(find.text('APP'), findsNothing);
      expect(find.text('Contact Us'), findsNothing);
    });

    testWidgets('App section is shown when appLinks flag is on',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, appLinks: true));
      await tester.pumpAndSettle();

      expect(find.text('APP'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
    });
  });

  // Note: About (with the website link) moved out of Settings into its own
  // AboutPage — those assertions now live in about_page_test.dart.

  group('SettingsScreen — secondary destinations', () {
    testWidgets('shows Bookmarks and About rows (reached via the Home gear)',
        (tester) async {
      // Tall surface so the lazy ListView builds the rows at the bottom.
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Saved'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'About'), findsOneWidget);
    });
  });
}
