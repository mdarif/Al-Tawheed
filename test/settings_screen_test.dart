import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';

Map<String, dynamic> _catalogJson(String bookId) => {
      'version': 1,
      'book': {
        'id': bookId,
        'title': {'en': 'Test Book'},
        'titleArabic': '',
        'speaker': {'en': 'Speaker'},
        'totalDurationSeconds': 60,
        'lectureCount': 1,
        'coverImageUrl': '',
        'language': 'Arabic',
      },
      'chapters': <Map<String, dynamic>>[],
      'lectures': [
        {
          'id': 'lec-001',
          'number': 1,
          'chapterId': '',
          'title': {'en': 'Part 1'},
          'audioUrl': 'https://example.com/lec-001.mp3',
          'durationSeconds': 60,
          'fileSizeBytes': 1000,
        },
      ],
      'dailyBenefits': <Map<String, dynamic>>[],
    };

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
  bool multiSeries = true,
  bool appLinks = false,
  bool downloads = false,
  // The app-language picker (default ON in prod) is turned OFF here so tests can
  // isolate the content-edition switcher — both render اردو/العربية rows, so a
  // test keying on those text finders would otherwise be ambiguous.
  bool languageFlag = false,
}) {
  return MaterialApp.router(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => _settingsProviders(
            series: series,
            language: language,
            multiSeries: multiSeries,
            appLinks: appLinks,
            downloads: downloads,
            languageFlag: languageFlag,
            child: const SettingsScreen(),
          ),
        ),
      ],
    ),
  );
}

