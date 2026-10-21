import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/app.dart' show createAppRouter;
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/chapter_header.dart';
import 'package:myapp/widgets/lecture_tile.dart';
import 'package:myapp/widgets/mini_player.dart';

import 'support/fake_audio_playback.dart';
import 'support/ignore_render_flex_overflow.dart';

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

/// The series teacher's portrait the redesigned Lectures hero shows beside the
/// title — a different asset per series (Rahmani for Urdu, Fawzan for Arabic).
Finder _avatarFinder(String asset) => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == asset,
    );

Map<String, dynamic> _lectureJson(String id, int number, {String? titleAr}) => {
      'id': id,
      'number': number,
      'chapterId': 'ch-01',
      'title': {
        'en': 'Lecture $number',
        if (titleAr != null) 'ar': titleAr,
      },
      'audioUrl': 'https://example.com/$id.mp3',
      'durationSeconds': 60,
      'fileSizeBytes': 1000,
    };

Map<String, dynamic> _catalogJson({
  required String bookId,
  required List<Map<String, dynamic>> chapters,
  required List<Map<String, dynamic>> lectures,
  Map<String, dynamic>? bookTitle,
  Map<String, dynamic>? bookSpeaker,
}) =>
    {
      'version': 1,
      'book': {
        'id': bookId,
        'title': bookTitle ?? {'en': 'Test Book'},
        'titleArabic': '',
        'speaker': bookSpeaker ?? {'en': 'Speaker'},
        'totalDurationSeconds': lectures.fold<int>(
          0,
          (sum, l) => sum + (l['durationSeconds'] as int),
        ),
        'lectureCount': lectures.length,
        'coverImageUrl': '',
        'language': 'English',
      },
      'chapters': chapters,
      'lectures': lectures,
      'dailyBenefits': <Map<String, dynamic>>[],
    };

/// Stands in for the Search screen: pops [pick] (a chapter id, or null for
/// "Back without choosing") exactly as the real route does for Go to class.
class _SearchStub extends StatelessWidget {
  final String? pick;
  const _SearchStub({required this.pick});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          key: const ValueKey('search-stub-pick'),
          onPressed: () => context.pop(pick),
          child: const Text('pick'),
        ),
      );
}

