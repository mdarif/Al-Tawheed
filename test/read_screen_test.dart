import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/app.dart' show createAppRouter;
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
import 'package:myapp/screens/read_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/section_tab_header.dart';

import 'support/fake_audio_playback.dart';

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

const _studyOnlySeries = SeriesConfig(
  id: 'study-only',
  catalogUrl: 'https://example.com/study-only/catalog.json',
  storagePrefix: 'so_',
  hasStudyMode: true,
  hasBook: false,
  language: 'ur',
  displayName: {'en': 'Study only'},
  speakerName: {'en': 'Speaker'},
);

const _bookTitle = 'کتاب التوحید';

const _book = BookContent(
  title: _bookTitle,
  author: 'المؤلف',
  chapters: [
    BookChapter(id: 'ch-01', number: 1, title: 'باب فضل التوحيد', text: 'نص'),
    BookChapter(id: 'ch-02', number: 2, title: 'باب الدعاء', text: 'نص'),
  ],
);

Catalog _catalog() => Catalog.fromJson(
      jsonDecode('''
{
  "version": 1,
  "book": {
    "id": "book", "title": "Test", "titleArabic": "", "speaker": "Speaker",
    "totalDurationSeconds": 1200, "lectureCount": 2, "coverImageUrl": "",
    "language": "Urdu"
  },
  "chapters": [
    {"id": "class-01", "number": 1, "title": "Class 01", "lectureCount": 1},
    {"id": "class-02", "number": 2, "title": "Class 02", "lectureCount": 1}
  ],
  "lectures": [
    {"id": "lec-01", "number": 1, "chapterId": "class-01", "title": "P1", "audioUrl": "", "durationSeconds": 600, "fileSizeBytes": 1},
    {"id": "lec-02", "number": 1, "chapterId": "class-02", "title": "P1", "audioUrl": "", "durationSeconds": 600, "fileSizeBytes": 1}
  ],
  "dailyBenefits": []
}
''') as Map<String, dynamic>,
    );

