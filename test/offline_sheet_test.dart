import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/offline_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Single Arabic-series lecture (no chapter section shown).
Lecture _arabicLec() => Lecture(
      id: 'lec-ar',
      number: 2,
      chapterId: 'ch-ar',
      title: const {'en': 'Dars 02', 'ar': 'الدرس 2'},
      audioUrl: 'https://example.com/audio.mp3',
      durationSeconds: 120,
      fileSizeBytes: 5 * 1024 * 1024, // 5 MB
    );

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Single lecture in a single-lecture chapter (no chapter section shown).
Lecture _singleLec() => Lecture(
      id: 'lec-solo',
      number: 1,
      chapterId: 'ch-solo',
      title: const {'en': 'Solo Lecture'},
      audioUrl: 'https://example.com/audio.mp3',
      durationSeconds: 120,
      fileSizeBytes: 5 * 1024 * 1024, // 5 MB
    );

/// Three lectures in the same chapter (chapter section shown).
List<Lecture> _threeLecs() => [
      Lecture(
        id: 'lec-a',
        number: 1,
        chapterId: 'ch-multi',
        title: const {'en': 'Part 1'},
        audioUrl: '',
        durationSeconds: 60,
        fileSizeBytes: 2 * 1024 * 1024,
      ),
      Lecture(
        id: 'lec-b',
        number: 2,
        chapterId: 'ch-multi',
        title: const {'en': 'Part 2'},
        audioUrl: '',
        durationSeconds: 60,
        fileSizeBytes: 2 * 1024 * 1024,
      ),
      Lecture(
        id: 'lec-c',
        number: 3,
        chapterId: 'ch-multi',
        title: const {'en': 'Part 3'},
        audioUrl: '',
        durationSeconds: 60,
        fileSizeBytes: 2 * 1024 * 1024,
      ),
    ];

// ── Widget helpers ────────────────────────────────────────────────────────────

/// Opens the sheet immediately after first frame so tests can interact with it.
class _SheetOpener extends StatefulWidget {
  final Lecture lecture;
  const _SheetOpener({required this.lecture});

  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showOfflineSheet(context, widget.lecture);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}

