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
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/chapter_header.dart';
import 'package:myapp/widgets/lecture_tile.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaykh Salih Al-Fawzan'},
);

Map<String, dynamic> _lectureJson(String id, int number) => {
      'id': id,
      'number': number,
      'chapterId': 'ch-01',
      'title': {'en': 'Lecture $number'},
      'audioUrl': 'https://example.com/$id.mp3',
      'durationSeconds': 60,
      'fileSizeBytes': 1000,
    };

Map<String, dynamic> _catalogJson({
  required String bookId,
  required List<Map<String, dynamic>> chapters,
  required List<Map<String, dynamic>> lectures,
}) => {
      'version': 1,
      'book': {
        'id': bookId,
        'title': {'en': 'Test Book'},
        'titleArabic': '',
        'speaker': {'en': 'Speaker'},
        'totalDurationSeconds': lectures
            .fold<int>(0, (sum, l) => sum + (l['durationSeconds'] as int)),
        'lectureCount': lectures.length,
        'coverImageUrl': '',
        'language': 'English',
      },
      'chapters': chapters,
      'lectures': lectures,
      'dailyBenefits': <Map<String, dynamic>>[],
    };

Widget _wrap({required SeriesProvider series}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
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
        initialLocation: '/lectures',
        routes: [
          GoRoute(
            path: '/lectures',
            builder: (_, __) => const LectureListScreen(),
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

  testWidgets('renders chapter headers for a series with chapters',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(_catalogJson(
        bookId: 'legacy-book',
        chapters: const [
          {'id': 'ch-01', 'number': 1, 'title': {'en': 'Chapter One'}, 'lectureCount': 2},
        ],
        lectures: [_lectureJson('lec-001', 1), _lectureJson('lec-002', 2)],
      )),
    );

    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.byType(ChapterHeader), findsOneWidget);
    expect(find.byType(LectureTile), findsNWidgets(2));
  });

  testWidgets('renders a flat lecture list with no chapter headers for a series with no chapters',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(_catalogJson(
        bookId: 'arabic-book',
        chapters: const [],
        lectures: [_lectureJson('lec-001', 1), _lectureJson('lec-002', 2), _lectureJson('lec-003', 3)],
      )),
    );

    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.byType(ChapterHeader), findsNothing);
    expect(find.byType(LectureTile), findsNWidgets(3));
    expect(find.text('Lecture 1'), findsOneWidget);
    expect(find.text('Lecture 2'), findsOneWidget);
    expect(find.text('Lecture 3'), findsOneWidget);
  });
}