/// The shell with stub sibling branches around the real [ReadScreen], parsing
/// `?tab=` exactly like the production `/read` route does.
GoRouter _substituteRouter(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => ShellScreen(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/lectures',
                  builder: (_, __) => const Scaffold(body: Text('Lectures!')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/read',
                  builder: (_, state) => ReadScreen(
                    initialTab: ReadTab.fromQuery(
                      state.uri.queryParameters['tab'],
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (_, __) => const Scaffold(body: Text('Library!')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (_, __) => const Scaffold(body: Text('Settings!')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Widget _read({
  SeriesProvider? series,
  GoRouter? router,
  String initialLocation = '/read',
  Locale? locale,
  double textScale = 1.0,
  BookContent? book = _book,
}) {
  final activeSeries = series ?? (SeriesProvider()..load(false));
  final progress = ProgressProvider()..load();
  final catalogProvider = CatalogProvider()
    ..setCatalogForTest(
      _catalog(),
      seriesId: activeSeries.currentSeries.id,
    );
  final downloads = DownloadsProvider();
  final connectivity = ConnectivityProvider.testOnline();
  final bookProvider = BookProvider();
  if (book != null) bookProvider.setBookForTest(book);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: activeSeries),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider.value(value: progress),
      ChangeNotifierProvider.value(value: downloads),
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider.value(value: bookProvider),
      ChangeNotifierProvider(
        create: (_) => StudyProgressProvider(progress, catalogProvider)..load(),
      ),
      ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
      ChangeNotifierProvider(create: (_) => ReadingProvider()..load()),
      ChangeNotifierProvider(
        create: (_) => PlayerNotifier(
          FakeAudioPlayback(),
          progress,
          downloads,
          connectivity,
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      routerConfig: router ?? createAppRouter(initialLocation: initialLocation),
    ),
  );
}

/// The index the Read tab bar has selected.
int _selectedTab(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

Finder _tabText(Key tabKey, String text) =>
    find.descendant(of: find.byKey(tabKey), matching: find.text(text));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('Urdu edition (Book and Study)', () {
    testWidgets('header is "Read" + the book title, over Book / Study tabs',
        (tester) async {
      await tester.pumpWidget(_read());
      await tester.pumpAndSettle();

      expect(find.byType(ReadScreen), findsOneWidget);
      expect(find.byKey(WidgetKeys.readHeader), findsOneWidget);
      expect(find.byType(SectionTabHeader), findsOneWidget);
      // Exactly one header: the nav destination plus the title, and no
      // AppBar duplicating it.
      expect(find.text('Read'), findsNWidgets(2));
      expect(find.byType(AppBar), findsNothing);
      expect(find.text(_bookTitle), findsOneWidget);
      expect(_tabText(WidgetKeys.readTabBook, 'Book'), findsOneWidget);
      expect(_tabText(WidgetKeys.readTabStudy, 'Study'), findsOneWidget);
      // No counts, no toggle chips.
      expect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.textContaining(RegExp(r'\d')),
        ),
        findsNothing,
      );
    });

    testWidgets('the book title uses the book font and reads right-to-left',
        (tester) async {
      await tester.pumpWidget(_read());
      await tester.pumpAndSettle();

      final subtitle = tester.widget<Text>(find.text(_bookTitle));
      expect(subtitle.style?.fontFamily, 'NotoNastaliqUrdu');
      expect(subtitle.textDirection, TextDirection.rtl);
    });

    testWidgets('opens on Book by default, with its chapter list',
        (tester) async {
      await tester.pumpWidget(_read());
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 0);
      expect(find.byType(BookChapterListBody), findsOneWidget);
      expect(find.text('باب فضل التوحيد'), findsOneWidget);
    });

    testWidgets('has no overflow menu anywhere', (tester) async {
      await tester.pumpWidget(_read());
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      expect(find.byTooltip('More options'), findsNothing);

      await tester.tap(find.byKey(WidgetKeys.readTabStudy));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    testWidgets('tabs are at least 48dp targets', (tester) async {
      await tester.pumpWidget(_read());
      await tester.pumpAndSettle();

      for (final key in [WidgetKeys.readTabBook, WidgetKeys.readTabStudy]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('tapping Study shows the Study tab', (tester) async {
      await tester.pumpWidget(_read());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.readTabStudy));
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 1);
      expect(find.text('Your progress').hitTestable(), findsOneWidget);
    });
  });

  group('?tab= selects the tab', () {
    testWidgets('tab=study opens Study', (tester) async {
      await tester.pumpWidget(_read(initialLocation: '/read?tab=study'));
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 1);
      expect(find.text('Your progress').hitTestable(), findsOneWidget);
    });

    testWidgets('tab=book opens Book', (tester) async {
      await tester.pumpWidget(_read(initialLocation: '/read?tab=book'));
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 0);
      expect(find.text('باب فضل التوحيد').hitTestable(), findsOneWidget);
    });

    testWidgets('no or unknown tab opens Book', (tester) async {
      await tester.pumpWidget(_read(initialLocation: '/read?tab=nonsense'));
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 0);
    });

    testWidgets('go to ?tab=study while Read is already built', (tester) async {
      final router = _substituteRouter('/read');
      await tester.pumpWidget(_read(router: router));
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), 0);

      router.go('/read?tab=study');
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), 1);
      expect(find.text('Your progress').hitTestable(), findsOneWidget);
    });

    testWidgets('manual tab changes are mirrored into the location',
        (tester) async {
      final router = createAppRouter(initialLocation: '/read');
      await tester.pumpWidget(_read(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.readTabStudy));
      await tester.pumpAndSettle();
      expect(_location(router), '/read?tab=study');

      await tester.tap(find.byKey(WidgetKeys.readTabBook));
      await tester.pumpAndSettle();
      expect(_location(router), '/read?tab=book');
    });

    testWidgets(
        'a repeated link to ?tab=study still lands on Study after the user '
        'switched away', (tester) async {
      final router = _substituteRouter('/read?tab=study');
      await tester.pumpWidget(_read(router: router));
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), 1);

      await tester.tap(find.byKey(WidgetKeys.readTabBook));
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), 0);

      // The same link again, as Study completion issues it every time.
      router.go('/read?tab=study');
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), 1);
    });
  });

  group('tab state', () {
    testWidgets('survives switching shell branches', (tester) async {
      final router = _substituteRouter('/read');
      await tester.pumpWidget(_read(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.readTabStudy));
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), 1);

      await tester.tap(find.byKey(WidgetKeys.shellSettingsTab));
      await tester.pumpAndSettle();
      expect(find.text('Settings!'), findsOneWidget);
      await tester.tap(find.byKey(WidgetKeys.shellReadTab));
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 1);
      expect(find.text('Your progress').hitTestable(), findsOneWidget);
    });

    testWidgets('the Book list keeps its scroll position across tabs',
        (tester) async {
      final longBook = BookContent(
        title: _bookTitle,
        author: 'المؤلف',
        chapters: [
          for (var i = 1; i <= 40; i++)
            BookChapter(id: 'ch-$i', number: i, title: 'باب $i', text: 'x'),
        ],
      );
      await tester.pumpWidget(_read(book: longBook));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final scrolled = position().pixels;
      expect(scrolled, greaterThan(0));

      await tester.tap(find.byKey(WidgetKeys.readTabStudy));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.readTabBook));
      await tester.pumpAndSettle();

      expect(position().pixels, scrolled);
    });
  });

  group('editions with one destination show no tab bar', () {
    testWidgets('Arabic (book only): title, book subtitle, chapter list',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_arabicSeries);
      await tester.pumpWidget(_read(series: series));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
      expect(find.byKey(WidgetKeys.readTabBook), findsNothing);
      expect(find.byKey(WidgetKeys.readTabStudy), findsNothing);
      expect(find.byKey(WidgetKeys.readHeader), findsOneWidget);
      expect(find.text(_bookTitle), findsOneWidget);
      expect(find.byType(BookChapterListBody), findsOneWidget);
      expect(find.byType(StudyBody), findsNothing);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      // The Arabic book is set in Naskh, not Nastaliq.
      final subtitle = tester.widget<Text>(find.text(_bookTitle));
      expect(subtitle.style?.fontFamily, 'NotoNaskhArabic');
    });

    testWidgets('Study only: just the title over the Study body',
        (tester) async {
      final series = SeriesProvider()
        ..load(false)
        ..setCurrentSeriesForTest(_studyOnlySeries);
      await tester.pumpWidget(_read(series: series));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
      expect(find.byKey(WidgetKeys.readHeader), findsOneWidget);
      expect(find.text('Read'), findsNWidgets(2));
      // No book, so no book title beside the title.
      expect(find.text(_bookTitle), findsNothing);
      expect(find.byType(StudyBody), findsOneWidget);
      expect(find.byType(BookChapterListBody), findsNothing);
      expect(find.text('Your progress'), findsOneWidget);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('switching from Urdu to Arabic while open drops the tabs',
        (tester) async {
      final series = SeriesProvider()..load(false);
      await tester.pumpWidget(_read(series: series));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);

      series.setCurrentSeriesForTest(_arabicSeries);
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(BookChapterListBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  for (final (name, locale) in [
    ('Arabic', const Locale('ar')),
    ('Urdu', const Locale('ur')),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$name chrome at ${scale}x text renders without overflow',
          (tester) async {
        tester.view.physicalSize = const Size(360 * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_read(locale: locale, textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text(_bookTitle), findsOneWidget);

        await tester.tap(find.byKey(WidgetKeys.readTabStudy));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_selectedTab(tester), 1);
      });
    }
  }
}