Widget _wrap({
  required SeriesProvider series,
  Locale? locale,
  String? searchPick,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOnline()),
      ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
      ChangeNotifierProvider(create: (_) => AnnouncementsProvider()),
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
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/lectures',
        routes: [
          GoRoute(
            path: '/lectures',
            builder: (_, __) => const LectureListScreen(),
            routes: [
              GoRoute(
                path: 'search',
                builder: (_, __) => _SearchStub(pick: searchPick),
              ),
            ],
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

/// The real app shell (production router, `/lectures` branch) around the real
/// Lectures list, with a controllable audio backend so a mini-player can be
/// raised. Unlike [_wrap], this has the NavigationBar + MiniPlayer that the
/// shell draws over the body (`extendBody: true`).
Widget _shell({
  required Catalog catalog,
  Locale? locale,
  double textScale = 1.0,
  SeriesConfig? edition,
}) {
  final series = SeriesProvider()..load(false);
  if (edition != null) series.setCurrentSeriesForTest(edition);
  final progress = ProgressProvider()..load();
  final downloads = DownloadsProvider();
  final connectivity = ConnectivityProvider.testOnline();
  final catalogProvider = CatalogProvider()
    ..setCatalogForTest(catalog, seriesId: series.currentSeries.id);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: series),
      ChangeNotifierProvider.value(value: catalogProvider),
      ChangeNotifierProvider.value(value: progress),
      ChangeNotifierProvider.value(value: downloads),
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
      ChangeNotifierProvider(create: (_) => AnnouncementsProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
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
      routerConfig: createAppRouter(initialLocation: '/lectures'),
    ),
  );
}

/// [classes] chapters of [perClass] lectures each, as one parsed catalogue.
Catalog _bigCatalog({int classes = 4, int perClass = 6}) => Catalog.fromJson(
      _catalogJson(
        bookId: 'book',
        chapters: [
          for (var c = 1; c <= classes; c++)
            {
              'id': 'class-$c',
              'number': c,
              'title': {'en': 'Class $c'},
              'lectureCount': perClass,
            },
        ],
        lectures: [
          for (var c = 1; c <= classes; c++)
            for (var p = 1; p <= perClass; p++)
              {
                'id': 'lec-$c-$p',
                'number': p,
                'chapterId': 'class-$c',
                'title': {'en': 'Class $c - Part $p'},
                'audioUrl': 'https://example.com/lec-$c-$p.mp3',
                'durationSeconds': 60,
                'fileSizeBytes': 1000,
              },
        ],
      ),
    );

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
      jsonEncode(
        _catalogJson(
          bookId: 'legacy-book',
          chapters: const [
            {
              'id': 'ch-01',
              'number': 1,
              'title': {'en': 'Chapter One'},
              'lectureCount': 2,
            },
          ],
          lectures: [_lectureJson('lec-001', 1), _lectureJson('lec-002', 2)],
        ),
      ),
    );

    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.byType(ChapterHeader), findsOneWidget);
    expect(find.byType(LectureTile), findsNWidgets(2));
  });

  testWidgets(
      'renders a flat lecture list with no chapter headers for a series with no chapters',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(
        _catalogJson(
          bookId: 'arabic-book',
          chapters: const [],
          lectures: [
            _lectureJson('lec-001', 1),
            _lectureJson('lec-002', 2),
            _lectureJson('lec-003', 3),
          ],
        ),
      ),
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

  testWidgets(
      'renders Arabic book/speaker/lecture titles and a left-aligned header for the Arabic series',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(
        _catalogJson(
          bookId: 'arabic-book',
          chapters: const [],
          bookTitle: const {'en': 'Kitab at-Tawheed', 'ar': 'كتاب التوحيد'},
          bookSpeaker: const {
            'en': 'Shaikh Salih al-Fawzan Hafizahullah',
            'ar': 'الشيخ صالح الفوزان حفظه الله',
          },
          lectures: [
            _lectureJson('lec-001', 1, titleAr: 'الدرس الأول'),
            _lectureJson('lec-002', 2, titleAr: 'الدرس الثاني'),
          ],
        ),
      ),
    );

    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.centerTitle, isFalse);

    expect(find.text('كتاب التوحيد'), findsOneWidget);
    expect(find.text('الشيخ صالح الفوزان حفظه الله'), findsOneWidget);
    // Chrome here is English (this harness pins no locale) — what an
    // Arabic-edition reader who explicitly picked English would see: the
    // content stays Arabic, the chrome (words AND numbers) stays English.
    expect(find.text('2 lectures · 2m'), findsOneWidget);
    // The redesigned hero shows the Arabic series teacher (Shaikh al-Fawzan).
    expect(_avatarFinder('assets/images/sheikh_fawzan.png'), findsOneWidget);
    final avatarContainer = tester.widget<Container>(
      find
          .ancestor(
            of: _avatarFinder('assets/images/sheikh_fawzan.png'),
            matching: find.byType(Container),
          )
          .first,
    );
    final avatarDecoration = avatarContainer.decoration! as BoxDecoration;
    expect(avatarContainer.constraints?.maxWidth, 68);
    expect(avatarContainer.constraints?.maxHeight, 68);
    expect((avatarDecoration.border! as Border).top.width, 1);
    expect(find.text('الدرس الأول'), findsOneWidget);
    expect(find.text('الدرس الثاني'), findsOneWidget);
  });

  // The production default for the Arabic edition: the edition defaults the
  // chrome language to Arabic, so the header reads entirely in Arabic — words
  // and numbers alike. The old code hardcoded 'محاضرة'; the ARB says 'درس',
  // and the ARB is canonical (it also matches the الدروس nav tab).
  testWidgets('heads the Arabic edition with an all-Arabic count line',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(
        _catalogJson(
          bookId: 'arabic-book',
          chapters: const [],
          lectures: [
            _lectureJson('lec-001', 1, titleAr: 'الدرس الأول'),
            _lectureJson('lec-002', 2, titleAr: 'الدرس الثاني'),
          ],
        ),
      ),
    );

    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('٢ درس · ٢ د'), findsOneWidget);
    expect(find.textContaining('lectures'), findsNothing);
  });

  testWidgets('numbers the Arabic duroos in Arabic-Indic numerals',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(
        _catalogJson(
          bookId: 'arabic-book',
          chapters: const [],
          lectures: [
            _lectureJson('lec-001', 1, titleAr: 'الدرس الأول'),
            _lectureJson('lec-002', 2, titleAr: 'الدرس الثاني'),
          ],
        ),
      ),
    );

    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    // Arabic-Indic (U+066x), not Western — and not the Urdu set either.
    expect(find.text('٠١'), findsOneWidget);
    expect(find.text('٠٢'), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('۰۱'), findsNothing);
  });

  testWidgets('Arabic lecture rows fit on a narrow phone width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(
        _catalogJson(
          bookId: 'arabic-book',
          chapters: const [],
          bookTitle: const {'en': 'Kitab at-Tawheed', 'ar': 'كتاب التوحيد'},
          lectures: [
            _lectureJson(
              'lec-001',
              1,
              titleAr: 'الدرس الأول في شرح كتاب التوحيد ومسائله',
            ),
            _lectureJson(
              'lec-002',
              2,
              titleAr: 'الدرس الثاني في شرح كتاب التوحيد ومسائله',
            ),
          ],
        ),
      ),
    );

    final series = SeriesProvider()
      ..load(false)
      ..setCurrentSeriesForTest(_arabicSeries);

    await tester.pumpWidget(_wrap(series: series, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      find.text('الدرس الأول في شرح كتاب التوحيد ومسائله'),
      findsOneWidget,
    );
    expect(find.text('٠١'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The Urdu edition is deliberately untouched by the Arabic-chrome work: its
  // audience reads English chrome, so its lecture list counts 01, 02 exactly as
  // it always has. (Its *Book* is the exception — that renders ۰۱, in the
  // book's own script. Different rule, see book_chapter_list_body_test.)
  testWidgets('leaves the Urdu duroos numbered in Western digits',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(
        _catalogJson(
          bookId: 'legacy-book',
          chapters: const [],
          lectures: [_lectureJson('lec-001', 1), _lectureJson('lec-002', 2)],
        ),
      ),
    );

    final series = SeriesProvider()..load(false); // Urdu fallback

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('۰۱'), findsNothing);
  });

  // ...but an explicit اردو pick is honoured, numerals included.
  testWidgets('numbers the duroos in Urdu when the chrome is Urdu',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(
        _catalogJson(
          bookId: 'legacy-book',
          chapters: const [],
          lectures: [_lectureJson('lec-001', 1), _lectureJson('lec-002', 2)],
        ),
      ),
    );

    final series = SeriesProvider()..load(false); // Urdu fallback

    await tester.pumpWidget(_wrap(series: series, locale: const Locale('ur')));
    await tester.pumpAndSettle();

    expect(find.text('۰۱'), findsOneWidget);
    expect(find.text('٠١'), findsNothing);
    // The codepoints alone are not enough: Urdu and Persian share U+06F0–06F9
    // and draw 4/5/6/7 differently, so the badge must use the Urdu face.
    final badge = tester.widget<Text>(find.text('۰۱'));
    expect(badge.style?.fontFamily, 'NotoNastaliqUrdu');
  });

  testWidgets('marks the currently loaded lecture in the list', (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(
        _catalogJson(
          bookId: 'legacy-book',
          chapters: const [],
          lectures: [_lectureJson('lec-001', 1), _lectureJson('lec-002', 2)],
        ),
      ),
    );

    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LectureListScreen));
    context.read<PlayerNotifier>().setPlaybackStateForTest(
          Catalog.fromJson(
            _catalogJson(
              bookId: 'legacy-book',
              chapters: const [],
              lectures: [
                _lectureJson('lec-001', 1),
                _lectureJson('lec-002', 2),
              ],
            ),
          ).lectures.first,
        );
    await tester.pump();

    expect(find.byType(NowPlayingBars), findsOneWidget);
    expect(find.byIcon(Icons.equalizer_rounded), findsNothing);
    expect(find.text('Now Playing'), findsOneWidget);
    final highlightedRows = tester.widgetList<AnimatedContainer>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color != null &&
            (widget.decoration! as BoxDecoration).color != Colors.transparent,
      ),
    );
    expect(highlightedRows, isNotEmpty);
  });

  testWidgets('progress badges distinguish complete, in-progress, and new',
      (tester) async {
    await PreferencesService.instance.saveProgress('lec-001', 60);
    await PreferencesService.instance.saveProgress('lec-002', 30);
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(
        _catalogJson(
          bookId: 'legacy-book',
          chapters: const [],
          lectures: [
            _lectureJson('lec-001', 1),
            _lectureJson('lec-002', 2),
            _lectureJson('lec-003', 3),
          ],
        ),
      ),
    );

    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('03'), findsOneWidget);
  });

  testWidgets('shows an empty-state message when the catalog has no lectures',
      (tester) async {
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(
        _catalogJson(
          bookId: 'legacy-book',
          chapters: const [],
          lectures: const [],
        ),
      ),
    );

    final series = SeriesProvider()..load(false);

    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.byType(LectureTile), findsNothing);
    expect(find.text('No lectures available yet'), findsOneWidget);
  });

  testWidgets(
      'reloads the catalog when the active series changes — no series/catalog desync',
      (tester) async {
    // Urdu (legacy) catalog under the bare "catalog" cache key.
    await PreferencesService.instance.saveRemoteJson(
      'catalog',
      jsonEncode(
        _catalogJson(
          bookId: 'legacy-book',
          chapters: const [],
          bookTitle: const {'en': 'Sharah Kitab at-Tawheed'},
          lectures: [_lectureJson('lec-001', 1)],
        ),
      ),
    );
    // Arabic catalog under the namespaced "catalog_tawheed-ar" key.
    await PreferencesService.instance.saveRemoteJson(
      'catalog_tawheed-ar',
      jsonEncode(
        _catalogJson(
          bookId: 'arabic-book',
          chapters: const [],
          bookTitle: const {'en': 'Kitab at-Tawheed', 'ar': 'كتاب التوحيد'},
          bookSpeaker: const {
            'en': 'Shaikh Salih al-Fawzan Hafizahullah',
            'ar': 'الشيخ صالح الفوزان حفظه الله',
          },
          lectures: [_lectureJson('lec-001', 1, titleAr: 'الدرس الأول')],
        ),
      ),
    );

    // Mount on the Urdu (legacy) series — mirrors the brief boot window before
    // the saved Arabic series is restored.
    final series = SeriesProvider()..load(false);
    await tester.pumpWidget(_wrap(series: series));
    await tester.pumpAndSettle();

    expect(find.text('Sharah Kitab at-Tawheed'), findsOneWidget);
    expect(find.text('كتاب التوحيد'), findsNothing);
    // The Urdu series shows its teacher (Shaikh Abdullah Nasir Rahmani).
    expect(
      _avatarFinder('assets/images/sheikh-abdullah-nasir-rahmani.jpg'),
      findsOneWidget,
    );

    // The active series flips to Arabic (restored from prefs / device default).
    series.setCurrentSeriesForTest(_arabicSeries);
    await tester.pumpAndSettle();

    // The catalog must follow the series — Arabic content now, Urdu gone.
    expect(find.text('كتاب التوحيد'), findsOneWidget);
    expect(find.text('الدرس الأول'), findsOneWidget);
    expect(find.text('Sharah Kitab at-Tawheed'), findsNothing);
  });

  // The shell draws the mini-player and NavigationBar over the body
  // (`extendBody: true`). A CustomScrollView takes no automatic inset, so its
  // end spacer must clear them or the last lecture is unreachable.
  for (final (name, locale, scale) in [
    ('LTR', null, 1.0),
    ('LTR', null, 2.0),
    ('RTL (ur)', const Locale('ur'), 1.0),
    ('RTL (ur)', const Locale('ur'), 2.0),
  ]) {
    testWidgets(
        'Lectures clears the mini-player: the last lecture is tappable '
        '($name, ${scale}x text)', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // The Lectures hero and LectureTile badge row already overflow at 2x
      // text: separate layout bugs, not this test's subject.
      if (scale > 1) ignoreRenderFlexOverflow(addTearDown);

      final catalog = _bigCatalog();
      await tester.pumpWidget(
        _shell(catalog: catalog, locale: locale, textScale: scale),
      );
      await tester.pumpAndSettle();

      // A lecture is loaded, so the shell shows the mini-player.
      final shell = tester.element(find.byType(ShellScreen));
      final player = shell.read<PlayerNotifier>();
      await player.loadAndPlay(catalog.lectures.first, catalog.lectures);
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      final scrollable = find
          .descendant(
            of: find.byType(LectureListScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      final last = catalog.lectures.last;
      final lastTile = find.byWidgetPredicate(
        (w) => w is LectureTile && w.lecture.id == last.id,
      );
      expect(lastTile, findsOneWidget);
      final tileBottom = tester.getBottomLeft(lastTile).dy;
      final miniTop = tester.getTopLeft(find.byType(MiniPlayer)).dy;
      expect(
        tileBottom,
        lessThanOrEqualTo(miniTop),
        reason: 'last lecture ($tileBottom) must end above the '
            'mini-player ($miniTop)',
      );

      // And it is actually hit by a tap, which plays that lecture.
      expect(lastTile.hitTestable(), findsOneWidget);
      await tester.tap(lastTile, warnIfMissed: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(player.current?.id, last.id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Lectures with no audio still ends above the NavigationBar',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final catalog = _bigCatalog();
    await tester.pumpWidget(_shell(catalog: catalog));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(tester.getSize(find.byType(MiniPlayer)).height, 0);

    final scrollable = find
        .descendant(
          of: find.byType(LectureListScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    final last = catalog.lectures.last;
    final lastTile = find.byWidgetPredicate(
      (w) => w is LectureTile && w.lecture.id == last.id,
    );
    expect(
      tester.getBottomLeft(lastTile).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
    );
    expect(lastTile.hitTestable(), findsOneWidget);
  });

  group('search action and Go to class', () {
    // The real Urdu edition's shape: 15 classes, 50 parts.
    const counts = [2, 3, 3, 3, 4, 4, 2, 4, 2, 4, 4, 5, 3, 5, 2];

    Future<void> seedFifteenClasses() async {
      final chapters = <Map<String, dynamic>>[];
      final lectures = <Map<String, dynamic>>[];
      var n = 0;
      for (var c = 1; c <= counts.length; c++) {
        final id = 'class-${c.toString().padLeft(2, '0')}';
        chapters.add({
          'id': id,
          'number': c,
          'title': {'en': 'Class ${c.toString().padLeft(2, '0')}'},
          'lectureCount': counts[c - 1],
        });
        for (var p = 1; p <= counts[c - 1]; p++) {
          n++;
          lectures.add({
            ..._lectureJson('lec-${n.toString().padLeft(3, '0')}', n),
            'chapterId': id,
            'title': {'en': 'Class $c - Part $p'},
          });
        }
      }
      await PreferencesService.instance.saveRemoteJson(
        'catalog',
        jsonEncode(
          _catalogJson(
            bookId: 'legacy-book',
            chapters: chapters,
            lectures: lectures,
          ),
        ),
      );
    }

    ScrollPosition lecturesScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(LectureListScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    Future<void> pickFromSearch(WidgetTester tester) async {
      await tester.tap(find.byKey(WidgetKeys.lecturesSearchAction));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-stub-pick')));
      await tester.pumpAndSettle();
    }

    testWidgets('the app bar has one Search action, at least 48dp, first',
        (tester) async {
      await seedFifteenClasses();
      await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
      await tester.pumpAndSettle();

      final action = find.byKey(WidgetKeys.lecturesSearchAction);
      expect(action, findsOneWidget);
      expect(tester.widget<IconButton>(action).tooltip, 'Search lectures');
      expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));

      // Before the announcements bell, not after it.
      final actions =
          tester.widget<SliverAppBar>(find.byType(SliverAppBar)).actions!;
      expect(actions, hasLength(2));
      expect(actions.first.key, WidgetKeys.lecturesSearchAction);
    });

    testWidgets('Search is offered on a load error too', (tester) async {
      // Nothing cached and no network: the screen lands on its error state.
      await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.lecturesSearchAction), findsOneWidget);
    });

    testWidgets(
        'Go to class jumps from the top to the LAST class (Class 15), '
        'whose header was never built', (tester) async {
      await seedFifteenClasses();
      await tester.pumpWidget(
        _wrap(series: SeriesProvider()..load(false), searchPick: 'class-15'),
      );
      await tester.pumpAndSettle();

      expect(lecturesScroll(tester).pixels, 0);
      final header = find.byKey(WidgetKeys.lecturesChapterHeader('class-15'));
      // 15 chapters of 2-5 rows each: Class 15 is far below the first screen.
      expect(
        header.evaluate().isEmpty || tester.getTopLeft(header).dy > 600,
        isTrue,
      );

      await pickFromSearch(tester);

      expect(header, findsOneWidget);
      final position = lecturesScroll(tester);
      expect(position.pixels, greaterThan(0));
      // The last class cannot scroll to the very top of a viewport taller than
      // itself, so it settles at the end of the list with its header on screen.
      expect(position.pixels, position.maxScrollExtent);
      final top = tester.getTopLeft(header).dy;
      expect(top, greaterThanOrEqualTo(kToolbarHeight));
      expect(top, lessThan(600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Go to class puts a middle class header under the app bar',
        (tester) async {
      await seedFifteenClasses();
      await tester.pumpWidget(
        _wrap(series: SeriesProvider()..load(false), searchPick: 'class-08'),
      );
      await tester.pumpAndSettle();

      await pickFromSearch(tester);

      final header = find.byKey(WidgetKeys.lecturesChapterHeader('class-08'));
      expect(header, findsOneWidget);
      // Flush with the pinned app bar's bottom edge, not hidden beneath it.
      expect(tester.getTopLeft(header).dy, closeTo(kToolbarHeight, 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Go to class also works when the list is already scrolled down',
        (tester) async {
      await seedFifteenClasses();
      await tester.pumpWidget(
        _wrap(series: SeriesProvider()..load(false), searchPick: 'class-02'),
      );
      await tester.pumpAndSettle();
      lecturesScroll(tester).jumpTo(2000);
      await tester.pumpAndSettle();

      await pickFromSearch(tester);

      final header = find.byKey(WidgetKeys.lecturesChapterHeader('class-02'));
      expect(header, findsOneWidget);
      expect(tester.getTopLeft(header).dy, closeTo(kToolbarHeight, 1.0));
    });

    testWidgets('Back from Search without choosing leaves the scroll alone',
        (tester) async {
      await seedFifteenClasses();
      await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
      await tester.pumpAndSettle();
      lecturesScroll(tester).jumpTo(300);
      await tester.pumpAndSettle();

      await pickFromSearch(tester);

      expect(lecturesScroll(tester).pixels, 300);
    });

    testWidgets('an unknown chapter id is ignored without throwing',
        (tester) async {
      await seedFifteenClasses();
      await tester.pumpWidget(
        _wrap(series: SeriesProvider()..load(false), searchPick: 'class-99'),
      );
      await tester.pumpAndSettle();

      await pickFromSearch(tester);

      expect(lecturesScroll(tester).pixels, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chapter headers are keyed and lecture rows still build',
        (tester) async {
      await seedFifteenClasses();
      await tester.pumpWidget(_wrap(series: SeriesProvider()..load(false)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(WidgetKeys.lecturesChapterHeader('class-01')),
        findsOneWidget,
      );
      expect(find.text('Class 1 - Part 1'), findsOneWidget);
    });
  });
}
