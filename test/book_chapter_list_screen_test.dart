import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
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

const _testBook = BookContent(
  title: 'كتاب التوحيد',
  author: 'الشيخ محمد بن عبد الوهاب',
  chapters: [
    BookChapter(id: 'intro', number: 0, title: 'مقدمة', text: 'نص المقدمة'),
    BookChapter(
        id: 'ch-01', number: 1, title: 'باب فضل التوحيد', text: 'نص الباب',),
  ],
);

Widget _wrap({required BookProvider book, required SeriesProvider series}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: book),
      ChangeNotifierProvider.value(value: series),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/book',
        routes: [
          GoRoute(
            path: '/book',
            builder: (_, __) => const BookChapterListScreen(),
          ),
          GoRoute(
            path: '/book/:chapterId',
            builder: (context, state) => Scaffold(
              body: Center(
                child: Text('Reader: ${state.pathParameters['chapterId']}'),
              ),
            ),
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

  testWidgets('loaded state shows the book title and chapter list',
      (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(book: book, series: series));
    await tester.pumpAndSettle();

    expect(find.text('كتاب التوحيد'), findsOneWidget);
    expect(find.text('مقدمة'), findsOneWidget);
    expect(find.text('باب فضل التوحيد'), findsOneWidget);
    // Badges are 1-based (start at 1, not 0), in Eastern Arabic-Indic for the
    // Arabic series.
    expect(find.text('٠١'), findsOneWidget);
    expect(find.text('٠٢'), findsOneWidget);
  });

  testWidgets('Urdu series numbers chapters 1-based in Urdu digits',
      (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(SeriesConfig.legacyUrduFallback);

    await tester.pumpWidget(_wrap(book: book, series: series));
    await tester.pumpAndSettle();

    // Urdu numerals (U+06F0…) start at ۰۱, not Arabic-Indic ٠١.
    expect(find.text('۰۱'), findsOneWidget);
    expect(find.text('۰۲'), findsOneWidget);
  });

  testWidgets('badge numerals render in the Urdu font, not the UI font',
      (tester) async {
    // Urdu and Persian share the numeral codepoints (U+06F0–06F9) but draw
    // 4/5/6/7 differently. Getting the codepoints right is not enough — the
    // digits must be laid out in the Urdu face or the UI font's fallback
    // renders Persian-shaped numerals.
    final book = BookProvider()..setBookForTest(_testBook);
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(SeriesConfig.legacyUrduFallback);

    await tester.pumpWidget(_wrap(book: book, series: series));
    await tester.pumpAndSettle();

    final badge = tester.widget<Text>(find.text('۰۱'));
    expect(badge.style?.fontFamily, SeriesConfig.legacyUrduFallback.bookFontFamily);
    expect(badge.style?.fontFamily, 'NotoNastaliqUrdu');
  });

  testWidgets('tapping a chapter navigates to the reader', (tester) async {
    final book = BookProvider()..setBookForTest(_testBook);
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(book: book, series: series));
    await tester.pumpAndSettle();

    await tester.tap(find.text('باب فضل التوحيد'));
    await tester.pumpAndSettle();

    expect(find.text('Reader: ch-01'), findsOneWidget);
  });

  testWidgets('loading state shows a progress indicator', (tester) async {
    // Pin the loading state so the assertion doesn't race the screen's
    // auto-load (which resolves within a pump for a small bundled asset).
    final book = BookProvider()..setLoadingForTest();
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(SeriesConfig.legacyUrduFallback);

    await tester.pumpWidget(_wrap(book: book, series: series));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows a retry button', (tester) async {
    final book = BookProvider()..setErrorForTest(Exception('network down'));
    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(book: book, series: series));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the book'), findsOneWidget);
    expect(find.textContaining('network down'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });
}
