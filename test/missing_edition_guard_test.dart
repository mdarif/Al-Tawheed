import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/app.dart' show createAppRouter;
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/navigation/missing_edition_refresh.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/choose_series_screen.dart';
import 'package:myapp/screens/edition_missing_screen.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/library_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';

import 'support/fake_audio_playback.dart';

/// BLK-06 through the REAL production router (`createAppRouter`): a saved
/// edition the manifest doesn't contain must never fall through to the Urdu
/// fallback's content — not on launch, not after a failed Retry, not via system
/// Back, not via a deep link.

const _urdu = SeriesConfig.legacyUrduFallback;

const _arabic = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

const _missingPath = '/edition-missing';

/// Writes the cache entry `SeriesManifestService.fetchManifest` reads, so
/// `SeriesProvider.loadManifest()` (and so the screen's Retry) sees exactly
/// this manifest — fresh, so no network is involved.
Future<void> _serveManifest(List<SeriesConfig> series) =>
    PreferencesService.instance.saveRemoteJson(
      'series_manifest',
      jsonEncode({
        'series': [
          for (final s in series)
            {
              'id': s.id,
              'catalogUrl': s.catalogUrl,
              'storagePrefix': s.storagePrefix,
              'hasStudyMode': s.hasStudyMode,
              'hasBook': s.hasBook,
              'language': s.language,
              'displayName': s.displayName,
              'speakerName': s.speakerName,
            },
        ],
      }),
    );

Catalog _catalog() => Catalog(
      version: 1,
      book: const Book(
        id: 'arabic-book',
        title: {'en': 'Kitab at-Tawheed'},
        speaker: {'en': 'Shaikh Salih al-Fawzan'},
        totalDurationSeconds: 600,
        lectureCount: 1,
        coverImageUrl: '',
        language: 'Arabic',
      ),
      chapters: const [],
      lectures: [
        Lecture(
          id: 'l1',
          number: 1,
          chapterId: 'ch-1',
          title: const {'en': 'Dars 01'},
          audioUrl: 'https://example.com/l1.mp3',
          durationSeconds: 600,
          fileSizeBytes: 1048576,
        ),
      ],
      dailyBenefits: const [],
    );

/// A returning user whose saved edition is Arabic and who has already seen its
/// welcome — so "the edition resolves" lands on its Lectures, while the Urdu
/// fallback (welcome not seen) would show WelcomeScreen. Either is a leak.
Future<SeriesProvider> _returningArabicUser({
  required List<SeriesConfig> manifest,
  bool applyManifest = true,
}) async {
  await PreferencesService.instance.saveSelectedSeriesId(_arabic.id);
  await PreferencesService.instance.saveSeenWelcomeForSeries(_arabic.id);
  await _serveManifest(manifest);
  final series = SeriesProvider()..load(true, definitive: true);
  if (applyManifest) await series.loadManifest();
  return series;
}

