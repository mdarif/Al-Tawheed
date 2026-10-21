import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/settings/text_size_setting.dart';

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

// An edition with a book (Urdu, so the preview uses the Nastaliq family) and
// one without — Reading is only offered for the former.
const _seriesUrduBook = SeriesConfig(
  id: 'tawheed-ur',
  catalogUrl: 'https://example.com/tawheed-ur/catalog.json',
  storagePrefix: '',
  hasStudyMode: true,
  hasBook: true,
  language: 'ur',
  displayName: {'en': 'Kitab at-Tawheed (Urdu)'},
  speakerName: {'en': 'Shaikh Abdullah Nasir Rahmani Hafizahullah'},
);

const _settingsBook = BookContent(
  title: 'كتاب التوحيد',
  author: 'الشيخ',
  chapters: [
    BookChapter(
      id: 'ch-01',
      number: 1,
      title: 'الباب الأول',
      text:
          'ارشادِ باری تعالیٰ ہے: {وما خَلَقْتُ} [الذَّارِيَات: 56].\nثانی سطر',
    ),
  ],
);

const _settingsPreview =
    'ارشادِ باری تعالیٰ ہے: \u{FD3F}وما خَلَقْتُ\u{FD3E} [الذَّارِيَات: ۵۶].';

/// One shared fake: SharePlus caches the platform on first use (gotchas).
final _sharePlatform = _FakeSharePlatform();

class _FakeSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return ShareResult('', ShareResultStatus.success);
  }
}

