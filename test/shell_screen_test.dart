import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/app.dart' show createAppRouter;
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/navigation/series_navigation_policy.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/screens/library_screen.dart';
import 'package:myapp/screens/offline_library_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';

import 'support/fake_audio_playback.dart';

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

const _audioOnlySeries = SeriesConfig(
  id: 'audio-only',
  catalogUrl: 'https://example.com/audio-only/catalog.json',
  storagePrefix: 'audio_',
  hasStudyMode: false,
  hasBook: false,
  language: 'ur',
  displayName: {'en': 'Audio only'},
  speakerName: {'en': 'Speaker'},
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
  bool downloadsEnabled = false,
  TextScaler? textScaler,
  TextDirection? textDirection,
  // UI/chrome locale. Chrome now follows the UI language independently of the
  // content edition, so Arabic-chrome expectations require an Arabic UI locale.
  Locale? locale,
  bool useProductionRouter = false,
}) {
  final catalogProvider = CatalogProvider();
  if (catalog != null) {
    catalogProvider.setCatalogForTest(catalog);
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(
        create: (_) => FeatureFlagsProvider()
          ..setFeaturesJsonForTest({'downloads': downloadsEnabled}),
      ),
      connectivity != null
          ? ChangeNotifierProvider.value(value: connectivity)
          : ChangeNotifierProvider(
              create: (_) => ConnectivityProvider.testOnline(),
            ),
      progress != null
          ? ChangeNotifierProvider.value(value: progress)
          : ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      downloads != null
          ? ChangeNotifierProvider.value(value: downloads)
          : ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider(create: (_) => AnnouncementsProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
      player != null
          ? ChangeNotifierProvider.value(value: player)
          : ChangeNotifierProvider(
              create: (ctx) => PlayerNotifier(
                FakeAudioPlayback(),
                ctx.read<ProgressProvider>(),
                ctx.read<DownloadsProvider>(),
                ctx.read<ConnectivityProvider>(),
              ),
            ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return Directionality(
          textDirection: textDirection ??
              ((locale?.languageCode == 'ar' || locale?.languageCode == 'ur')
                  ? TextDirection.rtl
                  : TextDirection.ltr),
          child: MediaQuery(
            data: media.copyWith(textScaler: textScaler ?? media.textScaler),
            child: child!,
          ),
        );
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: useProductionRouter
          ? createAppRouter(initialLocation: initialLocation)
          : GoRouter(
              initialLocation: initialLocation,
              routes: [
                StatefulShellRoute.indexedStack(
                  builder: (context, state, navigationShell) =>
                      ShellScreen(navigationShell: navigationShell),
                  branches: [
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/lectures',
                          builder: (_, __) => Scaffold(
                            body: ListView.builder(
                              key: const PageStorageKey('lecture-list'),
                              itemCount: 60,
                              itemBuilder: (context, index) => ListTile(
                                title: Text('Lecture $index'),
                                onTap: index == 0
                                    ? () => context.push('/lectures/detail')
                                    : null,
                              ),
                            ),
                          ),
                          routes: [
                            GoRoute(
                              path: 'detail',
                              builder: (_, __) => const Scaffold(
                                body: Center(
                                  child: Text('Nested lecture detail'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/read',
                          builder: (_, __) => const Scaffold(
                            body: Center(child: Text('Read')),
                          ),
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/library',
                          builder: (_, __) => const LibraryScreen(),
                          routes: [
                            GoRoute(
                              path: 'detail',
                              builder: (_, __) => const Scaffold(
                                body: Center(
                                  child: Text('Nested library detail'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/settings',
                          builder: (_, __) => const Scaffold(
                            body: Center(child: Text('Settings')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: '/bookmarks',
                  builder: (_, __) => const BookmarksScreen(),
                ),
                GoRoute(
                  path: '/offline-library',
                  builder: (_, __) => const OfflineLibraryScreen(),
                ),
                GoRoute(
                  path: '/player',
                  builder: (_, __) => const Scaffold(
                    body: Text(
                      'Player route',
                      key: ValueKey('player-route-probe'),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

AnimatedSlide _shellChromeSlide(WidgetTester tester) {
  return tester.widget<AnimatedSlide>(
    find
        .ancestor(
          of: find.byType(NavigationBar),
          matching: find.byType(AnimatedSlide),
        )
        .first,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets(
      'shows 4 tabs (Lectures, Read, Library, Settings) for the Urdu series', (
    tester,
  ) async {
    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    // The Urdu series has both Book and Study, merged into one Read tab, plus
    // Settings last. Home was retired; Bookmarks and About live behind the ⋯
    // overflow menu.
    expect(find.text('Lecture 0'), findsOneWidget);
    expect(find.text('Lectures'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget); // nav destination label
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byKey(WidgetKeys.shellLecturesTab), findsOneWidget);
    expect(find.byKey(WidgetKeys.shellReadTab), findsOneWidget);
    expect(find.byKey(WidgetKeys.shellLibraryTab), findsOneWidget);
    expect(find.byKey(WidgetKeys.shellSettingsTab), findsOneWidget);
  });

  testWidgets('Settings is the LAST tab', (tester) async {
    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    final expected = SeriesNavigationPolicy.tabsFor(series.currentSeries)
        .map(
          (tab) => switch (tab) {
            SeriesNavigationTab.lectures => 'Lectures',
            SeriesNavigationTab.read => 'Read',
            SeriesNavigationTab.library => 'Library',
            SeriesNavigationTab.settings => 'Settings',
          },
        )
        .toList();
    expect(labels, expected);
    expect(labels, ['Lectures', 'Read', 'Library', 'Settings']);
  });

  testWidgets(
      'shows 4 tabs (Lectures, Read, Library, Settings) for the Arabic series',
      (
    tester,
  ) async {
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    // Arabic UI locale → Arabic navigation labels.
    await tester.pumpWidget(_wrap(series: series, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('Lectures'), findsNothing);
    // Lectures + Read + Library + Settings — Settings is series-independent.
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    final expected = SeriesNavigationPolicy.tabsFor(series.currentSeries)
        .map(
          (tab) => switch (tab) {
            SeriesNavigationTab.lectures => 'الدروس',
            SeriesNavigationTab.read => 'القراءة',
            SeriesNavigationTab.library => 'المكتبة',
            SeriesNavigationTab.settings => 'الإعدادات',
          },
        )
        .toList();
    expect(labels, expected);
    expect(labels, ['الدروس', 'القراءة', 'المكتبة', 'الإعدادات']);

    await tester.tap(find.text('المكتبة'));
    await tester.pumpAndSettle();
    expect(find.text('المكتبة'), findsNWidgets(2));
  });

  testWidgets('shows Arabic nav labels for the Arabic series under Arabic UI', (
    tester,
  ) async {
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الدروس'), findsOneWidget);
    expect(find.text('القراءة'), findsOneWidget);
    expect(find.text('المكتبة'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget); // Settings tab (last)
    // Home retired; only Bookmarks/About live behind the ⋯ overflow menu.
    expect(find.text('الرئيسية'), findsNothing);
  });

  testWidgets('hides and restores bottom navigation chrome on request', (
    tester,
  ) async {
    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_shellChromeSlide(tester).offset, Offset.zero);

    tester.element(find.byType(ShellScreen)).read<ShellChromeProvider>().hide();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_shellChromeSlide(tester).offset, const Offset(0, 1));

    tester.element(find.byType(ShellScreen)).read<ShellChromeProvider>().show();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_shellChromeSlide(tester).offset, Offset.zero);
  });

  testWidgets('mini player survives repeated switches across every Urdu branch',
      (tester) async {
    final progress = ProgressProvider()..load();
    final downloads = DownloadsProvider();
    final connectivity = ConnectivityProvider.testOffline();
    final player =
        PlayerNotifier(FakeAudioPlayback(), progress, downloads, connectivity);
    addTearDown(player.dispose);
    final lecture = _arabicLec();
    await player.loadAndPlay(lecture, [lecture]);

    await tester.pumpWidget(
      _wrap(
        series: SeriesProvider()..load(false),
        player: player,
        progress: progress,
        downloads: downloads,
        connectivity: connectivity,
      ),
    );
    await tester.pumpAndSettle();

    for (final destination in [
      WidgetKeys.shellReadTab,
      WidgetKeys.shellLibraryTab,
      WidgetKeys.shellSettingsTab,
      WidgetKeys.shellLecturesTab,
      WidgetKeys.shellLibraryTab,
    ]) {
      await tester.tap(find.byKey(destination));
      await tester.pumpAndSettle();
      expect(find.text('Dars 02'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });

  testWidgets('Back from a non-Lectures branch returns to Lectures',
      (tester) async {
    await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsNWidgets(2));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Lecture 0'), findsOneWidget);
  });

  testWidgets('Back pops a nested Library route before returning to Lectures',
      (tester) async {
    await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(ShellScreen)));
    router.go('/library');
    await tester.pumpAndSettle();
    unawaited(router.push('/library/detail'));
    await tester.pumpAndSettle();
    expect(find.text('Nested library detail'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Nested library detail'), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Lecture 0'), findsOneWidget);
  });

  testWidgets('lecture list scroll position survives switching away and back',
      (tester) async {
    await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const PageStorageKey('lecture-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final before =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(before, greaterThan(0));

    await tester.tap(find.byKey(WidgetKeys.shellLibraryTab));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.shellLecturesTab));
    await tester.pumpAndSettle();
    final after =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(after, before);
  });

  testWidgets('Back pops branch detail, returns to Lectures, then permits exit',
      (tester) async {
    await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lecture 0'));
    await tester.pumpAndSettle();
    expect(find.text('Nested lecture detail'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Lecture 0'), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.shellLibraryTab));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Lecture 0'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets(
      'all capability layouts render localized destinations at narrow 2x scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final layouts = [
      (
        series: SeriesProvider()..load(false),
        locale: const Locale('ur'),
        localizedLectures: 'دروس',
        destinations: [
          WidgetKeys.shellLecturesTab,
          WidgetKeys.shellReadTab,
          WidgetKeys.shellLibraryTab,
          WidgetKeys.shellSettingsTab,
        ],
      ),
      (
        series: SeriesProvider()
          ..load(false)
          ..setCurrentSeriesForTest(_arabicSeries),
        locale: const Locale('ar'),
        localizedLectures: 'الدروس',
        destinations: [
          WidgetKeys.shellLecturesTab,
          WidgetKeys.shellReadTab,
          WidgetKeys.shellLibraryTab,
          WidgetKeys.shellSettingsTab,
        ],
      ),
      (
        series: SeriesProvider()
          ..load(false)
          ..setCurrentSeriesForTest(_audioOnlySeries),
        locale: const Locale('ur'),
        localizedLectures: 'دروس',
        destinations: [
          WidgetKeys.shellLecturesTab,
          WidgetKeys.shellLibraryTab,
          WidgetKeys.shellSettingsTab,
        ],
      ),
    ];

    for (final layout in layouts) {
      await tester.pumpWidget(
        _wrap(
          series: layout.series,
          locale: layout.locale,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(layout.localizedLectures), findsOneWidget);
      expect(
        find.byType(NavigationDestination),
        findsNWidgets(layout.destinations.length),
      );

      for (final key in layout.destinations) {
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
      'Arabic and Urdu Library segments fit at narrow 2x scale with downloads',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final layout in [
      (
        series: SeriesProvider()
          ..load(false)
          ..setCurrentSeriesForTest(_arabicSeries),
        locale: const Locale('ar'),
        saved: 'المحفوظات',
        downloads: 'التنزيلات',
      ),
      (
        series: SeriesProvider()..load(false),
        locale: const Locale('ur'),
        saved: 'محفوظ',
        downloads: 'ڈاؤن لوڈز',
      ),
    ]) {
      await tester.pumpWidget(
        _wrap(
          series: layout.series,
          initialLocation: '/library',
          locale: layout.locale,
          downloadsEnabled: true,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(layout.saved), findsOneWidget);
      expect(find.text(layout.downloads), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'production router wires the Library destination and redirects unavailable tabs',
      (tester) async {
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_audioOnlySeries);
    await tester.pumpWidget(
      _wrap(
        series: series,
        initialLocation: '/library',
        useProductionRouter: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byKey(WidgetKeys.shellLibraryTab), findsOneWidget);
    // Audio-only has neither book nor study, so /read is unavailable.
    GoRouter.of(tester.element(find.byType(ShellScreen))).go('/read');
    await tester.pumpAndSettle();
    expect(
      GoRouter.of(tester.element(find.byType(ShellScreen)))
          .routeInformationProvider
          .value
          .uri
          .path,
      '/lectures',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy Library routes from Player preserve Player and pop back',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        series: SeriesProvider()..load(false),
        downloadsEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(ShellScreen)));

    for (final route in ['/bookmarks', '/offline-library']) {
      unawaited(router.push('/player'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-route-probe')), findsOneWidget);
      unawaited(router.push(route));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-route-probe'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        route == '/bookmarks'
            ? find.byType(BookmarksScreen)
            : find.byType(OfflineLibraryScreen),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-route-probe')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'opening a lecture from Saved or Downloads lands on Player via push, '
      'and Back returns to the originating list (B1b)', (tester) async {
    // bookmarks_screen.dart and offline_library_screen.dart both push
    // '/player' from their lecture rows, the same mechanism as
    // lecture_list_screen.dart and ContinueListeningBanner — this proves the
    // resulting back-stack, not just that the same string literal is used.
    await tester.pumpWidget(
      _wrap(
        series: SeriesProvider()..load(false),
        downloadsEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(ShellScreen)));

    for (final route in ['/bookmarks', '/offline-library']) {
      unawaited(router.push(route));
      await tester.pumpAndSettle();
      expect(
        route == '/bookmarks'
            ? find.byType(BookmarksScreen)
            : find.byType(OfflineLibraryScreen),
        findsOneWidget,
      );

      unawaited(router.push('/player'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-route-probe')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        route == '/bookmarks'
            ? find.byType(BookmarksScreen)
            : find.byType(OfflineLibraryScreen),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('player-route-probe')), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  group('ShellScreen — mini player', () {
    testWidgets(
      'shows the Arabic lecture title for the Arabic series, with l10n nav unchanged',
      (tester) async {
        final progress = ProgressProvider()..load();
        final downloads = DownloadsProvider();
        final connectivity = ConnectivityProvider.testOffline();
        final player = PlayerNotifier(
          FakeAudioPlayback(),
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

        await tester.pumpWidget(
          _wrap(
            series: series,
            catalog: _arabicCatalog(),
            player: player,
            progress: progress,
            downloads: downloads,
            connectivity: connectivity,
            locale: const Locale('ar'),
          ),
        );
        await tester.pumpAndSettle();

        // Content (mini-player track title) is Arabic per edition, regardless of UI.
        expect(find.text('الدرس 2'), findsOneWidget);
        expect(find.text('Dars 02'), findsNothing);

        // Bottom nav is Arabic because the UI locale is Arabic.
        expect(find.text('Lectures'), findsNothing);
        expect(find.text('الدروس'), findsOneWidget);
        expect(find.text('الإعدادات'), findsOneWidget); // Settings tab (last)
      },
    );
  });
}