Widget _app({required SeriesProvider series, required GoRouter router}) {
  final catalog = CatalogProvider()
    ..setCatalogForTest(_catalog(), seriesId: _arabic.id);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(
        create: (_) => FeatureFlagsProvider()
          ..setFeaturesJsonForTest({'downloads': false}),
      ),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider.value(value: catalog),
      ChangeNotifierProvider(create: (_) => AnnouncementsProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
      ChangeNotifierProvider(create: (_) => BookProvider()),
      ChangeNotifierProvider(create: (ctx) => ReadingProvider(series)..load()),
      ChangeNotifierProvider(
        create: (ctx) => StudyProgressProvider(
          ctx.read<ProgressProvider>(),
          ctx.read<CatalogProvider>(),
        )..load(),
      ),
      ChangeNotifierProvider(
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// The production router wired the way `MyApp` wires it: refreshed whenever
/// the saved edition goes missing or comes back.
GoRouter _router(SeriesProvider series, {String initialLocation = '/'}) {
  final refresh = MissingEditionRefresh(series);
  addTearDown(refresh.dispose);
  return createAppRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
  );
}

/// The location of the topmost page, including pages added with `push` (which
/// `routeInformationProvider.value` does not reflect).
String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

/// The recovery screen is what the user sees. Setup precondition only: it does
/// not look underneath it (see [_expectOnlyRecovery]).
void _expectRecoveryVisible(GoRouter router) {
  expect(find.byType(EditionMissingScreen), findsOneWidget);
  expect(_path(router), _missingPath);
}

/// Nothing the Urdu fallback (or any edition) would show is on screen *or kept
/// alive beneath it* (`skipOffstage: false`): the recovery screen is the only
/// page, so neither Back nor a failed Retry can reveal a substituted edition.
void _expectOnlyRecovery(GoRouter router) {
  _expectRecoveryVisible(router);
  expect(find.byType(WelcomeScreen, skipOffstage: false), findsNothing);
  expect(find.byType(ShellScreen, skipOffstage: false), findsNothing);
  expect(find.byType(LectureListScreen, skipOffstage: false), findsNothing);
  expect(find.byType(LibraryScreen, skipOffstage: false), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('(1) launch with the saved edition missing lands on recovery',
      (tester) async {
    final series = await _returningArabicUser(manifest: [_urdu]);
    expect(series.hasMissingSelectedSeries, isTrue);
    final router = _router(series);

    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();

    _expectOnlyRecovery(router);
    expect(series.selectedSeriesId, _arabic.id);
  });

  testWidgets(
      '(2) Retry while the manifest still lacks the edition stays on recovery '
      'and keeps the saved id', (tester) async {
    final series = await _returningArabicUser(manifest: [_urdu]);
    final router = _router(series);
    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();
    _expectRecoveryVisible(router);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    _expectOnlyRecovery(router);
    expect(series.hasMissingSelectedSeries, isTrue);
    expect(series.selectedSeriesId, _arabic.id);
    expect(PreferencesService.instance.selectedSeriesId, _arabic.id);

    // And again: a second failed Retry is no different from the first.
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    _expectOnlyRecovery(router);
  });

  testWidgets('(3) system Back on recovery never reveals fallback content',
      (tester) async {
    final series = await _returningArabicUser(manifest: [_urdu]);
    final router = _router(series);
    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();
    _expectRecoveryVisible(router);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    _expectOnlyRecovery(router);
    expect(series.selectedSeriesId, _arabic.id);
  });

  testWidgets(
      '(4) Retry after the manifest now lists the edition lands on that '
      "edition's Lectures", (tester) async {
    final series = await _returningArabicUser(manifest: [_urdu]);
    final router = _router(series);
    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();
    _expectRecoveryVisible(router);

    await _serveManifest([_urdu, _arabic]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(series.hasMissingSelectedSeries, isFalse);
    expect(series.currentSeries.id, _arabic.id);
    expect(find.byType(EditionMissingScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(LectureListScreen), findsOneWidget);
    expect(_path(router), '/lectures');
  });

  testWidgets(
      '(5) "Choose another edition" opens the picker; picking one clears the '
      'missing state', (tester) async {
    await PreferencesService.instance.saveSeenWelcomeForSeries(_urdu.id);
    final series = await _returningArabicUser(manifest: [_urdu]);
    final router = _router(series);
    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();
    _expectRecoveryVisible(router);

    await tester.tap(find.text('Choose another edition'));
    await tester.pumpAndSettle();
    expect(find.byType(ChooseSeriesScreen), findsOneWidget);
    expect(_path(router), '/choose-series');
    expect(series.hasMissingSelectedSeries, isTrue);

    // Back from the picker returns to recovery, not to fallback content.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectOnlyRecovery(router);

    await tester.tap(find.text('Choose another edition'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.chooseSeriesCard(_urdu.id)));
    await tester.runAsync(() async {
      while (series.selectedSeriesId != _urdu.id) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    expect(series.hasMissingSelectedSeries, isFalse);
    expect(series.selectedSeriesId, _urdu.id);
    expect(PreferencesService.instance.selectedSeriesId, _urdu.id);
    expect(find.byType(EditionMissingScreen), findsNothing);
    expect(find.byType(ChooseSeriesScreen), findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('(6) deep links and in-app jumps while missing go to recovery',
      (tester) async {
    final series = await _returningArabicUser(manifest: [_urdu]);
    final router = _router(series);
    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();
    _expectRecoveryVisible(router);

    for (final target in [
      '/library',
      '/lectures',
      '/settings',
      '/read?tab=book',
      '/about',
      '/bookmarks',
      '/',
    ]) {
      router.go(target);
      await tester.pumpAndSettle();
      expect(_path(router), _missingPath, reason: 'go($target)');
      _expectOnlyRecovery(router);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '(7) the edition going missing after launch replaces the content '
      'stack, so Back cannot reveal it', (tester) async {
    // The common case: a returning user is already on /lectures when the
    // manifest fetch completes without their edition.
    final series = await _returningArabicUser(
      manifest: [_urdu, _arabic],
      applyManifest: false,
    );
    final router = _router(series, initialLocation: '/lectures');
    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();
    expect(find.byType(LectureListScreen), findsOneWidget);

    await _serveManifest([_urdu]);
    await series.loadManifest();
    await tester.pumpAndSettle();
    _expectOnlyRecovery(router);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectOnlyRecovery(router);
  });

  testWidgets('an edition that resolves is untouched by any of this',
      (tester) async {
    final series = await _returningArabicUser(manifest: [_urdu, _arabic]);
    expect(series.hasMissingSelectedSeries, isFalse);
    final router = _router(series, initialLocation: '/lectures');

    await tester.pumpWidget(_app(series: series, router: router));
    await tester.pumpAndSettle();
    expect(find.byType(LectureListScreen), findsOneWidget);

    router.go('/library');
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(EditionMissingScreen), findsNothing);

    router.go('/');
    await tester.pumpAndSettle();
    expect(_path(router), '/lectures');
  });

  test(
      'MissingEditionRefresh fires only when missing flips, not on every '
      'SeriesProvider notification', () async {
    final series = await _returningArabicUser(
      manifest: [_urdu, _arabic],
      applyManifest: false,
    );
    final refresh = MissingEditionRefresh(series);
    addTearDown(refresh.dispose);
    var fired = 0;
    refresh.addListener(() => fired++);

    series.markWelcomeSeenForCurrentSeries(); // unrelated notification
    expect(fired, 0);

    await series.loadManifest(); // edition present: still not missing
    expect(fired, 0);

    await _serveManifest([_urdu]);
    await series.loadManifest(); // goes missing
    expect(fired, 1);

    await series.loadManifest(); // still missing
    expect(fired, 1);

    await _serveManifest([_urdu, _arabic]);
    await series.loadManifest(); // comes back
    expect(fired, 2);
  });
}
