import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/continue_reading_banner.dart';

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

const _book = BookContent(
  title: 'كتاب التوحيد',
  author: 'الشيخ محمد بن عبد الوهاب',
  chapters: [
    BookChapter(id: 'ch-01', number: 1, title: 'الباب الأول', text: 'نص'),
    BookChapter(id: 'ch-02', number: 2, title: 'الباب الثاني', text: 'نص'),
  ],
);

Widget _wrap({
  ReadingProvider? reading,
  SeriesProvider? series,
  BookProvider? book,
  Locale? locale,
  VoidCallback? onBookRoute,
}) {
  final bookProvider = book ?? (BookProvider()..setBookForTest(_book));
  final seriesProvider = series ?? SeriesProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: bookProvider),
      ChangeNotifierProvider.value(value: seriesProvider),
      ChangeNotifierProvider.value(
        value: reading ?? (ReadingProvider(seriesProvider)..load()),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: ContinueReadingBanner()),
            ),
          ),
          GoRoute(
            path: '/book/:chapterId',
            builder: (_, state) {
              onBookRoute?.call();
              return Scaffold(
                body: Center(
                  child: Text(
                    'Book ${state.pathParameters['chapterId']}'
                    '${state.uri.queryParameters['startFromTop'] == 'true' ? ' (top)' : ''}',
                  ),
                ),
              );
            },
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

  testWidgets('hidden — takes no space — when nothing has been read',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Continue Reading'), findsNothing);
  });

  testWidgets('shows the chapter title when resuming', (tester) async {
    final series = SeriesProvider();
    final reading = ReadingProvider(series)..load();
    await reading.setBookScrollOffset('ch-01', 200);

    await tester.pumpWidget(_wrap(reading: reading, series: series));
    await tester.pumpAndSettle();

    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('الباب الأول'), findsOneWidget);
  });

  testWidgets('hidden when the saved chapter no longer exists in the book',
      (tester) async {
    final series = SeriesProvider();
    final reading = ReadingProvider(series)..load();
    await reading.setBookScrollOffset('ch-removed', 200);

    await tester.pumpWidget(_wrap(reading: reading, series: series));
    await tester.pumpAndSettle();

    expect(find.text('Continue Reading'), findsNothing);
  });

  testWidgets('tapping the card resumes the saved chapter', (tester) async {
    final series = SeriesProvider();
    final reading = ReadingProvider(series)..load();
    await reading.setBookScrollOffset('ch-01', 200);
    var routed = false;

    await tester.pumpWidget(
      _wrap(
        reading: reading,
        series: series,
        onBookRoute: () => routed = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الباب الأول'));
    await tester.pumpAndSettle();

    expect(routed, isTrue);
    expect(find.text('Book ch-01'), findsOneWidget);
  });

  testWidgets('the start-from-top action opens the chapter at the top',
      (tester) async {
    final series = SeriesProvider();
    final reading = ReadingProvider(series)..load();
    await reading.setBookScrollOffset('ch-01', 200);

    await tester.pumpWidget(_wrap(reading: reading, series: series));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.replay_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Book ch-01 (top)'), findsOneWidget);
  });

  testWidgets('Arabic series shows Arabic wording and RTL alignment',
      (tester) async {
    final series = SeriesProvider()..setCurrentSeriesForTest(_arabicSeries);
    final reading = ReadingProvider(series)..load();
    await reading.setBookScrollOffset('ch-01', 200);

    await tester.pumpWidget(
      _wrap(reading: reading, series: series, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('متابعة القراءة'), findsOneWidget);
    expect(find.text('الباب الأول'), findsOneWidget);
  });
}
