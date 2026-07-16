import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

/// `bookmarks_screen.dart` was never constructed in any test, despite being a
/// live route reachable from the overflow menu. Covers the three states that
/// matter: empty, the bookmarked-only filter, and tap-through to the player.

Lecture _lec(String id, int num) => Lecture(
      id: id,
      number: num,
      chapterId: 'ch-1',
      title: {'en': 'Lecture $num'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1048576,
    );

final _lectures = [_lec('l1', 1), _lec('l2', 2), _lec('l3', 3)];

Catalog _catalog() => Catalog(
      version: 1,
      book: const Book(
        id: 'b',
        title: {'en': 'Kitab at-Tawheed'},
        speaker: {'en': 'Speaker'},
        totalDurationSeconds: 1800,
        lectureCount: 3,
        coverImageUrl: '',
        language: 'Urdu',
      ),
      chapters: const [],
      lectures: _lectures,
      dailyBenefits: const [],
    );

Future<ProgressProvider> _pump(
  WidgetTester tester, {
  required List<String> bookmarked,
  bool loaded = true,
  bool online = false,
}) async {
  final progress = ProgressProvider()..load();
  for (final id in bookmarked) {
    await progress.toggleBookmark(id);
  }
  final catalog = CatalogProvider();
  if (loaded) catalog.setCatalogForTest(_catalog());

  final downloads = DownloadsProvider();
  final connectivity = online
      ? ConnectivityProvider.testOnline()
      : ConnectivityProvider.testOffline();
  final series = SeriesProvider()..load(false);
  final player =
      PlayerNotifier(TawheedAudioHandler(), progress, downloads, connectivity);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: progress),
      ChangeNotifierProvider.value(value: catalog),
      ChangeNotifierProvider.value(value: player),
      ChangeNotifierProvider.value(value: downloads),
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/bookmarks',
        routes: [
          GoRoute(
            path: '/bookmarks',
            builder: (_, __) => const BookmarksScreen(),
          ),
          GoRoute(
            path: '/player',
            builder: (_, __) => const Scaffold(body: Text('PLAYER')),
          ),
        ],
      ),
    ),
  ),);
  await tester.pumpAndSettle();
  return progress;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('no bookmarks: empty state, unnumbered title', (tester) async {
    await _pump(tester, bookmarked: []);

    expect(find.text('No bookmarked lectures yet'), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget); // no count
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('shows only bookmarked lectures, with the count in the title',
      (tester) async {
    await _pump(tester, bookmarked: ['l1', 'l3']);

    // l1 and l3 are bookmarked; l2 is not.
    expect(find.text('Lecture 1'), findsOneWidget);
    expect(find.text('Lecture 3'), findsOneWidget);
    expect(find.text('Lecture 2'), findsNothing);
    expect(find.text('Bookmarks (2)'), findsOneWidget);
    expect(find.text('No bookmarked lectures yet'), findsNothing);
  });

  testWidgets('un-bookmarking removes a lecture from the list live',
      (tester) async {
    final progress = await _pump(tester, bookmarked: ['l1', 'l2']);
    expect(find.text('Bookmarks (2)'), findsOneWidget);

    await progress.toggleBookmark('l1');
    await tester.pumpAndSettle();

    expect(find.text('Lecture 1'), findsNothing);
    expect(find.text('Bookmarks (1)'), findsOneWidget);
  });

  testWidgets('tapping a bookmarked lecture opens the player', (tester) async {
    // Online so the tile isn't offline-blocked (which would show a snackbar
    // instead of navigating).
    await _pump(tester, bookmarked: ['l1'], online: true);

    await tester.tap(find.text('Lecture 1'));
    await tester.pumpAndSettle();

    expect(find.text('PLAYER'), findsOneWidget);
  });
}
