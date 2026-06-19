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
    expect(find.text('00'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
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

  testWidgets('idle state shows a progress indicator', (tester) async {
    final book = BookProvider();
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
