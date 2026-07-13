import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/continue_listening_banner.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: false,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

const _book = Book(
  id: 'book',
  title: {'en': 'Test Book'},
  speaker: {'en': 'Sheikh'},
  totalDurationSeconds: 3000,
  lectureCount: 5,
  coverImageUrl: '',
  language: 'English',
);

Lecture _lec(String id, int num, {String? titleAr}) => Lecture(
      id: id,
      number: num,
      chapterId: 'ch-1',
      title: {'en': 'Lecture $num', if (titleAr != null) 'ar': titleAr},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1048576,
    );

final _lectures = List.generate(5, (i) => _lec('l${i + 1}', i + 1));
final _arabicLectures =
    List.generate(5, (i) => _lec('l${i + 1}', i + 1, titleAr: 'الدرس ${i + 1}'));

Catalog _catalog({bool arabic = false}) => Catalog(
      version: 1,
      book: _book,
      chapters: const [],
      lectures: arabic ? _arabicLectures : _lectures,
      dailyBenefits: const [],
    );

Widget _wrap({
  Catalog? catalog,
  ProgressProvider? progress,
  SeriesProvider? series,
  ConnectivityProvider? connectivity,
}) {
  final catalogProvider = CatalogProvider()
    ..setCatalogForTest(catalog ?? _catalog());

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider.value(
          value: progress ?? (ProgressProvider()..load()),),
      ChangeNotifierProvider.value(value: DownloadsProvider()),
      ChangeNotifierProvider.value(
          value: connectivity ?? ConnectivityProvider.testOnline(),),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider.value(
          value: series ?? (SeriesProvider()..load(false)),),
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
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: ContinueListeningBanner()),
            ),
          ),
          GoRoute(
            path: '/player',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Player'))),
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

  testWidgets('hidden — takes no space — when nothing has been played',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Continue Listening'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows lecture title and progress when resuming', (tester) async {
    final progress = ProgressProvider()..load();
    await progress.saveProgress('l1', 60);

    await tester.pumpWidget(_wrap(progress: progress));
    await tester.pumpAndSettle();

    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Lecture 1'), findsOneWidget);
    expect(find.text('1:00 listened · 9:00 left'), findsOneWidget);
    expect(find.text('10% complete'), findsOneWidget);
  });

  testWidgets('tapping resumes into the player', (tester) async {
    final progress = ProgressProvider()..load();
    await progress.saveProgress('l1', 60);

    await tester.pumpWidget(_wrap(
      progress: progress,
      connectivity: ConnectivityProvider.testOffline(),
    ),);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lecture 1'));
    await tester.pumpAndSettle();

    expect(find.text('Player'), findsOneWidget);
  });

  testWidgets('Arabic series shows Arabic title and chrome', (tester) async {
    final progress = ProgressProvider()..load();
    await progress.saveProgress('l1', 60);

    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(
      progress: progress,
      series: series,
      catalog: _catalog(arabic: true),
    ),);
    await tester.pumpAndSettle();

    expect(find.text('الدرس 1'), findsOneWidget);
    expect(find.text('متابعة الاستماع'), findsOneWidget);
    expect(find.text('1:00 مستمَع · 9:00 متبقٍّ'), findsOneWidget);
    expect(find.text('10% مكتمل'), findsOneWidget);
  });
}