Widget _wrap({
  required SeriesProvider series,
  LanguageProvider? language,
  bool multiSeries = true,
  bool appLinks = false,
  bool shareButton = false,
  bool downloads = false,
  // The app-language picker (default ON in prod) is turned OFF here so tests can
  // isolate the content-edition switcher — both render اردو/العربية rows, so a
  // test keying on those text finders would otherwise be ambiguous.
  bool languageFlag = false,
  BookContent? book,
  ReadingProvider? reading,
  DownloadsProvider? downloadsProvider,
  Locale? locale,
  double textScale = 1,
  List<String>? visitedRoutes,
}) {
  return MaterialApp.router(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: textScale == 1
        ? null
        : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
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
            shareButton: shareButton,
            downloads: downloads,
            languageFlag: languageFlag,
            book: book,
            reading: reading,
            downloadsProvider: downloadsProvider,
            child: const SettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/about',
          builder: (_, __) {
            visitedRoutes?.add('/about');
            return const Scaffold(body: Text('About route'));
          },
        ),
        GoRoute(
          path: '/library',
          builder: (_, state) {
            visitedRoutes?.add(state.uri.toString());
            return const Scaffold(body: Text('Library route'));
          },
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
  bool shareButton = false,
  bool downloads = false,
  bool languageFlag = false,
  BookContent? book,
  ReadingProvider? reading,
  DownloadsProvider? downloadsProvider,
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
            'shareButton': shareButton,
            'downloads': downloads,
            'language': languageFlag,
          }),
      ),
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider.value(
        value: language ?? (LanguageProvider()..load()),
      ),
      downloadsProvider != null
          ? ChangeNotifierProvider.value(value: downloadsProvider)
          : ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ChangeNotifierProvider(
        create: (_) => BookProvider()..setBookForTest(book ?? _settingsBook),
      ),
      reading != null
          ? ChangeNotifierProvider.value(value: reading)
          : ChangeNotifierProvider(
              create: (ctx) =>
                  ReadingProvider(ctx.read<SeriesProvider>())..load(),
            ),
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

  group('SettingsScreen — About section', () {
    testWidgets('is always visible, even with every flag off', (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(
        _wrap(series: series, appLinks: false, shareButton: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget); // section header
      expect(find.byKey(WidgetKeys.settingsAbout), findsOneWidget);
      expect(find.text('About this app'), findsOneWidget);
      // The old gated "App" section header is gone.
      expect(find.text('App'), findsNothing);
    });

    testWidgets('the About row opens the existing /about route',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);
      final visited = <String>[];

      await tester.pumpWidget(_wrap(series: series, visitedRoutes: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.settingsAbout));
      await tester.pumpAndSettle();

      expect(visited, ['/about']);
      expect(find.text('About route'), findsOneWidget);
    });

    testWidgets(
        'Share app is gated by shareButton alone (visible with appLinks off)',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(
        _wrap(series: series, appLinks: false, shareButton: true),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsShareApp), findsOneWidget);
      expect(find.text('Share app'), findsOneWidget);
      // appLinks is still off, so the outbound-link rows stay hidden.
      expect(find.byKey(WidgetKeys.settingsContactUs), findsNothing);
    });

    testWidgets('Share app is hidden when shareButton is off', (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      // Even with appLinks ON — only shareButton governs Share.
      await tester.pumpWidget(
        _wrap(series: series, appLinks: true, shareButton: false),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsShareApp), findsNothing);
      expect(find.text('Share app'), findsNothing);
    });

    testWidgets("Share app shares the remote config's share message",
        (tester) async {
      SharePlatform.instance = _sharePlatform;
      _sharePlatform.lastParams = null;
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, shareButton: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.settingsShareApp));
      await tester.pumpAndSettle();

      expect(
        _sharePlatform.lastParams?.text,
        AppConfigModel.defaults.share.message,
      );
    });

    testWidgets('Contact / Rate / YouTube are hidden when appLinks is off',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, appLinks: false));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsContactUs), findsNothing);
      expect(find.byKey(WidgetKeys.settingsRateApp), findsNothing);
      expect(find.byKey(WidgetKeys.settingsYouTube), findsNothing);
      expect(find.text('Contact Us'), findsNothing);
    });

    testWidgets(
        'Contact / Rate / YouTube show inside About when appLinks is on',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(_wrap(series: series, appLinks: true));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsContactUs), findsOneWidget);
      expect(find.byKey(WidgetKeys.settingsRateApp), findsOneWidget);
      expect(find.byKey(WidgetKeys.settingsYouTube), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Rate on Play Store'), findsOneWidget);
      expect(find.text('YouTube channel'), findsOneWidget);
      expect(find.text('Al Marfa Duroos'), findsOneWidget);
      // One section: the rows sit under the About header, not a separate "App".
      expect(find.text('App'), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(WidgetKeys.settingsContactUs)).dy,
        greaterThan(tester.getTopLeft(find.text('About')).dy),
      );
    });

    testWidgets('every About row is a ≥48dp target', (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);

      await tester.pumpWidget(
        _wrap(series: series, appLinks: true, shareButton: true),
      );
      await tester.pumpAndSettle();

      for (final key in [
        WidgetKeys.settingsAbout,
        WidgetKeys.settingsShareApp,
        WidgetKeys.settingsContactUs,
        WidgetKeys.settingsRateApp,
        WidgetKeys.settingsYouTube,
      ]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(48),
          reason: '$key',
        );
      }
    });
  });

  group('SettingsScreen — Our other apps', () {
    testWidgets(
      'shows on Android even with appLinks off',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final series = SeriesProvider()
          ..setAvailableSeriesForTest([_seriesUrdu])
          ..setCurrentSeriesForTest(_seriesUrdu);

        await tester.pumpWidget(_wrap(series: series, appLinks: false));
        await tester.pumpAndSettle();

        expect(find.text('Our other apps'), findsOneWidget);
        expect(find.text('Al Quran Reader'), findsOneWidget);
        expect(find.text('As-Sunnah Search'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'is hidden on iOS',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final series = SeriesProvider()
          ..setAvailableSeriesForTest([_seriesUrdu])
          ..setCurrentSeriesForTest(_seriesUrdu);

        await tester.pumpWidget(_wrap(series: series, appLinks: true));
        await tester.pumpAndSettle();

        expect(find.text('Our other apps'), findsNothing);
        expect(find.text('Al Quran Reader'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('SettingsScreen — Reading', () {
    testWidgets('shows the text-size control when the edition has a book',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrduBook])
        ..setCurrentSeriesForTest(_seriesUrduBook);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Reading'), findsOneWidget);
      expect(find.byType(TextSizeSetting), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
    });

    testWidgets('is hidden when the active edition has no book',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu); // hasBook: false

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Reading'), findsNothing);
      expect(find.byType(TextSizeSetting), findsNothing);
      expect(find.text('Text size'), findsNothing);
    });

    testWidgets('the slider spans 14–32 and a drag persists on release',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrduBook])
        ..setCurrentSeriesForTest(_seriesUrduBook);
      final reading = ReadingProvider(series)..load();

      await tester.pumpWidget(_wrap(series: series, reading: reading));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(
        find.byKey(WidgetKeys.settingsTextSizeSlider),
      );
      expect(slider.min, 14);
      expect(slider.max, 32);
      expect(slider.divisions, 9);

      await tester.drag(
        find.byKey(WidgetKeys.settingsTextSizeSlider),
        const Offset(400, 0),
      );
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 32.0);
      expect(PreferencesService.instance.bookFontSize, 32.0);
    });

    testWidgets('the A buttons move ±2 within 14–32 and persist',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrduBook])
        ..setCurrentSeriesForTest(_seriesUrduBook);
      final reading = ReadingProvider(series)..load();

      await tester.pumpWidget(_wrap(series: series, reading: reading));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.settingsTextSizeIncrease));
      await tester.pumpAndSettle();
      expect(reading.bookFontSize, 22.0);
      expect(PreferencesService.instance.bookFontSize, 22.0);

      await reading.setBookFontSize(32);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(WidgetKeys.settingsTextSizeIncrease))
            .onPressed,
        isNull,
      );

      await reading.setBookFontSize(14);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(WidgetKeys.settingsTextSizeDecrease))
            .onPressed,
        isNull,
      );
    });

    testWidgets("previews the book's own chapter-1 opening in its font",
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrduBook])
        ..setCurrentSeriesForTest(_seriesUrduBook);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      final preview = tester.widget<Text>(
        find.byKey(WidgetKeys.settingsTextSizePreview),
      );
      expect(
        preview.data ?? preview.textSpan?.toPlainText(),
        _settingsPreview,
      );
      expect(preview.style?.fontFamily, _seriesUrduBook.bookFontFamily);
      expect(preview.textDirection, TextDirection.rtl);
    });

    testWidgets('follows a size set elsewhere (pinch or the reader "Aa")',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrduBook])
        ..setCurrentSeriesForTest(_seriesUrduBook);
      final reading = ReadingProvider(series)..load();

      await tester.pumpWidget(_wrap(series: series, reading: reading));
      await tester.pumpAndSettle();

      reading.setBookFontSizeLive(28); // exactly what the pinch gesture writes
      await tester.pump();

      expect(
        tester
            .widget<Text>(find.byKey(WidgetKeys.settingsTextSizePreview))
            .style
            ?.fontSize,
        28.0,
      );
      expect(find.text('28'), findsOneWidget);
    });
  });

  group('SettingsScreen — section order', () {
    testWidgets(
      'Appearance · Reading · Content edition · App language · Playback · '
      'Downloads · About · Our other apps',
      (tester) async {
        tester.view.physicalSize = const Size(800, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final series = SeriesProvider()
          ..setAvailableSeriesForTest([_seriesUrduBook, _seriesArabic])
          ..setCurrentSeriesForTest(_seriesUrduBook);

        await tester.pumpWidget(
          _wrap(
            series: series,
            languageFlag: true,
            downloads: true,
            appLinks: true,
            shareButton: true,
          ),
        );
        await tester.pumpAndSettle();

        final order = [
          'Appearance',
          'Reading',
          'Content edition',
          'App language',
          'Playback',
          'Downloads',
          'About',
          'Our other apps',
        ];
        final tops = [
          for (final header in order)
            tester.getTopLeft(find.text(header).first).dy,
        ];
        expect(
          tops,
          orderedEquals([...tops]..sort()),
          reason: 'headers out of order: $tops',
        );
        expect(tops.toSet(), hasLength(order.length));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('SettingsScreen — RTL and 2× text', () {
    for (final locale in [
      const Locale('ar'),
      const Locale('ur'),
      const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
    ]) {
      testWidgets(
        'lays out every section without overflow in $locale',
        (tester) async {
          tester.view.physicalSize = const Size(360, 5000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final series = SeriesProvider()
            ..setAvailableSeriesForTest([_seriesUrduBook, _seriesArabic])
            ..setCurrentSeriesForTest(_seriesUrduBook);

          await tester.pumpWidget(
            _wrap(
              series: series,
              locale: locale,
              textScale: 2,
              languageFlag: true,
              downloads: true,
              appLinks: true,
              shareButton: true,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(TextSizeSetting), findsOneWidget);
          expect(
            find.byKey(WidgetKeys.settingsOtherAppsSection),
            findsOneWidget,
          );
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
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
    testWidgets('keeps Download-on-Wi-Fi-only visible on a tall phone viewport',
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
      expect(
        tester.getBottomLeft(find.text('Download on Wi-Fi only')).dy,
        lessThan(tester.view.physicalSize.height / 3.5),
      );
    });

    testWidgets(
        'has no Offline library or Clear rows — both live in Library › '
        'Downloads', (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);
      // Downloads present, so the old "Clear all downloads" row would show.
      final downloads = DownloadsProvider()..seedDownloadedForTest('lec-001');

      await tester.pumpWidget(
        _wrap(series: series, downloads: true, downloadsProvider: downloads),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.settingsDownloadOnWifiOnly), findsOneWidget);
      expect(find.byKey(WidgetKeys.settingsOfflineLibrary), findsNothing);
      expect(find.byIcon(Icons.storage_rounded), findsNothing);
      expect(find.text('No downloads yet'), findsNothing);
      expect(find.text('Clear all downloads'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('points to Library › Downloads and opens it on tap',
        (tester) async {
      final series = SeriesProvider()
        ..setAvailableSeriesForTest([_seriesUrdu])
        ..setCurrentSeriesForTest(_seriesUrdu);
      final visited = <String>[];

      await tester.pumpWidget(
        _wrap(series: series, downloads: true, visitedRoutes: visited),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Your downloaded lectures are in Library › Downloads.'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(WidgetKeys.settingsDownloadsHint)).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.byKey(WidgetKeys.settingsDownloadsHint));
      await tester.pumpAndSettle();

      expect(visited, ['/library?tab=downloads']);
      expect(find.text('Library route'), findsOneWidget);
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

  // AGENTS.md rule #1: every new user-facing string ships in all four ARBs.
  // test/arb_parity_test.dart proves the key sets match; this pins the P4 keys
  // by name (so a rename can't silently drop one) and the retired ⋮ label.
  group('P4 ARB keys', () {
    const locales = ['en', 'ar', 'ur', 'ur_roman'];
    const newKeys = [
      'settingsReading',
      'settingsTextSizeSmaller',
      'settingsTextSizeLarger',
      'settingsTextSizeHint',
      'settingsAboutApp',
      'settingsOtherApps',
      'settingsOtherAppsFooter',
      'settingsOtherAppOpensInPlay',
      'settingsOtherAppsOpenFailed',
      'settingsOtherAppsCopyLink',
      'otherAppQuranTagline',
      'otherAppAssunnahTagline',
      'settingsDownloadsHint',
    ];

    Map<String, dynamic> arb(String locale) => jsonDecode(
          File('lib/l10n/app_$locale.arb').readAsStringSync(),
        ) as Map<String, dynamic>;

    for (final locale in locales) {
      test('$locale defines every new key with a real value', () {
        final messages = arb(locale);
        for (final key in newKeys) {
          expect(messages[key], isA<String>(), reason: '$locale:$key');
          expect((messages[key] as String).trim(), isNotEmpty);
        }
      });

      test('$locale no longer ships the unused moreOptions label', () {
        expect(arb(locale).containsKey('moreOptions'), isFalse);
      });
    }

    test('translations differ from English where the script differs', () {
      final en = arb('en');
      for (final locale in ['ar', 'ur']) {
        final messages = arb(locale);
        for (final key in newKeys) {
          expect(messages[key], isNot(en[key]), reason: '$locale:$key');
        }
      }
    });
  });

  // Note: the /about page's own content lives in about_page_test.dart. The shell
  // ⋮ overflow menu is gone, so Settings › About and Share app (tested above)
  // are how users reach them.
}