Widget _settingsProviders({
  required SeriesProvider series,
  required Widget child,
  LanguageProvider? language,
  bool multiSeries = true,
  bool appLinks = false,
  bool downloads = false,
  bool languageFlag = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppConfigProvider()),
      ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ChangeNotifierProvider(
        create: (_) => FeatureFlagsProvider()
          ..setExperimentalJsonForTest({'multiSeries': multiSeries})
          ..setFeaturesJsonForTest({
            'appLinks': appLinks,
            'downloads': downloads,
            'language': languageFlag,
          }),
      ),
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider.value(
        value: language ?? (LanguageProvider()..load()),
      ),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ChangeNotifierProvider(create: (_) => BookProvider()),
      ChangeNotifierProvider(
        create: (ctx) => StudyProgressProvider(
          ctx.read<ProgressProvider>(),
          ctx.read<CatalogProvider>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => PlayerNotifier(
          TawheedAudioHandler(),
          ctx.read<ProgressProvider>(),
          ctx.read<DownloadsProvider>(),
          ctx.read<ConnectivityProvider>(),
        ),
      ),
    ],
    child: child,
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

  group('SettingsScreen — content edition selector', () {
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
      expect(
        find.byKey(WidgetKeys.settingsSeriesOption(_seriesUrdu.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(WidgetKeys.settingsSeriesOption(_seriesArabic.id)),
        findsOneWidget,
      );

      // Each row previews the capabilities that change when switching:
      // Urdu has Study but no Book; Arabic has Book but no Study. Both
      // always show Audio.
      expect(find.text('Audio'), findsNWidgets(2));
      expect(find.text('Study Mode'), findsOneWidget);
      expect(find.text('Book'), findsOneWidget);
    });

    testWidgets(
        'switching editions confirms with a content-edition-worded dialog',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // Tap the non-current (Arabic) edition.
      await tester.tap(
        find.byKey(WidgetKeys.settingsSeriesOption(_seriesArabic.id)),
      );
      await tester.pumpAndSettle();

      // Dialog is worded around content edition, not "series" or "language" —
      // switching also changes teacher, catalogue, tabs, and scoped progress.
      expect(find.text('Change content edition?'), findsOneWidget);
      expect(find.textContaining('العربية'), findsWidgets);
    });

    testWidgets(
        'shows an in-progress spinner and blocks a second tap while '
        'switching', (tester) async {
      await PreferencesService.instance.saveRemoteJson(
        'catalog_tawheed-ar',
        jsonEncode(_catalogJson('arabic-book')),
      );

      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(WidgetKeys.settingsSeriesOption(_seriesArabic.id)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Change content edition?'), findsOneWidget);

      // Confirm the switch, then check state before it has resolved.
      await tester.tap(find.text('Switch'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final absorbing = tester
          .widgetList<AbsorbPointer>(find.byType(AbsorbPointer))
          .any((a) => a.absorbing);
      expect(absorbing, isTrue);

      // Let the switch finish so the test doesn't leak a pending timer.
      await tester.runAsync(() async {
        while (series.currentSeries.id != _seriesArabic.id) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      await tester.pumpAndSettle();
    });
  });

  group('SettingsScreen — edition switcher visibility', () {
    testWidgets('edition switcher is hidden when multi-series is off',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, multiSeries: false));
      await tester.pumpAndSettle();

      // No edition rows (and the manual Language picker is off by default too).
      expect(find.text('اردو'), findsNothing);
      expect(find.text('العربية'), findsNothing);
      expect(
        find.byKey(WidgetKeys.settingsSeriesOption(_seriesArabic.id)),
        findsNothing,
      );
    });

    testWidgets(
        'edition switcher is shown when multi-series is on with >1 edition '
        '(no separate opt-in flag)', (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, multiSeries: true));
      await tester.pumpAndSettle();

      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('edition switcher is hidden when only one edition is available',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, multiSeries: true));
      await tester.pumpAndSettle();

      expect(find.text('اردو'), findsNothing);
      expect(find.text('العربية'), findsNothing);
    });
  });

  group('SettingsScreen — app-language picker (independent of edition)', () {
    testWidgets(
        'renders under its own header, separate from the '
        'content-edition switcher', (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(
        _wrap(series: series, multiSeries: true, languageFlag: true),
      );
      await tester.pumpAndSettle();

      // Two distinct section headers: the content edition switcher ("Content
      // edition") and the app/chrome language picker ("App language") —
      // proving they read as separate, independent axes without shouting in
      // all caps.
      expect(find.text('Content edition'), findsOneWidget);
      expect(find.text('App language'), findsOneWidget);
      expect(find.text('LANGUAGE'), findsNothing);
      expect(find.text('APP LANGUAGE'), findsNothing);
      // The UI picker offers English, which the edition switcher never does.
      expect(find.text('English'), findsWidgets);
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

      expect(find.text('App'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('YouTube channel'), findsOneWidget);
      expect(find.text('Al Marfa Duroos'), findsOneWidget);
    });
  });

  group('SettingsScreen — playback speed', () {
    testWidgets('opens the speed selector from a compact settings row',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Playback speed'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('0.75x'), findsNothing);

      await tester.tap(find.text('Playback speed'));
      await tester.pumpAndSettle();

      expect(find.text('0.75x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
    });
  });

  group('SettingsScreen — downloads', () {
    testWidgets(
        'keeps the offline library row visible on a tall phone viewport',
        (tester) async {
      tester.view.physicalSize = const Size(1272, 2800);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu, _seriesArabic])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(
        _wrap(series: series, multiSeries: true, downloads: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Downloads'), findsWidgets);
      expect(find.byKey(WidgetKeys.settingsDownloadOnWifiOnly), findsOneWidget);

      final downloadsRowBottom =
          tester.getBottomLeft(find.text('No downloads yet')).dy;

      expect(
        downloadsRowBottom,
        lessThan(tester.view.physicalSize.height / 3.5),
      );
    });

    testWidgets('shows offline library even before anything is downloaded',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => _settingsProviders(
              series: series,
              downloads: true,
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/offline-library',
            builder: (_, __) => const Scaffold(body: Text('Offline route')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Downloads'), findsWidgets);
      expect(find.byKey(WidgetKeys.settingsDownloadOnWifiOnly), findsOneWidget);
      expect(find.text('No downloads yet'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);

      await tester.tap(find.byKey(WidgetKeys.settingsOfflineLibrary));
      await tester.pumpAndSettle();

      expect(find.text('Offline route'), findsOneWidget);
    });

    testWidgets('hides the Wi-Fi-only control when downloads are disabled',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsDownloadOnWifiOnly), findsNothing);
    });

    group('notification permission recovery', () {
      tearDown(() {
        DownloadNotificationService.instance.areNotificationsEnabledForTest =
            null;
      });

      testWidgets(
          'stays hidden if notifications were never asked about, even when '
          'off', (tester) async {
        DownloadNotificationService.instance.areNotificationsEnabledForTest =
            false;
        final series = SeriesProvider()
          ..setAvailableSeriesForTest([_seriesUrdu])
          ..setCurrentSeriesForTest(_seriesUrdu);

        await tester.pumpWidget(_wrap(series: series, downloads: true));
        await tester.pumpAndSettle();

        expect(find.text('Download notifications'), findsNothing);
      });

      testWidgets('shows recovery once asked and currently disabled',
          (tester) async {
        await PreferencesService.instance
            .saveHasAskedDownloadNotificationPermission();
        DownloadNotificationService.instance.areNotificationsEnabledForTest =
            false;
        final series = SeriesProvider()
          ..setAvailableSeriesForTest([_seriesUrdu])
          ..setCurrentSeriesForTest(_seriesUrdu);

        await tester.pumpWidget(_wrap(series: series, downloads: true));
        await tester.pumpAndSettle();

        expect(find.text('Download notifications'), findsOneWidget);
        expect(
          find.textContaining("Turned off"),
          findsOneWidget,
        );
      });

      testWidgets('stays hidden once asked when notifications are enabled',
          (tester) async {
        await PreferencesService.instance
            .saveHasAskedDownloadNotificationPermission();
        DownloadNotificationService.instance.areNotificationsEnabledForTest =
            true;
        final series = SeriesProvider()
          ..setAvailableSeriesForTest([_seriesUrdu])
          ..setCurrentSeriesForTest(_seriesUrdu);

        await tester.pumpWidget(_wrap(series: series, downloads: true));
        await tester.pumpAndSettle();

        expect(find.text('Download notifications'), findsNothing);
      });
    });
  });

  // Note: Bookmarks / About / Settings are now reached from the ⋯ overflow
  // menu (see app_overflow_menu_test.dart); About content lives in
  // about_page_test.dart. Settings itself is pure config.
}
