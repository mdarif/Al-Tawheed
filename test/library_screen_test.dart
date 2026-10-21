import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/app.dart' show createAppRouter;
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/screens/library_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/section_tab_header.dart';

import 'support/fake_audio_playback.dart';

Lecture _lecture(String id, int number) => Lecture(
      id: id,
      number: number,
      chapterId: 'chapter',
      title: {'en': 'Lecture $number'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1024 * 1024,
    );

Catalog _catalog(List<Lecture> lectures) => Catalog(
      version: 1,
      book: const Book(
        id: 'book',
        title: {'en': 'Book'},
        speaker: {'en': 'Speaker'},
        totalDurationSeconds: 0,
        lectureCount: 0,
        coverImageUrl: '',
        language: 'Urdu',
      ),
      chapters: const [],
      lectures: lectures,
      dailyBenefits: const [],
    );

class _RecordingDownloads extends DownloadsProvider {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAll() async {
    deleteAllCalls++;
  }
}

/// A shell around [LibraryScreen] with stub sibling branches, parsing `?tab=`
/// exactly like the production `/library` route does.
GoRouter _substituteRouter(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => ShellScreen(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/lectures',
                  builder: (_, __) => const Scaffold(body: Text('Lectures')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/read',
                  builder: (_, __) => const Scaffold(body: Text('Read')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (_, state) => LibraryScreen(
                    initialTab: LibraryTab.fromQuery(
                      state.uri.queryParameters['tab'],
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (_, __) => const Scaffold(body: Text('Settings')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/player',
          builder: (_, __) => const Scaffold(body: Text('Player')),
        ),
      ],
    );

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Widget _library({
  required bool downloadsEnabled,
  Catalog? catalog,
  ProgressProvider? progress,
  DownloadsProvider? downloads,
  PlayerNotifier? player,
  bool useProductionRouter = false,
  String initialLocation = '/library',
  GoRouter? router,
  bool offline = false,
  Locale? locale,
  double textScale = 1.0,
}) {
  final flags = FeatureFlagsProvider()
    ..setFeaturesJsonForTest({'downloads': downloadsEnabled});
  final activeProgress = progress ?? (ProgressProvider()..load());
  final activeDownloads = downloads ?? DownloadsProvider();
  final catalogProvider = CatalogProvider();
  if (catalog != null) catalogProvider.setCatalogForTest(catalog);
  final series = SeriesProvider()..load(false);
  final connectivity = offline
      ? ConnectivityProvider.testOffline()
      : ConnectivityProvider.testOnline();
  final activePlayer = player ??
      PlayerNotifier(
        FakeAudioPlayback(),
        activeProgress,
        activeDownloads,
        connectivity,
      );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: flags),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider.value(value: activeDownloads),
      ChangeNotifierProvider.value(value: activeProgress),
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
      ChangeNotifierProvider.value(value: activePlayer),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      routerConfig: router ??
          (useProductionRouter
              ? createAppRouter(initialLocation: initialLocation)
              : _substituteRouter(initialLocation)),
    ),
  );
}

Finder _tabText(Key tabKey, String text) =>
    find.descendant(of: find.byKey(tabKey), matching: find.text(text));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('header is a plain title: no hero badge, stats chip or toggles',
      (tester) async {
    await tester.pumpWidget(_library(downloadsEnabled: true));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.libraryHeader), findsOneWidget);
    expect(find.byType(SectionTabHeader), findsOneWidget);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.byIcon(Icons.collections_bookmark_rounded), findsNothing);
    // The old "N saved · N downloaded" stats chip.
    expect(find.textContaining('saved ·'), findsNothing);
    expect(find.textContaining('downloaded'), findsNothing);
    // The nav destination plus the header title.
    expect(find.text('Library'), findsNWidgets(2));
  });

  testWidgets('tabs show the bookmark and download counts', (tester) async {
    final progress = ProgressProvider()..load();
    await progress.toggleBookmark(_lecture('a', 1));
    await progress.toggleBookmark(_lecture('b', 2));
    final downloads = DownloadsProvider()..seedDownloadedForTest('a');
    await tester.pumpWidget(
      _library(
        downloadsEnabled: true,
        progress: progress,
        downloads: downloads,
        catalog: _catalog([_lecture('a', 1), _lecture('b', 2)]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _tabText(WidgetKeys.libraryTabBookmarks, 'Bookmarks'),
      findsOneWidget,
    );
    expect(_tabText(WidgetKeys.libraryTabBookmarks, '2'), findsOneWidget);
    expect(
      _tabText(WidgetKeys.libraryTabDownloads, 'Downloads'),
      findsOneWidget,
    );
    expect(_tabText(WidgetKeys.libraryTabDownloads, '1'), findsOneWidget);
  });

  testWidgets('tab counts update live', (tester) async {
    final progress = ProgressProvider()..load();
    await tester.pumpWidget(
      _library(downloadsEnabled: true, progress: progress),
    );
    await tester.pumpAndSettle();
    expect(_tabText(WidgetKeys.libraryTabBookmarks, '0'), findsOneWidget);

    await progress.toggleBookmark(_lecture('a', 1));
    await tester.pumpAndSettle();
    expect(_tabText(WidgetKeys.libraryTabBookmarks, '1'), findsOneWidget);
  });

  testWidgets('with downloads off there is no tab bar, just Bookmarks',
      (tester) async {
    await tester.pumpWidget(_library(downloadsEnabled: false));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(WidgetKeys.libraryTabDownloads), findsNothing);
    expect(find.text('Downloads'), findsNothing);
    expect(find.text('Library'), findsNWidgets(2));
    expect(find.text('No bookmarks yet'), findsOneWidget);
    expect(find.byKey(WidgetKeys.libraryRemoveAllDownloads), findsNothing);
  });

  testWidgets('mounts Library through the production route graph',
      (tester) async {
    await tester.pumpWidget(
      _library(downloadsEnabled: true, useProductionRouter: true),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Bookmarks'), findsWidgets);
    expect(find.text('Downloads'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Bookmarks tab explains how to add a bookmark',
      (tester) async {
    await tester.pumpWidget(_library(downloadsEnabled: true));
    await tester.pumpAndSettle();

    expect(find.text('No bookmarks yet'), findsOneWidget);
    expect(
      find.text(
        'Tap the bookmark icon on a lecture or in the player to keep it here.',
      ),
      findsOneWidget,
    );
    expect(find.text('No downloads yet'), findsNothing);
  });

  testWidgets('empty Downloads tab explains how to download', (tester) async {
    await tester.pumpWidget(_library(downloadsEnabled: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
    await tester.pumpAndSettle();

    expect(find.text('No downloads yet'), findsOneWidget);
    expect(
      find.text('Tap the download icon on any lecture to listen offline'),
      findsOneWidget,
    );
    expect(find.text('No bookmarks yet'), findsNothing);
    // Nothing to remove, so no destructive action either.
    expect(find.byKey(WidgetKeys.libraryRemoveAllDownloads), findsNothing);
  });

  testWidgets('preserves the selected Downloads tab across shell tab switches',
      (tester) async {
    await tester.pumpWidget(_library(downloadsEnabled: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
    await tester.pumpAndSettle();
    expect(find.text('No downloads yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsNothing);
  });

  testWidgets('Bookmarks renders a bookmarked lecture and opens Player',
      (tester) async {
    final progress = ProgressProvider()..load();
    final downloads = DownloadsProvider();
    final player = PlayerNotifier(
      FakeAudioPlayback(),
      progress,
      downloads,
      ConnectivityProvider.testOnline(),
    );
    addTearDown(player.dispose);
    await progress.toggleBookmark(_lecture('saved', 1));
    await tester.pumpWidget(
      _library(
        downloadsEnabled: true,
        progress: progress,
        downloads: downloads,
        player: player,
        catalog: _catalog([_lecture('saved', 1)]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lecture 1'), findsOneWidget);
    await tester.tap(find.text('Lecture 1'));
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);
    await player.stop();
  });

  testWidgets('Downloads renders a downloaded lecture', (tester) async {
    final downloads = DownloadsProvider()..seedDownloadedForTest('downloaded');
    await tester.pumpWidget(
      _library(
        downloadsEnabled: true,
        downloads: downloads,
        catalog: _catalog([_lecture('downloaded', 2)]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
    await tester.pumpAndSettle();
    expect(find.text('Lecture 2'), findsOneWidget);
  });

  group('Remove all downloads', () {
    Widget host(_RecordingDownloads downloads) => _library(
          downloadsEnabled: true,
          downloads: downloads,
          catalog: _catalog([_lecture('downloaded', 2)]),
        );

    testWidgets('lives in the Downloads tab only', (tester) async {
      final downloads = _RecordingDownloads()
        ..seedDownloadedForTest('downloaded');
      await tester.pumpWidget(host(downloads));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.libraryRemoveAllDownloads), findsNothing);

      await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.libraryRemoveAllDownloads), findsOneWidget);
      expect(find.text('Clear all downloads'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(WidgetKeys.libraryRemoveAllDownloads)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('asks for confirmation and cancelling keeps everything',
        (tester) async {
      final downloads = _RecordingDownloads()
        ..seedDownloadedForTest('downloaded');
      await tester.pumpWidget(host(downloads));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.libraryRemoveAllDownloads));
      await tester.pumpAndSettle();
      expect(find.text('Clear all downloads?'), findsOneWidget);
      expect(
        find.textContaining('will be deleted from this device'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all downloads?'), findsNothing);
      expect(downloads.deleteAllCalls, 0);
      expect(find.text('Lecture 2'), findsOneWidget);
    });

    testWidgets('confirming deletes every download', (tester) async {
      final downloads = _RecordingDownloads()
        ..seedDownloadedForTest('downloaded');
      await tester.pumpWidget(host(downloads));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.libraryRemoveAllDownloads));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();

      expect(downloads.deleteAllCalls, 1);
      expect(find.text('Clear all downloads?'), findsNothing);
    });
  });

  group('/library?tab= selects the tab (production router)', () {
    Future<void> openAt(
      WidgetTester tester,
      String location, {
      bool downloadsEnabled = true,
    }) async {
      await tester.pumpWidget(
        _library(
          downloadsEnabled: downloadsEnabled,
          useProductionRouter: true,
          initialLocation: location,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tab=downloads opens Downloads', (tester) async {
      await openAt(tester, '/library?tab=downloads');
      expect(find.text('No downloads yet'), findsOneWidget);
      expect(find.text('No bookmarks yet'), findsNothing);
    });

    testWidgets('tab=bookmarks opens Bookmarks', (tester) async {
      await openAt(tester, '/library?tab=bookmarks');
      expect(find.text('No bookmarks yet'), findsOneWidget);
    });

    testWidgets('no or unknown tab opens Bookmarks', (tester) async {
      await openAt(tester, '/library?tab=nonsense');
      expect(find.text('No bookmarks yet'), findsOneWidget);
    });

    testWidgets('tab=downloads falls back to Bookmarks when downloads are off',
        (tester) async {
      await openAt(tester, '/library?tab=downloads', downloadsEnabled: false);
      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });
  });

  group('tab selection follows the URL', () {
    testWidgets('go to ?tab=downloads while Library is already built',
        (tester) async {
      final router = _substituteRouter('/library');
      await tester.pumpWidget(
        _library(downloadsEnabled: true, router: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('No bookmarks yet'), findsOneWidget);

      router.go('/library?tab=downloads');
      await tester.pumpAndSettle();
      expect(find.text('No downloads yet'), findsOneWidget);
    });

    testWidgets('manual tab changes are mirrored into the location',
        (tester) async {
      final router = _substituteRouter('/library');
      await tester.pumpWidget(
        _library(downloadsEnabled: true, router: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
      await tester.pumpAndSettle();
      expect(_location(router), '/library?tab=downloads');

      await tester.tap(find.byKey(WidgetKeys.libraryTabBookmarks));
      await tester.pumpAndSettle();
      expect(_location(router), '/library?tab=bookmarks');
    });

    testWidgets(
        'a repeated link to ?tab=downloads still lands on Downloads after the '
        'user switched away', (tester) async {
      final router = _substituteRouter('/library?tab=downloads');
      await tester.pumpWidget(
        _library(downloadsEnabled: true, router: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('No downloads yet'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.libraryTabBookmarks));
      await tester.pumpAndSettle();
      expect(find.text('No bookmarks yet'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      router.go('/library?tab=downloads');
      await tester.pumpAndSettle();
      expect(find.text('No downloads yet'), findsOneWidget);
    });
  });

  group('offline banner', () {
    testWidgets('lands on Library > Downloads, every time', (tester) async {
      await tester.pumpWidget(
        _library(
          downloadsEnabled: true,
          useProductionRouter: true,
          offline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No bookmarks yet'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.offlineStatusBanner));
      await tester.pumpAndSettle();
      expect(find.text('No downloads yet'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.libraryTabBookmarks));
      await tester.pumpAndSettle();
      expect(find.text('No bookmarks yet'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.offlineStatusBanner));
      await tester.pumpAndSettle();
      expect(find.text('No downloads yet'), findsOneWidget);
    });
  });

  group('standalone (legacy route adapters)', () {
    testWidgets('the shell version has no back button', (tester) async {
      await tester.pumpWidget(_library(downloadsEnabled: true));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('initialTab preselects the tab and Back pops', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/offline-library'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: '/offline-library',
            builder: (_, __) => const LibraryScreen(
              initialTab: LibraryTab.downloads,
              standalone: true,
            ),
          ),
        ],
      );
      await tester.pumpWidget(_library(downloadsEnabled: true, router: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('No downloads yet'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      // Standalone routes have no bottom navigation, and don't rewrite the URL.
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/offline-library',
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });

  for (final (name, locale, bookmarksLabel, downloadsLabel) in [
    ('Arabic', const Locale('ar'), 'الإشارات المرجعية', 'التنزيلات'),
    ('Urdu', const Locale('ur'), 'بک مارکس', 'ڈاؤن لوڈز'),
  ]) {
    testWidgets('$name chrome at 2.0 text scale renders without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final progress = ProgressProvider()..load();
      await progress.toggleBookmark(_lecture('a', 1));
      final downloads = DownloadsProvider()..seedDownloadedForTest('a');
      await tester.pumpWidget(
        _library(
          downloadsEnabled: true,
          progress: progress,
          downloads: downloads,
          catalog: _catalog([_lecture('a', 1)]),
          locale: locale,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(bookmarksLabel), findsOneWidget);
      expect(find.text(downloadsLabel), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(WidgetKeys.libraryTabDownloads));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.libraryRemoveAllDownloads), findsOneWidget);
      expect(
        tester.getSize(find.byKey(WidgetKeys.libraryRemoveAllDownloads)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
