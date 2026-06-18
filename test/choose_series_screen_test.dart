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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('renders a card for each available series', (tester) async {
    final series = SeriesProvider()
      ..load(false)
      ..setAvailableSeriesForTest(
          const [SeriesConfig.legacyUrduFallback, _arabicSeries]);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.text('Kitab at-Tawheed'), findsOneWidget);
    expect(find.text('كتاب التوحيد'), findsOneWidget);
    // Both cards carry an "Audio" chip; the language qualifier chip is gone.
    expect(find.text('Audio'), findsNWidgets(2));
    expect(find.text('Urdu'), findsNothing);
    expect(find.text('Arabic'), findsNothing);
    expect(find.text('Study Mode'), findsOneWidget);
    expect(find.text('Book'), findsOneWidget);
    // Speaker names are shown without the leading "Shaikh" honorific.
    expect(find.text('Abdullah Nasir Rahmani Hafizahullah'), findsOneWidget);
    expect(find.text('Salih al-Fawzan Hafizhahullah'), findsOneWidget);
  });

  testWidgets('selecting a series switches to it and goes to lectures',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
        'catalog_tawheed-ar', jsonEncode(_catalogJson('arabic-book')));

    final series = SeriesProvider()
      ..load(false)
      ..setAvailableSeriesForTest(
          const [SeriesConfig.legacyUrduFallback, _arabicSeries]);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    // Tapping shows a CircularProgressIndicator while switching, which
    // animates forever — so settle via runAsync (switchSeries does real
    // async work, e.g. TawheedAudioHandler.stop()) instead of pumpAndSettle().
    await tester.tap(find.text('Salih al-Fawzan Hafizhahullah'));
    await tester.pump();

    await tester.runAsync(() async {
      while (series.currentSeries.id != 'tawheed-ar') {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });

    await tester.pump();
    await tester.pumpAndSettle();

    expect(series.currentSeries.id, 'tawheed-ar');
    expect(PreferencesService.instance.selectedSeriesId, 'tawheed-ar');
    expect(series.hasCompletedOnboarding, isTrue);
    expect(find.text('Lectures'), findsOneWidget);
  });
}
