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
import 'package:myapp/theme/app_theme.dart';

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

Widget _library({
  required bool downloadsEnabled,
  Catalog? catalog,
  ProgressProvider? progress,
  DownloadsProvider? downloads,
  PlayerNotifier? player,
  bool useProductionRouter = false,
}) {
  final flags = FeatureFlagsProvider()
    ..setFeaturesJsonForTest({'downloads': downloadsEnabled});
  final activeProgress = progress ?? (ProgressProvider()..load());
  final activeDownloads = downloads ?? DownloadsProvider();
  final catalogProvider = CatalogProvider();
  if (catalog != null) catalogProvider.setCatalogForTest(catalog);
  final series = SeriesProvider()..load(false);
  final activePlayer = player ??
      PlayerNotifier(
        FakeAudioPlayback(),
        activeProgress,
        activeDownloads,
        ConnectivityProvider.testOnline(),
      );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: flags),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider.value(value: activeDownloads),
      ChangeNotifierProvider.value(value: activeProgress),
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
      ChangeNotifierProvider.value(value: activePlayer),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: useProductionRouter
          ? createAppRouter(initialLocation: '/library')
          : GoRouter(
              initialLocation: '/library',
              routes: [
                StatefulShellRoute.indexedStack(
                  builder: (_, __, shell) =>
                      ShellScreen(navigationShell: shell),
                  branches: [
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/lectures',
                          builder: (_, __) =>
                              const Scaffold(body: Text('Lectures')),
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/read',
                          builder: (_, __) =>
                              const Scaffold(body: Text('Read')),
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/library',
                          builder: (_, __) => const LibraryScreen(),
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/settings',
                          builder: (_, __) =>
                              const Scaffold(body: Text('Settings')),
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

  testWidgets('keeps Saved reachable and hides the toggle when disabled',
      (tester) async {
    await tester.pumpWidget(_library(downloadsEnabled: false));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsNWidgets(2));
    // No Bookmarks/Downloads toggle at all — a single option needs no chip.
    expect(find.text('Bookmarks'), findsNothing);
    expect(find.text('Downloads'), findsNothing);
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

  testWidgets(
      'preserves the selected Downloads segment across shell tab switches',
      (tester) async {
    await tester.pumpWidget(_library(downloadsEnabled: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('No downloads yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('No downloads yet'), findsOneWidget);
  });

  testWidgets('Saved renders a bookmarked lecture and opens Player',
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
    await progress.toggleBookmark('saved');
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

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Lecture 2'), findsOneWidget);
  });
}
