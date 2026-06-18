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
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/choose_series_screen.dart';
import 'package:myapp/screens/welcome.dart';
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
  speakerName: {
    'en': 'Shaikh Salih al-Fawzan Hafizhahullah',
    'ar': 'الشيخ صالح الفوزان حفظه الله',
  },
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

/// Wraps the welcome screen with routing so _startListening() can navigate.
Widget _wrapWithRouter({
  required SeriesProvider series,
  String initialLocation = '/',
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
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
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) {
              final s = context.read<SeriesProvider>();
              if (s.hasCompletedOnboarding) return '/lectures';
              return null;
            },
            builder: (_, __) => const WelcomeScreen(),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('WelcomeScreen — rendering', () {
    testWidgets('Urdu series shows English title and START LISTENING button',
        (tester) async {
      final series = SeriesProvider()..load(false, definitive: true);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      expect(find.text('Sharah Kitab at-Tawheed'), findsOneWidget);
      expect(find.text('START LISTENING'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });

    testWidgets('Arabic series shows Arabic title and Arabic CTA',
        (tester) async {
      final series = SeriesProvider()..load(false, definitive: true);
      series.setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      expect(find.text('شرح كتاب التوحيد'), findsOneWidget);
      expect(find.text('ابدأ الاستماع'), findsOneWidget);
      expect(find.text('START LISTENING'), findsNothing);
    });

    testWidgets('Arabic series shows speaker name', (tester) async {
      final series = SeriesProvider()..load(false, definitive: true);
      series.setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      expect(find.text('الشيخ صالح الفوزان حفظه الله'), findsOneWidget);
    });

    testWidgets('Arabic series shows tagline when series has a book',
        (tester) async {
      final series = SeriesProvider()..load(false, definitive: true);
      series.setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      expect(find.text('شرح صوتي مع متن الكتاب'), findsOneWidget);
    });

    testWidgets('content is hidden while series is loading', (tester) async {
      // load() without definitive: leaves _isLoading = true for multiSeries
      final series = SeriesProvider()..load(true);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pump();

      // Content should be invisible (opacity 0) while isSeriesReady is false
      expect(series.isSeriesReady, isFalse);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets('book icon uses brand color, not hardcoded amber',
        (tester) async {
      final series = SeriesProvider()..load(false, definitive: true);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      final iconWidget = tester.widget<Icon>(
        find.byIcon(Icons.auto_stories_rounded),
      );
      // Brand color should NOT be amber (0xFFFFC107)
      expect(iconWidget.color, isNot(Colors.amber));
      expect(iconWidget.color, isNotNull);
    });
  });

  group('WelcomeScreen — Scenario 2: existing user upgrading', () {
    testWidgets(
        'user with legacy progress sees welcome, taps CTA, goes to lectures',
        (tester) async {
      // Simulate legacy data: saved progress from v2
      await PreferencesService.instance.saveProgress('lec-001', 120);

      final series = SeriesProvider()..load(true, definitive: true);

      // Legacy data detected → pinned to Urdu, hasSelectedSeries = true
      expect(series.hasSelectedSeries, isTrue);
      expect(series.currentSeries.id, SeriesConfig.legacyId);
      expect(series.hasCompletedOnboarding, isFalse);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      // Should see WelcomeScreen (not redirected)
      expect(find.text('START LISTENING'), findsOneWidget);

      await tester.tap(find.text('START LISTENING'));
      await tester.pumpAndSettle();

      // Should go to lectures, onboarding completed
      expect(series.hasCompletedOnboarding, isTrue);
      expect(find.text('Lectures'), findsOneWidget);
    });

    testWidgets(
        'user with legacy bookmarks (no progress) is still treated as existing',
        (tester) async {
      await PreferencesService.instance
          .saveBookmarks({'lec-001', 'lec-002'});

      final series = SeriesProvider()..load(true, definitive: true);

      expect(series.hasSelectedSeries, isTrue);
      expect(series.currentSeries.id, SeriesConfig.legacyId);
    });

    testWidgets(
        'user with legacy downloads (no progress) is still treated as existing',
        (tester) async {
      await PreferencesService.instance.saveDownloadedIds({'lec-001'});

      final series = SeriesProvider()..load(true, definitive: true);

      expect(series.hasSelectedSeries, isTrue);
    });

    testWidgets(
        'user with studied chapters (no progress) is still treated as existing',
        (tester) async {
      await PreferencesService.instance
          .saveStudiedChapterIds({'ch-01'});

      final series = SeriesProvider()..load(true, definitive: true);

      expect(series.hasSelectedSeries, isTrue);
    });
  });

  group('WelcomeScreen — Scenario 3: fresh install, multiSeries OFF', () {
    testWidgets('tapping CTA goes directly to lectures', (tester) async {
      final series = SeriesProvider()..load(false, definitive: true);

      // multiSeries OFF → pinned to Urdu
      expect(series.hasSelectedSeries, isTrue);
      expect(series.currentSeries.id, SeriesConfig.legacyId);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      await tester.tap(find.text('START LISTENING'));
      await tester.pumpAndSettle();

      expect(series.hasCompletedOnboarding, isTrue);
      expect(find.text('Lectures'), findsOneWidget);
    });
  });

  group('WelcomeScreen — Scenario 4: fresh install, multiSeries ON, >1 series',
      () {
    testWidgets('tapping CTA navigates to ChooseSeriesScreen', (tester) async {
      final series = SeriesProvider()
        ..load(true, definitive: true)
        ..setAvailableSeriesForTest(
            const [SeriesConfig.legacyUrduFallback, _arabicSeries]);

      // Fresh install, multiSeries ON, no saved id → hasSelectedSeries = false
      expect(series.hasSelectedSeries, isFalse);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      await tester.tap(find.text('START LISTENING'));
      await tester.pumpAndSettle();

      // Should be on ChooseSeriesScreen, NOT lectures
      expect(find.text('Lectures'), findsNothing);
      // Onboarding not yet completed (deferred to card tap)
      expect(series.hasCompletedOnboarding, isFalse);

      // ChooseSeriesScreen should show both cards
      expect(find.text('Kitab at-Tawheed'), findsOneWidget);
    });
  });

  group('WelcomeScreen — Scenario 6: fresh install, multiSeries ON, 1 series',
      () {
    testWidgets('tapping CTA with single series goes straight to lectures',
        (tester) async {
      await PreferencesService.instance.saveRemoteJson(
          'catalog_tawheed-ur', jsonEncode(_catalogJson('urdu-book')));

      final series = SeriesProvider()
        ..load(true, definitive: true)
        ..setAvailableSeriesForTest(
            const [SeriesConfig.legacyUrduFallback]);
      // Only one series available (the fallback)
      expect(series.availableSeries.length, 1);
      expect(series.hasSelectedSeries, isFalse);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      await tester.tap(find.text('START LISTENING'));
      await tester.pump();

      await tester.runAsync(() async {
        while (!series.hasSelectedSeries) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });

      await tester.pump();
      await tester.pumpAndSettle();

      expect(series.hasCompletedOnboarding, isTrue);
      expect(find.text('Lectures'), findsOneWidget);
    });
  });

  group('WelcomeScreen — redirect', () {
    testWidgets(
        'returning user (onboarding completed) is redirected to lectures',
        (tester) async {
      await PreferencesService.instance.saveHasCompletedOnboarding();

      final series = SeriesProvider()..load(false, definitive: true);
      expect(series.hasCompletedOnboarding, isTrue);

      await tester.pumpWidget(_wrapWithRouter(series: series));
      await tester.pumpAndSettle();

      // Should never see WelcomeScreen
      expect(find.text('START LISTENING'), findsNothing);
      expect(find.text('ابدأ الاستماع'), findsNothing);
      expect(find.text('Lectures'), findsOneWidget);
    });
  });
}
