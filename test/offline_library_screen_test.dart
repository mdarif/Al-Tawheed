import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/offline_library_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Test catalog ──────────────────────────────────────────────────────────────

const _book = Book(
  id: 'book',
  title: {'en': 'Test Book'},
  speaker: {'en': 'Sheikh'},
  totalDurationSeconds: 0,
  lectureCount: 5,
  coverImageUrl: '',
  language: 'English',
);

const _ch1 = Chapter(id: 'ch-1', number: 1, title: {'en': 'Chapter One'}, lectureCount: 3);
const _ch2 = Chapter(id: 'ch-2', number: 2, title: {'en': 'Chapter Two'}, lectureCount: 2);

Lecture _lec(String id, int num, String chapterId, {int bytes = 1048576}) =>
    Lecture(
      id: id,
      number: num,
      chapterId: chapterId,
      title: {'en': 'Part $num'},
      audioUrl: '',
      durationSeconds: 60,
      fileSizeBytes: bytes,
    );

final _ch1Lecs = [
  _lec('l1', 1, 'ch-1'),
  _lec('l2', 2, 'ch-1'),
  _lec('l3', 3, 'ch-1'),
];
final _ch2Lecs = [
  _lec('l4', 1, 'ch-2'),
  _lec('l5', 2, 'ch-2'),
];

Catalog _catalog() => Catalog(
      version: 1,
      book: _book,
      chapters: const [_ch1, _ch2],
      lectures: [..._ch1Lecs, ..._ch2Lecs],
      dailyBenefits: const [],
    );

// ── Arabic series fixtures (flat list, no chapters) ─────────────────────────

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

