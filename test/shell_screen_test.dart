import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

Lecture _arabicLec() => Lecture(
      id: 'l1',
      number: 1,
      chapterId: 'ch-1',
      title: const {'en': 'Dars 02', 'ar': 'الدرس 2'},
      audioUrl: 'https://example.com/l1.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1048576,
    );

Catalog _arabicCatalog() => Catalog(
      version: 1,
      book: const Book(
        id: 'arabic-book',
        title: {'en': 'Kitab at-Tawheed', 'ar': 'كتاب التوحيد'},
        speaker: {
          'en': 'Shaikh Salih al-Fawzan Hafizahullah',
          'ar': 'الشيخ صالح الفوزان حفظه الله',
        },
        totalDurationSeconds: 3000,
        lectureCount: 5,
        coverImageUrl: '',
        language: 'Arabic',
      ),
      chapters: const [],
      lectures: [_arabicLec()],
      dailyBenefits: const [],
    );

Widget _wrap({
  required SeriesProvider series,
  String initialLocation = '/lectures',
  Catalog? catalog,
  PlayerNotifier? player,
  ProgressProvider? progress,
  DownloadsProvider? downloads,
  ConnectivityProvider? connectivity,
}) {
  final catalogProvider = CatalogProvider();
  if (catalog != null) {
    catalogProvider.setCatalogForTest(catalog);
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
      connectivity != null
          ? ChangeNotifierProvider.value(value: connectivity)
          : ChangeNotifierProvider(
              create: (_) => ConnectivityProvider.testOnline()),
      progress != null
          ? ChangeNotifierProvider.value(value: progress)
          : ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      downloads != null
          ? ChangeNotifierProvider.value(value: downloads)
          : ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      player != null
          ? ChangeNotifierProvider.value(value: player)
          : ChangeNotifierProvider(
              create: (ctx) => PlayerNotifier(
                TawheedAudioHandler(),
                ctx.read<ProgressProvider>(),
                ctx.read<DownloadsProvider>(),
                ctx.read<ConnectivityProvider>(),
              ),
            ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: initialLocation,
        routes: [
          ShellRoute(
            builder: (context, state, child) => ShellScreen(child: child),
            routes: [
              GoRoute(
                path: '/lectures',
                builder: (_, __) =>
                    const Scaffold(body: Center(child: Text('Lectures'))),
              ),
              GoRoute(
                path: '/book',
                builder: (_, __) =>
                    const Scaffold(body: Center(child: Text('Book'))),
              ),
              GoRoute(
                path: '/home',
                builder: (_, __) =>
                    const Scaffold(body: Center(child: Text('Home'))),
              ),
              GoRoute(
                path: '/study',
                builder: (_, __) =>
                    const Scaffold(body: Center(child: Text('Study'))),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, __) =>
                    const Scaffold(body: Center(child: Text('Settings'))),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('shows 4 tabs including Study for the Urdu (study-mode) series',
      (tester) async {
    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    // "Lectures" appears twice: the page body and the nav destination label.
    expect(find.text('Lectures'), findsNWidgets(2));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('shows 4 tabs with Book instead of Study for the Arabic series',
      (tester) async {
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.text('Lectures'), findsNWidgets(2));
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Study'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('tapping Settings navigates correctly in the 4-tab layout',
      (tester) async {
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsNWidgets(2)); // tab label + page body
  });

  group('ShellScreen — mini player', () {
    testWidgets(
        'shows the Arabic lecture title for the Arabic series, with l10n nav unchanged',
        (tester) async {
      final progress = ProgressProvider()..load();
      final downloads = DownloadsProvider();
      final connectivity = ConnectivityProvider.testOffline();
      final player = PlayerNotifier(
        TawheedAudioHandler(),
        progress,
        downloads,
        connectivity,
      );
      addTearDown(player.dispose);

      final lec = _arabicLec();
      await player.loadAndPlay(lec, [lec]);

      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(
        series: series,
        catalog: _arabicCatalog(),
        player: player,
        progress: progress,
        downloads: downloads,
        connectivity: connectivity,
      ));
      await tester.pumpAndSettle();

      expect(find.text('الدرس 2'), findsOneWidget);
      expect(find.text('Dars 02'), findsNothing);

      // Bottom nav stays in English — navigation Arabic-ization is deferred.
      expect(find.text('Lectures'), findsNWidgets(2));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
