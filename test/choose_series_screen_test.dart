import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/choose_series_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

const _urduSeries = SeriesConfig.legacyUrduFallback;

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {
    'en': 'Shaikh Salih al-Fawzan Hafizhahullah',
    'ar': 'الشيخ صالح الفوزان حفظه الله',
  },
);

// A series with no study mode and no book — tests that only the "Audio" chip
// appears when neither optional feature is present.
const _minimalSeries = SeriesConfig(
  id: 'tawheed-minimal',
  catalogUrl: 'https://example.com/tawheed-minimal/catalog.json',
  storagePrefix: 'min_',
  hasStudyMode: false,
  hasBook: false,
  language: 'en',
  displayName: {'en': 'Some Other Series'},
  speakerName: {'en': 'Speaker Name'},
);

// A series with a "Fazilat Shaikh" prefix to test the longest honorific strip.
const _fazSeriesName = SeriesConfig(
  id: 'tawheed-faz',
  catalogUrl: 'https://example.com/catalog.json',
  storagePrefix: 'faz_',
  hasStudyMode: false,
  hasBook: false,
  language: 'ur',
  displayName: {'en': 'Test Series (Urdu)'},
  speakerName: {'en': 'Fazilat Shaikh Abdullah Nasir Rahmani'},
);

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

Widget _wrap({required SeriesProvider series}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => BookProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(
        create: (ctx) => StudyProgressProvider(
          ctx.read<ProgressProvider>(),
          ctx.read<CatalogProvider>(),
        )..load(),
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
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/choose-series',
        routes: [
          GoRoute(
            path: '/',
            // Mirror the real router: after a series switch the picker routes
            // to '/', which shows the chosen series' welcome if not yet seen,
            // or redirects to lectures otherwise.
            redirect: (context, state) {
              final s = context.read<SeriesProvider>();
              if (!s.shouldShowWelcomeForCurrentSeries) return '/lectures';
              return null;
            },
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Welcome'))),
          ),
          GoRoute(
            path: '/choose-series',
            builder: (_, __) => const ChooseSeriesScreen(),
          ),
          GoRoute(
            path: '/lectures',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Lectures'))),
          ),
        ],
      ),
    ),
  );
}