Lecture _arabicLec(String id, int num) => Lecture(
      id: id,
      number: num,
      chapterId: 'ch-ar',
      title: {'en': 'Dars 0$num', 'ar': 'الدرس $num'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 120,
      fileSizeBytes: 5 * 1024 * 1024,
    );

Catalog _arabicCatalog() => Catalog(
      version: 1,
      book: const Book(
        id: 'arabic-book',
        title: {'en': 'Kitab at-Tawheed', 'ar': 'كتاب التوحيد'},
        speaker: {'en': 'Shaikh', 'ar': 'الشيخ'},
        totalDurationSeconds: 0,
        lectureCount: 2,
        coverImageUrl: '',
        language: 'Arabic',
      ),
      chapters: const [],
      lectures: [_arabicLec('ar-1', 1), _arabicLec('ar-2', 2)],
      dailyBenefits: const [],
    );

// ── Widget helpers ────────────────────────────────────────────────────────────

Widget _wrap(DownloadsProvider downloads,
    {Catalog? catalog, SeriesProvider? series}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
          create: (_) =>
              CatalogProvider()..setCatalogForTest(catalog ?? _catalog())),
      ChangeNotifierProvider.value(value: downloads),
      ChangeNotifierProvider(
          create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider.value(
          value: series ?? (SeriesProvider()..load(false))),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OfflineLibraryScreen(),
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

  // ── Empty state ───────────────────────────────────────────────────────────

  group('OfflineLibraryScreen — empty state', () {
    testWidgets('shows empty state when no lectures are downloaded',
        (tester) async {
      await tester.pumpWidget(_wrap(DownloadsProvider()));
      await tester.pumpAndSettle();

      expect(find.text('No downloads yet'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });

  // ── Populated state ───────────────────────────────────────────────────────

  group('OfflineLibraryScreen — populated state', () {
    testWidgets('shows downloaded lectures grouped by chapter', (tester) async {
      final downloads = DownloadsProvider()
        ..seedDownloadedForTest('l1')
        ..seedDownloadedForTest('l2');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      expect(find.text('Chapter One'), findsOneWidget);
      expect(find.text('Part 1'), findsOneWidget);
      expect(find.text('Part 2'), findsOneWidget);
      // Chapter Two has no downloads → not shown
      expect(find.text('Chapter Two'), findsNothing);
    });

    testWidgets('chapter header shows correct downloaded / total count',
        (tester) async {
      final downloads = DownloadsProvider()..seedDownloadedForTest('l1');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      // l1 is in ch-1 which has 3 lectures total; 1 is saved
      expect(find.textContaining('1 of 3'), findsOneWidget);
    });

    testWidgets(
        '"Download remaining" chip shown when chapter is partially downloaded',
        (tester) async {
      final downloads = DownloadsProvider()..seedDownloadedForTest('l1');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download remaining'), findsOneWidget);
    });

    testWidgets(
        '"Delete chapter" chip shown when entire chapter is downloaded',
        (tester) async {
      final downloads = DownloadsProvider()
        ..seedDownloadedForTest('l1')
        ..seedDownloadedForTest('l2')
        ..seedDownloadedForTest('l3');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      expect(find.textContaining('Remove chapter'), findsOneWidget);
      expect(find.textContaining('Download remaining'), findsNothing);
    });

    testWidgets('lectures from two chapters both appear when both have downloads',
        (tester) async {
      final downloads = DownloadsProvider()
        ..seedDownloadedForTest('l1')
        ..seedDownloadedForTest('l4');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      expect(find.text('Chapter One'), findsOneWidget);
      expect(find.text('Chapter Two'), findsOneWidget);
    });
  });

  // ── Delete lecture ────────────────────────────────────────────────────────

  group('OfflineLibraryScreen — delete lecture', () {
    testWidgets('delete icon triggers confirmation dialog', (tester) async {
      final downloads = DownloadsProvider()..seedDownloadedForTest('l1');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      // Tap the delete icon for the downloaded lecture
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.textContaining('Remove download'), findsWidgets);
    });

    testWidgets('cancelling the dialog leaves the lecture in place',
        (tester) async {
      final downloads = DownloadsProvider()..seedDownloadedForTest('l1');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(downloads.isDownloaded('l1'), isTrue);
    });
  });

  // ── Delete chapter ────────────────────────────────────────────────────────

  group('OfflineLibraryScreen — delete chapter', () {
    testWidgets('cancel delete-chapter dialog keeps lectures downloaded',
        (tester) async {
      final downloads = DownloadsProvider()
        ..seedDownloadedForTest('l1')
        ..seedDownloadedForTest('l2')
        ..seedDownloadedForTest('l3');

      await tester.pumpWidget(_wrap(downloads));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Remove chapter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(downloads.isDownloaded('l1'), isTrue);
      expect(downloads.isDownloaded('l2'), isTrue);
      expect(downloads.isDownloaded('l3'), isTrue);
    });
  });

  // ── Arabic series (flat list, no chapters) ──────────────────────────────

  group('OfflineLibraryScreen — Arabic series (flat list)', () {
    testWidgets(
        'shows the downloaded Arabic lecture without chapter grouping',
        (tester) async {
      final downloads = DownloadsProvider()..seedDownloadedForTest('ar-1');
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(
          _wrap(downloads, catalog: _arabicCatalog(), series: series));
      await tester.pumpAndSettle();

      // Downloaded lecture shows its Arabic title, not the English one.
      expect(find.text('الدرس 1'), findsOneWidget);
      expect(find.text('Dars 01'), findsNothing);

      // Only the downloaded lecture is listed.
      expect(find.text('الدرس 2'), findsNothing);

      // No chapter section/header for the flat series.
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets(
        'shows empty state when nothing is downloaded for the Arabic series',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(_wrap(DownloadsProvider(),
          catalog: _arabicCatalog(), series: series));
      await tester.pumpAndSettle();

      expect(find.text('No downloads yet'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets(
        'delete icon shows Arabic confirm dialog with the Arabic lecture title',
        (tester) async {
      final downloads = DownloadsProvider()..seedDownloadedForTest('ar-1');
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);

      await tester.pumpWidget(
          _wrap(downloads, catalog: _arabicCatalog(), series: series));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Dialog title + confirm button both read "إزالة التحميل".
      expect(find.text('إزالة التحميل'), findsNWidgets(2));
      expect(find.text('Remove download'), findsNothing);

      // Dialog message shows the Arabic lecture title (list tile + dialog).
      expect(find.text('الدرس 1'), findsNWidgets(2));

      // Cancel button reads "إلغاء", not "Cancel".
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  });
}
