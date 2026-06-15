import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/announcement_model.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';

const _book = Book(
  id: 'book',
  title: {'en': 'Test Book'},
  speaker: {'en': 'Sheikh'},
  totalDurationSeconds: 3000,
  lectureCount: 5,
  coverImageUrl: '',
  language: 'English',
);

const _ch1 = Chapter(
  id: 'ch-1',
  number: 1,
  title: {'en': 'Chapter One'},
  lectureCount: 5,
);

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

Lecture _lec(String id, int num) => Lecture(
      id: id,
      number: num,
      chapterId: 'ch-1',
      title: {'en': 'Lecture $num'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1048576,
    );

Lecture _arabicLec(String id, int num) => Lecture(
      id: id,
      number: num,
      chapterId: 'ch-1',
      title: {'en': 'Lecture $num', 'ar': 'الدرس $num'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1048576,
    );

final _lectures = List.generate(5, (i) => _lec('l${i + 1}', i + 1));
final _arabicLectures =
    List.generate(5, (i) => _arabicLec('l${i + 1}', i + 1));

Catalog _catalog({List<DailyBenefit> dailyBenefits = const []}) => Catalog(
      version: 1,
      book: _book,
      chapters: const [_ch1],
      lectures: _lectures,
      dailyBenefits: dailyBenefits,
    );

Catalog _arabicCatalog() => Catalog(
      version: 1,
      book: const Book(
        id: 'arabic-book',
        title: {'en': 'Kitab at-Tawheed', 'ar': 'كتاب التوحيد'},
        speaker: {
          'en': 'Shaikh Salih al-Fawzan Hafizahullah',
          'ar': 'الشيخ صالح الفوزان حفظه الله',
        },
        totalDurationSeconds: 3000,
        lectureCount: 5,
        coverImageUrl: '',
        language: 'Arabic',
      ),
      chapters: const [],
      lectures: _arabicLectures,
      dailyBenefits: const [],
    );

Widget _wrap({
  Catalog? catalog,
  ConnectivityProvider? connectivity,
  DownloadsProvider? downloads,
  FeatureFlagsProvider? featureFlags,
  AnnouncementsProvider? announcements,
  ProgressProvider? progress,
  SeriesProvider? series,
}) {
  final catalogProvider = CatalogProvider()
    ..setCatalogForTest(catalog ?? _catalog());

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider.value(
          value: progress ?? (ProgressProvider()..load())),
      ChangeNotifierProvider.value(value: downloads ?? DownloadsProvider()),
      ChangeNotifierProvider.value(
          value: connectivity ?? ConnectivityProvider.testOnline()),
      ChangeNotifierProvider.value(
          value: featureFlags ?? FeatureFlagsProvider()),
      ChangeNotifierProvider.value(
          value: announcements ?? AnnouncementsProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider.value(
          value: series ?? (SeriesProvider()..load(false))),
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
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
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

  group('HomeScreen — continue listening', () {
    testWidgets('shows empty state when nothing has been played',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Start a lecture to resume here'), findsOneWidget);
    });

    testWidgets('shows lecture title and progress when resuming',
        (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);

      await tester.pumpWidget(_wrap(progress: progress));
      await tester.pumpAndSettle();

      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.text('1:00 listened · 9:00 left'), findsOneWidget);
      expect(find.text('10% complete'), findsOneWidget);
    });

    testWidgets('tapping the card loads the lecture and opens the player',
        (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);

      await tester.pumpWidget(_wrap(
        progress: progress,
        connectivity: ConnectivityProvider.testOffline(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lecture 1'));
      await tester.pumpAndSettle();

      expect(find.text('Player'), findsOneWidget);
    });

    testWidgets(
        'shows the Arabic lecture title for the Arabic series, with l10n chrome unchanged',
        (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);

      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(
        progress: progress,
        series: series,
        catalog: _arabicCatalog(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('الدرس 1'), findsOneWidget);
      expect(find.text('Lecture 1'), findsNothing);
      expect(find.text('1:00 listened · 9:00 left'), findsOneWidget);
      expect(find.text('10% complete'), findsOneWidget);
    });
  });

  group('HomeScreen — offline prep strip', () {
    testWidgets('hidden when nothing has been played', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('Download next'), findsNothing);
    });

    testWidgets('shown with save button when next lectures are not downloaded',
        (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);

      await tester.pumpWidget(_wrap(progress: progress));
      await tester.pumpAndSettle();

      expect(find.text('Download next 3 parts offline'), findsOneWidget);
      expect(find.text('~3.0 MB'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows progress bar when a lecture is already downloading',
        (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);
      final downloads = DownloadsProvider()..seedDownloadingForTest('l2');

      await tester.pumpWidget(_wrap(progress: progress, downloads: downloads));
      await tester.pumpAndSettle();

      expect(find.text('Download next 3 parts offline'), findsOneWidget);
      expect(find.text('Download'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('hidden while offline', (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);

      await tester.pumpWidget(_wrap(
        progress: progress,
        connectivity: ConnectivityProvider.testOffline(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download next'), findsNothing);
    });

    testWidgets('hidden when downloads feature flag is off', (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);

      await tester.pumpWidget(_wrap(
        progress: progress,
        featureFlags: FeatureFlagsProvider()
          ..setFeaturesJsonForTest({'downloads': false}),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download next'), findsNothing);
    });

    testWidgets('dismiss button hides the strip', (tester) async {
      final progress = ProgressProvider()..load();
      await progress.saveProgress('l1', 60);

      await tester.pumpWidget(_wrap(progress: progress));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download next'), findsNothing);
    });
  });

  group('HomeScreen — announcements', () {
    testWidgets('hidden when there are no active announcements',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });

    testWidgets('shows announcement title and body, dismiss removes it',
        (tester) async {
      final announcements = AnnouncementsProvider()
        ..setAnnouncementsForTest(const [
          Announcement(
            id: 'a1',
            type: 'info',
            title: {'en': 'Test Announcement'},
            body: {'en': 'Announcement body text'},
            platforms: ['android', 'ios'],
          ),
        ]);

      await tester.pumpWidget(_wrap(announcements: announcements));
      await tester.pumpAndSettle();

      expect(find.text('Test Announcement'), findsOneWidget);
      expect(find.text('Announcement body text'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Test Announcement'), findsNothing);
    });

    testWidgets('hidden when announcements feature flag is off',
        (tester) async {
      final announcements = AnnouncementsProvider()
        ..setAnnouncementsForTest(const [
          Announcement(
            id: 'a1',
            type: 'info',
            title: {'en': 'Test Announcement'},
            body: {'en': 'Announcement body text'},
            platforms: ['android', 'ios'],
          ),
        ]);

      await tester.pumpWidget(_wrap(
        announcements: announcements,
        featureFlags: FeatureFlagsProvider()
          ..setFeaturesJsonForTest({'announcements': false}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Test Announcement'), findsNothing);
    });
  });

  group('HomeScreen — daily benefit', () {
    testWidgets('hidden when catalog has no daily benefits', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Daily Benefit'), findsNothing);
    });

    testWidgets('shows benefit text and source when present', (tester) async {
      final catalog = _catalog(dailyBenefits: const [
        DailyBenefit(
          id: 'b1',
          text: {'en': 'Test benefit text'},
          source: {'en': 'Test Source'},
        ),
      ]);

      await tester.pumpWidget(_wrap(catalog: catalog));
      await tester.pumpAndSettle();

      expect(find.text('Daily Benefit'), findsOneWidget);
      expect(find.text('Test benefit text'), findsOneWidget);
      expect(find.text('— Test Source'), findsOneWidget);
    });
  });

  group('HomeScreen — overall progress stats', () {
    testWidgets('shows the classes stat when the series has study mode',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('hides the classes stat when the series has no study mode',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(series: series));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
      expect(find.byIcon(Icons.headphones_rounded), findsWidgets);
    });
  });
}