/// Full provider + router wrapper for offline-sheet widget tests.
Widget _wrap({
  required Lecture lecture,
  required DownloadsProvider downloads,
  ConnectivityProvider? connectivity,
  List<Lecture> allLectures = const [],
  SeriesProvider? series,
}) {
  final chapters = allLectures.isEmpty
      ? <Chapter>[]
      : allLectures
          .map((l) => l.chapterId)
          .toSet()
          .map((id) => Chapter(
                id: id,
                number: 1,
                title: const {'en': 'Chapter'},
                lectureCount: allLectures.where((l) => l.chapterId == id).length,
              ))
          .toList();

  final catalog = Catalog(
    version: 1,
    book: const Book(
      id: 'book',
      title: {'en': 'Book'},
      speaker: {'en': 'Speaker'},
      totalDurationSeconds: 0,
      lectureCount: 0,
      coverImageUrl: '',
      language: 'English',
    ),
    chapters: chapters,
    lectures: allLectures.isEmpty ? [lecture] : allLectures,
    dailyBenefits: [],
  );

  final catalogProvider = CatalogProvider()..setCatalogForTest(catalog);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider.value(value: downloads),
      ChangeNotifierProvider.value(
          value: connectivity ?? ConnectivityProvider.testOnline()),
      ChangeNotifierProvider.value(
          value: series ?? (SeriesProvider()..load(false))),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => _SheetOpener(lecture: lecture),
          ),
          GoRoute(
            path: '/offline-library',
            builder: (_, __) =>
                const Scaffold(body: Text('Offline Library Screen')),
          ),
        ],
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  // ── Lecture download states ───────────────────────────────────────────────

  group('OfflineSheet — lecture download state', () {
    testWidgets('shows "Download lecture" when lecture not downloaded',
        (tester) async {
      final lec = _singleLec();
      await tester.pumpWidget(_wrap(
        lecture: lec,
        downloads: DownloadsProvider(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download lecture'), findsOneWidget);
      expect(find.textContaining('Remove download'), findsNothing);
    });

    testWidgets('shows "Remove download" when lecture is downloaded',
        (tester) async {
      final lec = _singleLec();
      final downloads = DownloadsProvider()..seedDownloadedForTest(lec.id);

      await tester.pumpWidget(_wrap(lecture: lec, downloads: downloads));
      await tester.pumpAndSettle();

      expect(find.textContaining('Remove download'), findsOneWidget);
      expect(find.textContaining('Download lecture'), findsNothing);
    });

    testWidgets('shows progress + cancel when lecture is downloading',
        (tester) async {
      final lec = _singleLec();
      final downloads = DownloadsProvider()..seedDownloadingForTest(lec.id);

      await tester.pumpWidget(_wrap(lecture: lec, downloads: downloads));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Cancel download'), findsOneWidget);
      expect(find.textContaining('Download lecture'), findsNothing);
    });
  });

  // ── Chapter section ───────────────────────────────────────────────────────

  group('OfflineSheet — chapter section', () {
    testWidgets(
        'chapter section hidden when chapter has only one lecture',
        (tester) async {
      final lec = _singleLec();
      await tester.pumpWidget(_wrap(
        lecture: lec,
        downloads: DownloadsProvider(),
        allLectures: [lec], // single-lecture chapter
      ));
      await tester.pumpAndSettle();

      // No chapter-level download/cancel chips
      expect(find.textContaining('Download chapter'), findsNothing);
      expect(find.textContaining('Cancel chapter download'), findsNothing);
    });

    testWidgets(
        'chapter section shows "Download chapter" for multi-lecture chapter',
        (tester) async {
      final lecs = _threeLecs();
      await tester.pumpWidget(_wrap(
        lecture: lecs.first,
        downloads: DownloadsProvider(),
        allLectures: lecs,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download chapter'), findsOneWidget);
    });

    testWidgets(
        'chapter section shows "Cancel chapter download" when chapter downloading',
        (tester) async {
      final lecs = _threeLecs();
      final downloads = DownloadsProvider()
        ..seedChapterDownloadingForTest(lecs.first.chapterId);

      await tester.pumpWidget(_wrap(
        lecture: lecs.first,
        downloads: downloads,
        allLectures: lecs,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cancel chapter download'), findsOneWidget);
      expect(find.textContaining('Download chapter'), findsNothing);
    });

    testWidgets(
        'chapter section hidden when chapter is fully downloaded',
        (tester) async {
      final lecs = _threeLecs();
      final downloads = DownloadsProvider()
        ..seedDownloadedForTest('lec-a')
        ..seedDownloadedForTest('lec-b')
        ..seedDownloadedForTest('lec-c');

      await tester.pumpWidget(_wrap(
        lecture: lecs.first,
        downloads: downloads,
        allLectures: lecs,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download chapter'), findsNothing);
      expect(find.textContaining('Cancel chapter download'), findsNothing);
    });
  });

  // ── Manage downloads link ─────────────────────────────────────────────────

  group('OfflineSheet — Manage downloads', () {
    testWidgets('"Manage downloads" is always visible', (tester) async {
      await tester.pumpWidget(_wrap(
        lecture: _singleLec(),
        downloads: DownloadsProvider(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Manage downloads'), findsOneWidget);
    });

    testWidgets(
        'tapping "Manage downloads" dismisses sheet and navigates to offline library',
        (tester) async {
      await tester.pumpWidget(_wrap(
        lecture: _singleLec(),
        downloads: DownloadsProvider(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage downloads'));
      await tester.pumpAndSettle();

      // Sheet is gone and the offline library screen is visible
      expect(find.text('Manage downloads'), findsNothing);
      expect(find.text('Offline Library Screen'), findsOneWidget);
    });
  });

  // ── Wi-Fi only blocking ───────────────────────────────────────────────────

  group('OfflineSheet — Wi-Fi only gate', () {
    testWidgets('shows snackbar when wifi-only is on and device is on mobile',
        (tester) async {
      final lec = _singleLec();
      final downloads = DownloadsProvider();
      await downloads.setDownloadOnWifiOnly(true);

      await tester.pumpWidget(_wrap(
        lecture: lec,
        downloads: downloads,
        connectivity: ConnectivityProvider.testOnlineMobile(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Download lecture'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ── Arabic series ─────────────────────────────────────────────────────────

  group('OfflineSheet — Arabic series', () {
    testWidgets(
        'shows Arabic lecture title and chrome labels when not downloaded',
        (tester) async {
      final lec = _arabicLec();
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(
        lecture: lec,
        downloads: DownloadsProvider(),
        series: series,
      ));
      await tester.pumpAndSettle();

      // Header shows the Arabic lecture title, not the English one.
      expect(find.text('الدرس 2'), findsOneWidget);
      expect(find.text('Dars 02'), findsNothing);

      // "Download lecture" and "Manage downloads" chrome in Arabic.
      expect(find.text('تحميل الدرس · 5.0 MB'), findsOneWidget);
      expect(find.textContaining('Download lecture'), findsNothing);
      expect(find.text('إدارة التنزيلات'), findsOneWidget);
      expect(find.text('Manage downloads'), findsNothing);
    });

    testWidgets(
        'shows Arabic "Remove download" tile and confirm-dialog buttons when downloaded',
        (tester) async {
      final lec = _arabicLec();
      final downloads = DownloadsProvider()..seedDownloadedForTest(lec.id);
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(
        lecture: lec,
        downloads: downloads,
        series: series,
      ));
      await tester.pumpAndSettle();

      expect(find.text('إزالة التحميل'), findsOneWidget);
      expect(find.text('Remove download'), findsNothing);

      await tester.tap(find.text('إزالة التحميل'));
      await tester.pumpAndSettle();

      // Confirm dialog title, message (lecture title), and confirm/cancel
      // buttons all render in Arabic.
      expect(find.text('إزالة التحميل'), findsNWidgets(3));
      expect(find.text('الدرس 2'), findsNWidgets(2));
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('shows Arabic downloading progress label and "Cancel download"',
        (tester) async {
      final lec = _arabicLec();
      final downloads = DownloadsProvider()..seedDownloadingForTest(lec.id);
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(
        lecture: lec,
        downloads: downloads,
        series: series,
      ));
      await tester.pumpAndSettle();

      expect(find.text('جارٍ التحميل... 50%'), findsOneWidget);
      expect(find.textContaining('Downloading'), findsNothing);
      expect(find.text('إلغاء التحميل'), findsOneWidget);
      expect(find.text('Cancel download'), findsNothing);
    });

    testWidgets('shows Arabic Wi-Fi-only snackbar message', (tester) async {
      final lec = _arabicLec();
      final downloads = DownloadsProvider();
      await downloads.setDownloadOnWifiOnly(true);
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(
        lecture: lec,
        downloads: downloads,
        connectivity: ConnectivityProvider.testOnlineMobile(),
        series: series,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('تحميل الدرس'));
      await tester.pump();

      expect(find.text('اتصل بشبكة Wi-Fi للتحميل'), findsOneWidget);
      expect(find.text('Connect to Wi-Fi to download'), findsNothing);
    });
  });
}
