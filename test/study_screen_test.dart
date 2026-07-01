import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/study/class_progress_card.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: true,
  hasBook: false,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

/// Builds a minimal catalog JSON that [Catalog.fromJson] accepts.
/// [chapters] entries must each have id/number/title/lectureCount.
Map<String, dynamic> _catalogJson({
  required String bookId,
  required List<Map<String, dynamic>> chapters,
}) {
  final lectures = <Map<String, dynamic>>[
    for (var i = 0; i < chapters.length; i++)
      {
        'id': 'lec-${(i + 1).toString().padLeft(3, '0')}',
        'number': i + 1,
        'chapterId': (chapters[i]['id'] as String),
        'title': {'en': 'Lecture ${i + 1}'},
        'audioUrl': 'https://example.com/lec-${i + 1}.mp3',
        'durationSeconds': 60,
        'fileSizeBytes': 1000,
      },
  ];
  return {
    'version': 1,
    'book': {
      'id': bookId,
      'title': {'en': 'Test Book'},
      'speaker': {'en': 'Speaker'},
      'totalDurationSeconds': 60 * chapters.length,
      'lectureCount': chapters.length,
      'coverImageUrl': '',
      'language': 'ur',
    },
    'chapters': chapters,
    'lectures': lectures,
    'dailyBenefits': <Map<String, dynamic>>[],
  };
}

Widget _wrap({required SeriesProvider series, CatalogProvider? catalog}) {
  final catalogProvider = catalog ?? CatalogProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(
        create: (ctx) => StudyProgressProvider(
          ctx.read<ProgressProvider>(),
          ctx.read<CatalogProvider>(),
        )..load(),
      ),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/study',
        routes: [
          GoRoute(
            path: '/study',
            builder: (_, __) => const StudyScreen(),
          ),
          GoRoute(
            path: '/player',
            builder: (_, __) => const Scaffold(body: SizedBox()),
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

  testWidgets('shows a ClassProgressCard for each chapter in the catalog',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(_catalogJson(
        bookId: 'urdu-book',
        chapters: const [
          {
            'id': 'ch-01',
            'number': 1,
            'title': {'en': 'Introduction to Tawheed'},
            'lectureCount': 1,
          },
          {
            'id': 'ch-02',
            'number': 2,
            'title': {'en': 'Tawheed al-Rububiyyah'},
            'lectureCount': 1,
          },
        ],
      ),),
    );

    final series = SeriesProvider()..load(false);
    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.byType(ClassProgressCard), findsNWidgets(2));
    expect(find.text('Introduction to Tawheed'), findsOneWidget);
    expect(find.text('Tawheed al-Rububiyyah'), findsOneWidget);
  });

  testWidgets('shows an error body when the catalog fails to load',
      (tester) async {
    // Inject error state directly so the test does not depend on HTTP timing.
    final catalog = CatalogProvider();
    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series, catalog: catalog));

    // Override whatever load() tried with a known error state.
    catalog.setErrorForTest(Exception('Server unavailable'));
    await tester.pump();

    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.byType(ClassProgressCard), findsNothing);
  });

  testWidgets(
      'reloads the catalog when the active series changes — no series/catalog desync',
      (tester) async {
    // Urdu (legacy) catalog under the bare cache key.
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(_catalogJson(
        bookId: 'urdu-book',
        chapters: const [
          {
            'id': 'ch-01',
            'number': 1,
            'title': {'en': 'Urdu Class One'},
            'lectureCount': 1,
          },
          {
            'id': 'ch-02',
            'number': 2,
            'title': {'en': 'Urdu Class Two'},
            'lectureCount': 1,
          },
        ],
      ),),
    );
    // Arabic catalog under the namespaced cache key.
    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(_catalogJson(
        bookId: 'arabic-book',
        chapters: const [
          {
            'id': 'ch-01',
            'number': 1,
            'title': {'en': 'Arabic Class One'},
            'lectureCount': 1,
          },
          {
            'id': 'ch-02',
            'number': 2,
            'title': {'en': 'Arabic Class Two'},
            'lectureCount': 1,
          },
        ],
      ),),
    );

    // Mount on the Urdu (legacy) series.
    final series = SeriesProvider()..load(false);
    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.text('Urdu Class One'), findsOneWidget);
    expect(find.text('Urdu Class Two'), findsOneWidget);
    expect(find.text('Arabic Class One'), findsNothing);
    expect(find.text('Arabic Class Two'), findsNothing);

    // The active series flips to Arabic.
    series.setCurrentSeriesForTest(_arabicSeries);
    await tester.pumpAndSettle();

    // Study screen must reflect the Arabic catalog — no Urdu content remains.
    expect(find.text('Arabic Class One'), findsOneWidget);
    expect(find.text('Arabic Class Two'), findsOneWidget);
    expect(find.text('Urdu Class One'), findsNothing);
    expect(find.text('Urdu Class Two'), findsNothing);
  });
}