/// Taps a card identified by [tapTarget], waits for the series switch to
/// complete, then pumps until settled. Returns after navigation is done.
Future<void> _tapCardAndSettle(
  WidgetTester tester,
  SeriesProvider series,
  Finder tapTarget,
  String expectedSeriesId,
) async {
  await tester.tap(tapTarget);
  await tester.pump();

  await tester.runAsync(() async {
    while (series.currentSeries.id != expectedSeriesId) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });

  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('ChooseSeriesScreen — card rendering', () {
    testWidgets('renders a card for each available series', (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Kitab at-Tawheed'), findsOneWidget);
      expect(find.text('كتاب التوحيد'), findsOneWidget);
    });

    testWidgets('both cards carry an Audio chip, no language qualifier chips',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Audio'), findsNWidgets(2));
      expect(find.text('Urdu'), findsNothing);
      expect(find.text('Arabic'), findsNothing);
    });

    testWidgets('Study Mode chip shown only for series with hasStudyMode',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // Urdu has studyMode, Arabic does not
      expect(find.text('Study Mode'), findsOneWidget);
    });

    testWidgets('Book chip shown only for series with hasBook', (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // Arabic has book, Urdu does not
      expect(find.text('Book'), findsOneWidget);
    });

    testWidgets(
        'minimal series (no studyMode, no book) shows only Audio chip',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_minimalSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Study Mode'), findsNothing);
      expect(find.text('Book'), findsNothing);
    });

    testWidgets('language thumbnail shows native script labels',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('Urdu card shows Urdu native subtitle', (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('شرح کتاب التوحید'), findsOneWidget);
    });

    testWidgets('Arabic card shows Arabic native subtitle', (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('شرح كتاب التوحيد'), findsOneWidget);
    });

    testWidgets('cards have Material elevation for tappable affordance',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // The Material widget is the parent of the InkWell in each card.
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(InkWell),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, greaterThan(0));
    });
  });

  group('ChooseSeriesScreen — speaker name shortening', () {
    testWidgets('"Shaikh" prefix is stripped from English speaker names',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // "Shaikh Abdullah Nasir Rahmani Hafizahullah" → "Abdullah ..."
      expect(find.text('Abdullah Nasir Rahmani Hafizahullah'), findsOneWidget);
      expect(find.text('Salih al-Fawzan Hafizhahullah'), findsOneWidget);

      // Full names with "Shaikh" prefix should NOT appear
      expect(find.text('Shaikh Abdullah Nasir Rahmani Hafizahullah'),
          findsNothing,);
      expect(find.text('Shaikh Salih al-Fawzan Hafizhahullah'), findsNothing);
    });

    testWidgets('"Fazilat Shaikh" prefix is stripped', (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_fazSeriesName]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Abdullah Nasir Rahmani'), findsOneWidget);
      expect(
          find.text('Fazilat Shaikh Abdullah Nasir Rahmani'), findsNothing,);
    });

    testWidgets('speaker name without known prefix is shown as-is',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_minimalSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Speaker Name'), findsOneWidget);
    });
  });

  group('ChooseSeriesScreen — selecting Urdu series', () {
    testWidgets('tapping the already-current Urdu card goes to lectures',
        (tester) async {
      await PreferencesService.instance.saveRemoteJson(
          'catalog_tawheed-ur', jsonEncode(_catalogJson('urdu-book')),);

      // Use load(true) so _currentId starts null (simulating the fresh-install
      // path where the user reaches ChooseSeriesScreen). currentSeries falls
      // back to the Urdu legacy series, so picking Urdu confirms the current
      // series — its welcome is marked seen and we land on lectures.
      final series = SeriesProvider()
        ..load(true, definitive: true)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      await _tapCardAndSettle(
        tester,
        series,
        find.text('Abdullah Nasir Rahmani Hafizahullah'),
        _urduSeries.id,
      );

      expect(series.currentSeries.id, _urduSeries.id);
      expect(series.shouldShowWelcomeForCurrentSeries, isFalse);
      expect(
          PreferencesService.instance.selectedSeriesId, _urduSeries.id,);
      expect(find.text('Lectures'), findsOneWidget);
    });
  });

  group('ChooseSeriesScreen — selecting Arabic series', () {
    testWidgets(
        'tapping a different (Arabic) card routes to its welcome screen',
        (tester) async {
      await PreferencesService.instance.saveRemoteJson(
          'catalog_tawheed-ar', jsonEncode(_catalogJson('arabic-book')),);

      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      await _tapCardAndSettle(
        tester,
        series,
        find.text('Salih al-Fawzan Hafizhahullah'),
        _arabicSeries.id,
      );

      expect(series.currentSeries.id, _arabicSeries.id);
      expect(
          PreferencesService.instance.selectedSeriesId, _arabicSeries.id,);
      // Switching to a not-yet-seen series shows that series' welcome (the
      // router stays on '/'), rather than skipping straight to lectures.
      expect(series.shouldShowWelcomeForCurrentSeries, isTrue);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Lectures'), findsNothing);
    });
  });

  group('ChooseSeriesScreen — loading state', () {
    testWidgets('tapping a card shows a spinner on the tapped card',
        (tester) async {
      await PreferencesService.instance.saveRemoteJson(
          'catalog_tawheed-ar', jsonEncode(_catalogJson('arabic-book')),);

      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // Before tap — no spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tap the Arabic card
      await tester.tap(find.text('Salih al-Fawzan Hafizhahullah'));
      await tester.pump();

      // After tap — spinner should be visible (in-card overlay)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let async work complete
      await tester.runAsync(() async {
        while (series.currentSeries.id != _arabicSeries.id) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets('cards are AbsorbPointer-blocked while switching',
        (tester) async {
      await PreferencesService.instance.saveRemoteJson(
          'catalog_tawheed-ar', jsonEncode(_catalogJson('arabic-book')),);

      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      // Before tapping, AbsorbPointer should not be absorbing
      final absorbBefore = tester.widgetList<AbsorbPointer>(
        find.byType(AbsorbPointer),
      );
      expect(absorbBefore.any((a) => a.absorbing), isFalse);

      // Tap the Arabic card to start switching
      await tester.tap(find.text('Salih al-Fawzan Hafizhahullah'));
      await tester.pump();

      // Now at least one AbsorbPointer should be absorbing
      final absorbAfter = tester.widgetList<AbsorbPointer>(
        find.byType(AbsorbPointer),
      );
      expect(absorbAfter.any((a) => a.absorbing), isTrue);

      // Clean up
      await tester.runAsync(() async {
        while (series.currentSeries.id != _arabicSeries.id) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      await tester.pumpAndSettle();
    });
  });

  group('ChooseSeriesScreen — header UI', () {
    testWidgets('shows title and subtitle', (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries, _arabicSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Series'), findsOneWidget);
      expect(find.text('Select a series to begin learning'), findsOneWidget);
    });

    testWidgets('header icon is auto_stories_rounded', (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setAvailableSeriesForTest(const [_urduSeries]);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });
  });
}
