import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/app.dart' show createAppRouter;
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
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
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/lecture_search_screen.dart';
import 'package:myapp/screens/library_screen.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_semantic_colors.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/widgets/mini_player.dart';

import 'support/fake_audio_playback.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

const _arabicEdition = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

String _p2(int n) => n.toString().padLeft(2, '0');

/// ASCII digits -> Extended Arabic-Indic (۰-۹), as the Urdu catalogue writes.
String _urduDigits(String s) => s.replaceAllMapped(
      RegExp(r'\d'),
      (m) => String.fromCharCode(0x06F0 + int.parse(m[0]!)),
    );

/// The real Urdu edition's shape: 15 classes / 50 parts, lecture numbers global
/// 1..50 (Class 12 = lectures 36-40; lecture 12 = Class 05 - Part 01).
const _urduCounts = [2, 3, 3, 3, 4, 4, 2, 4, 2, 4, 4, 5, 3, 5, 2];

Book _book(int lectures) => Book(
      id: 'book',
      title: const {'en': 'Kitab at-Tawheed'},
      speaker: const {'en': 'Speaker'},
      totalDurationSeconds: lectures * 600,
      lectureCount: lectures,
      coverImageUrl: '',
      language: 'Urdu',
    );

Catalog _urduCatalog() {
  final chapters = <Chapter>[];
  final lectures = <Lecture>[];
  var n = 0;
  for (var c = 1; c <= _urduCounts.length; c++) {
    final id = 'class-${_p2(c)}';
    chapters.add(
      Chapter(
        id: id,
        number: c,
        title: {
          'en': 'Class ${_p2(c)}',
          // Class 03 alone has a word that exists only in its Urdu title.
          'ur': 'درس ${_urduDigits(_p2(c))}${c == 3 ? ' — ایمان' : ''}',
          'roman': 'Dars ${_p2(c)}',
        },
        lectureCount: _urduCounts[c - 1],
      ),
    );
    for (var p = 1; p <= _urduCounts[c - 1]; p++) {
      n++;
      lectures.add(
        Lecture(
          id: 'lec-${n.toString().padLeft(3, '0')}',
          number: n,
          chapterId: id,
          title: {
            'en': 'Class ${_p2(c)} — Part ${_p2(p)}',
            'ur': 'درس ${_urduDigits(_p2(c))} — حصہ ${_urduDigits(_p2(p))}',
            'roman': 'Dars ${_p2(c)} — Hissa ${_p2(p)}',
          },
          audioUrl: 'https://example.com/$n.mp3',
          durationSeconds: 600,
          fileSizeBytes: 1000,
        ),
      );
    }
  }
  return Catalog(
    version: 1,
    book: _book(n),
    chapters: chapters,
    lectures: lectures,
    dailyBenefits: const [],
  );
}

/// Arabic edition: no chapters, `chapterId` empty, titles {ar, en}.
Catalog _arabicCatalog() {
  const rows = <int, String>{
    1: 'الدرس الأول',
    2: 'الدرس الثاني',
    3: 'الدرس الثالث',
    4: 'الدرس الرابع',
    11: 'الدرس الحادي عشر',
    12: 'الدرس الثاني عشر',
    13: 'الدرس الثالث عشر',
    20: 'الدرس العشرون',
    21: 'الدرس الحادي والعشرون',
    23: 'الدرس الثالث والعشرون',
    30: 'الدرس الثلاثون',
    33: 'الدرس الثالث والثلاثون',
    43: 'الدرس الثالث والأربعون',
    53: 'الدرس الثالث والخمسون',
    63: 'الدرس الثالث والستون',
    73: 'الدرس الثالث والسبعون',
    83: 'الدرس الثالث والثمانون',
    91: 'الدرس الحادي والتسعون',
  };
  return Catalog(
    version: 1,
    book: _book(rows.length),
    chapters: const [],
    lectures: [
      for (final e in rows.entries)
        Lecture(
          id: 'lec-${e.key.toString().padLeft(3, '0')}',
          number: e.key,
          chapterId: '',
          title: {'ar': e.value, 'en': 'Dars ${_p2(e.key)}'},
          audioUrl: 'https://example.com/${e.key}.mp3',
          durationSeconds: 600,
          fileSizeBytes: 1000,
        ),
    ],
    dailyBenefits: const [],
  );
}

/// A [CatalogProvider] whose state the test dictates, so the unavailable /
/// loading / error branches can be reached without a network.
class _StubCatalog extends CatalogProvider {
  _StubCatalog({
    this.stubStatus = CatalogStatus.loaded,
    Catalog? catalog,
    this.stubNeedsOnline = false,
    this.stubError,
  }) : _stubCatalog = catalog;

  CatalogStatus stubStatus;
  final Catalog? _stubCatalog;
  final bool stubNeedsOnline;
  final String? stubError;
  String? stubSeriesId;
  int loads = 0;

  @override
  CatalogStatus get status => stubStatus;
  @override
  Catalog? get catalog => _stubCatalog;
  @override
  bool get needsOnlineToLoad => stubNeedsOnline;
  @override
  String? get error => stubError;
  @override
  bool get isLoading => stubStatus == CatalogStatus.loading;
  @override
  String? get loadedSeriesId => stubSeriesId;

  @override
  Future<void> load([SeriesConfig? series]) async {
    loads++;
  }
}

/// A chrome language under test and how to talk about it.
class _Loc {
  const _Loc(this.name, this.language, this.locale, this.digits);
  final String name;
  final AppLanguage language;
  final Locale locale;

  /// The numeral script the chrome renders (`roman` Urdu uses Western digits).
  final String digits;

  AppLocalizations get l10n => lookupAppLocalizations(locale);
  String d(String s) => localizedDigitsInString(s, digits);
  bool get rtl => name == 'ar' || name == 'ur';
}

const _en = _Loc('en', AppLanguage.english, Locale('en'), 'en');
const _ar = _Loc('ar', AppLanguage.arabic, Locale('ar'), 'ar');
const _ur = _Loc('ur', AppLanguage.urdu, Locale('ur'), 'ur');
const _roman = _Loc(
  'ur_roman',
  AppLanguage.romanUrdu,
  Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
  'en',
);
const _allLocales = [_en, _ar, _ur, _roman];

class _App {
  _App(this.playback, this.player, this.progress, this.catalog);
  final FakeAudioPlayback playback;
  final PlayerNotifier player;
  final ProgressProvider progress;
  final _StubCatalog catalog;
}

Future<_App> _pumpApp(
  WidgetTester tester, {
  required _StubCatalog catalog,
  _Loc locale = _en,
  SeriesConfig? edition,
  String initialLocation = '/lectures',
  TextScaler? textScaler,
  bool dark = false,
  Size size = const Size(390, 844),
  ProgressProvider? progress,
  ConnectivityProvider? connectivity,
  bool downloadsEnabled = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final series = SeriesProvider()..load(false);
  if (edition != null) series.setCurrentSeriesForTest(edition);
  catalog.stubSeriesId = series.currentSeries.id;

  final lang = LanguageProvider()..load();
  lang.applyLanguageFeatureFlag(true);
  lang.applySeriesDefault(series.currentSeries);
  await lang.setLanguage(locale.language);

  final prog = progress ?? (ProgressProvider()..load());
  final conn = connectivity ?? ConnectivityProvider.testOnline();
  final downloads = DownloadsProvider();
  final playback = FakeAudioPlayback();
  final player = PlayerNotifier(playback, prog, downloads, conn);
  addTearDown(player.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: series),
        ChangeNotifierProvider(
          create: (_) => FeatureFlagsProvider()
            ..setFeaturesJsonForTest({'downloads': downloadsEnabled}),
        ),
        ChangeNotifierProvider.value(value: conn),
        ChangeNotifierProvider.value(value: prog),
        ChangeNotifierProvider.value(value: downloads),
        ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ChangeNotifierProvider(create: (_) => AnnouncementsProvider()),
        ChangeNotifierProvider.value(value: lang),
        ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
        ChangeNotifierProvider.value(value: player),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: lang.locale,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return Directionality(
            textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: media.copyWith(textScaler: textScaler ?? media.textScaler),
              child: child!,
            ),
          );
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: createAppRouter(initialLocation: initialLocation),
      ),
    ),
  );
  // Never pumpAndSettle here: the loading state spins forever.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  return _App(playback, player, prog, catalog);
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const _debounce = Duration(milliseconds: 200);

Finder get _field => find.byKey(WidgetKeys.searchField);

/// Types [text] and waits out the debounce.
Future<void> _type(
  WidgetTester tester,
  String text, {
  bool settle = true,
}) async {
  await tester.enterText(_field, text);
  await tester.pump(_debounce);
  // A loading state spins forever: pumpAndSettle would never return.
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

/// Lets a pushed route finish its transition without settling (the Player
/// shows a spinner while the fake backend "loads").
Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(ShellScreen)));

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.last.matchedLocation;

/// All text painted under [within], in order.
String _plain(WidgetTester tester, Finder within) => tester
    .widgetList<RichText>(
      find.descendant(of: within, matching: find.byType(RichText)),
    )
    .map((r) => r.text.toPlainText())
    .join('|');

/// The RichText under [within] whose text contains [text] (the title; an
/// icon is a RichText too).
RichText _richContaining(WidgetTester tester, Finder within, String text) =>
    tester
        .widgetList<RichText>(
          find.descendant(of: within, matching: find.byType(RichText)),
        )
        .firstWhere((r) => r.text.toPlainText().contains(text));

/// The highlighted fragments under [within]: bold + underlined spans.
List<String> _highlighted(WidgetTester tester, Finder within) {
  final out = <String>[];
  for (final rt in tester.widgetList<RichText>(
    find.descendant(of: within, matching: find.byType(RichText)),
  )) {
    rt.text.visitChildren((span) {
      if (span is TextSpan &&
          span.text != null &&
          span.style?.fontWeight == FontWeight.w700 &&
          span.style?.decoration == TextDecoration.underline) {
        out.add(span.text!);
      }
      return true;
    });
  }
  return out;
}

Finder _row(String lectureId) =>
    find.byKey(WidgetKeys.searchLectureRow(lectureId));

Finder _classRow(String chapterId) =>
    find.byKey(WidgetKeys.searchClassRow(chapterId));

ScrollPosition _scroll(WidgetTester tester, Finder within) => tester
    .state<ScrollableState>(
      find.descendant(of: within, matching: find.byType(Scrollable)).first,
    )
    .position;

void _expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  // ── Entry point and route ────────────────────────────────────────────────

  group('entry', () {
    testWidgets(
        'the Search action opens /lectures/search INSIDE the Lectures branch: '
        'bottom nav stays, field is focused, Back returns', (tester) async {
      await _pumpApp(tester, catalog: _StubCatalog(catalog: _urduCatalog()));
      expect(find.byType(LectureSearchScreen), findsNothing);

      await tester.tap(find.byKey(WidgetKeys.lecturesSearchAction));
      await tester.pumpAndSettle();

      expect(find.byType(LectureSearchScreen), findsOneWidget);
      expect(_location(tester), '/lectures/search');
      // Still the shell: the bottom nav (and its Lectures tab) is on screen.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(WidgetKeys.shellLecturesTab), findsOneWidget);
      // Autofocused field.
      final editable = tester.widget<EditableText>(
        find.descendant(of: _field, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);

      await tester.tap(find.byKey(WidgetKeys.searchBack));
      await tester.pumpAndSettle();
      expect(find.byType(LectureSearchScreen), findsNothing);
      expect(find.byType(LectureListScreen), findsOneWidget);
      expect(_location(tester), '/lectures');
    });

    testWidgets('system Back also returns to Lectures', (tester) async {
      await _pumpApp(tester, catalog: _StubCatalog(catalog: _urduCatalog()));
      await tester.tap(find.byKey(WidgetKeys.lecturesSearchAction));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(LectureSearchScreen), findsNothing);
      expect(find.byType(LectureListScreen), findsOneWidget);
    });
  });

  // ── Idle ─────────────────────────────────────────────────────────────────

  group('idle', () {
    for (final loc in _allLocales) {
      testWidgets('Urdu edition: chips and a 15-cell class grid (${loc.name})',
          (tester) async {
        await _pumpApp(
          tester,
          catalog: _StubCatalog(catalog: _urduCatalog()),
          locale: loc,
          initialLocation: '/lectures/search',
        );

        expect(find.byKey(WidgetKeys.searchIdle), findsOneWidget);
        for (final chip in ['12', 'Part 03', 'Hissa 2', 'درس ۰۵']) {
          expect(find.byKey(WidgetKeys.searchChip(chip)), findsOneWidget);
        }
        expect(find.byKey(WidgetKeys.searchClassGrid), findsOneWidget);
        for (var c = 1; c <= 15; c++) {
          expect(
            find.byKey(WidgetKeys.searchClassCell('class-${_p2(c)}')),
            findsOneWidget,
          );
        }
        // "15 classes · 50 parts" and the legend.
        final l = loc.l10n;
        expect(
          find.text(loc.d('${l.searchClassesCount(15)} · ${l.partsCount(50)}')),
          findsOneWidget,
        );
        expect(find.text(l.searchLegendFinished), findsOneWidget);
        expect(find.text(l.searchLegendContinue), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchClear), findsNothing);
        _expectNoOverflow(tester);
      });
    }

    testWidgets('Arabic edition: chips and a hint only — no grid, no classes',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _arabicCatalog()),
        edition: _arabicEdition,
        locale: _ar,
        initialLocation: '/lectures/search',
      );

      expect(find.byKey(WidgetKeys.searchIdle), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchChip('3')), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchChip('الثالث')), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchChip('12')), findsNothing);
      expect(find.byKey(WidgetKeys.searchClassGrid), findsNothing);
      expect(find.text(_ar.l10n.searchIdleHint), findsOneWidget);
      _expectNoOverflow(tester);
    });

    testWidgets('tapping a chip fills the field and searches', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );

      await tester.tap(find.byKey(WidgetKeys.searchChip('Hissa 2')));
      await tester.pumpAndSettle();

      expect(_fieldText(tester), 'Hissa 2');
      expect(find.byKey(WidgetKeys.searchResults), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchIdle), findsNothing);
    });

    testWidgets('the Urdu chip fills the field with Urdu script',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        locale: _ur,
        initialLocation: '/lectures/search',
      );

      await tester.tap(find.byKey(WidgetKeys.searchChip('درس ۰۵')));
      await tester.pumpAndSettle();

      expect(_fieldText(tester), 'درس ۰۵');
      expect(_classRow('class-05'), findsOneWidget);
    });

    testWidgets('chips and grid cells are at least 48dp', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );

      for (final chip in ['12', 'Part 03', 'Hissa 2', 'درس ۰۵']) {
        final size = tester.getSize(find.byKey(WidgetKeys.searchChip(chip)));
        expect(size.height, greaterThanOrEqualTo(48), reason: chip);
        expect(size.width, greaterThanOrEqualTo(48), reason: chip);
      }
      final cell = tester.getSize(
        find.byKey(WidgetKeys.searchClassCell('class-01')),
      );
      expect(cell.height, greaterThanOrEqualTo(48));
      expect(cell.width, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.byKey(WidgetKeys.searchBack)).shortestSide,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(_field).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  // ── Results ──────────────────────────────────────────────────────────────

  group('results', () {
    for (final loc in _allLocales) {
      testWidgets(
          '"12" -> 7 rows: Class 12, its 5 parts, and Lecture 12 '
          '(${loc.name})', (tester) async {
        await _pumpApp(
          tester,
          catalog: _StubCatalog(catalog: _urduCatalog()),
          locale: loc,
          initialLocation: '/lectures/search',
        );
        await _type(tester, '12');

        expect(find.byKey(WidgetKeys.searchResults), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchSectionClasses), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchSectionLectures), findsOneWidget);
        expect(
          find.text(loc.d(loc.l10n.searchResultsCount(7))),
          findsOneWidget,
        );
        expect(_classRow('class-12'), findsOneWidget);
        for (final n in [36, 37, 38, 39, 40, 12]) {
          expect(_row('lec-0$n'), findsOneWidget, reason: 'lecture $n');
        }
        expect(
          find.byWidgetPredicate(
            (w) => w.key.toString().contains('search.lecture-row.'),
          ),
          findsNWidgets(6),
        );
        // Classes before Lectures.
        expect(
          tester.getTopLeft(find.byKey(WidgetKeys.searchSectionClasses)).dy,
          lessThan(
            tester.getTopLeft(find.byKey(WidgetKeys.searchSectionLectures)).dy,
          ),
        );
        // Only the number-only hit says "Lecture 12".
        final lectureWord = loc.d(loc.l10n.searchLectureNumber('12'));
        expect(_plain(tester, _row('lec-012')), contains(lectureWord));
        // (In Urdu and Roman Urdu "Lecture 12" is spelled like the class
        // title itself, so the absence check only reads in en and ar.)
        if (loc == _en || loc == _ar) {
          expect(
            _plain(tester, _row('lec-036')),
            isNot(contains(lectureWord)),
          );
        }
        _expectNoOverflow(tester);
      });
    }

    testWidgets('the result count is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      final node =
          tester.getSemantics(find.byKey(WidgetKeys.searchResultCount));
      // ignore: deprecated_member_use
      expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      expect(node.label, '7 results');
      handle.dispose();
    });

    testWidgets('a single hit reads "1 result"', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'class 02 part 3');

      expect(find.text('1 result'), findsOneWidget);
    });

    testWidgets('Arabic edition: no Classes section, Lectures only',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _arabicCatalog()),
        edition: _arabicEdition,
        locale: _ar,
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'الثالث');

      expect(find.byKey(WidgetKeys.searchSectionClasses), findsNothing);
      expect(find.byKey(WidgetKeys.searchSectionLectures), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchClassGrid), findsNothing);
      // 3, 13, 23, 33, 43, 53 are on screen; the rest are further down.
      for (final n in [3, 13, 23]) {
        expect(_row('lec-${n.toString().padLeft(3, '0')}'), findsOneWidget);
      }
      _expectNoOverflow(tester);
    });

    testWidgets('debounces typing: nothing searched before ~150ms',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );

      await tester.enterText(_field, '12');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(WidgetKeys.searchResults), findsNothing);
      expect(find.byKey(WidgetKeys.searchIdle), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.searchResults), findsOneWidget);
    });

    testWidgets('Clear empties the field and returns to the idle state',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      expect(find.byKey(WidgetKeys.searchClear), findsNothing);
      await _type(tester, '12');
      expect(find.byKey(WidgetKeys.searchClear), findsOneWidget);
      expect(
        tester.getSize(find.byKey(WidgetKeys.searchClear)).shortestSide,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.byKey(WidgetKeys.searchClear));
      await tester.pumpAndSettle();

      expect(_fieldText(tester), isEmpty);
      expect(find.byKey(WidgetKeys.searchIdle), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchResults), findsNothing);
      expect(find.byKey(WidgetKeys.searchClear), findsNothing);
    });
  });

  // ── Highlight ────────────────────────────────────────────────────────────

  group('highlight', () {
    testWidgets('highlights the whole token in the title the row shows',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      expect(_highlighted(tester, _classRow('class-12')), ['12']);
      expect(_plain(tester, _classRow('class-12')), contains('Class 12'));
      expect(_highlighted(tester, _row('lec-037')), ['12']);
      expect(_plain(tester, _row('lec-037')), contains('Class 12 — Part 02'));
    });

    testWidgets('Urdu chrome shows the Urdu title and highlights ۱۲',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        locale: _ur,
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      expect(_highlighted(tester, _classRow('class-12')), ['۱۲']);
      expect(_plain(tester, _classRow('class-12')), contains('درس ۱۲'));
      expect(_highlighted(tester, _row('lec-037')), ['۱۲']);
    });

    testWidgets('Roman Urdu chrome highlights in the roman title',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        locale: _roman,
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'hissa 2');

      expect(_plain(tester, _row('lec-002')), contains('Dars 01 — Hissa 02'));
      expect(_highlighted(tester, _row('lec-002')), ['Hissa', '02']);
    });

    testWidgets('Arabic edition highlights the ordinal token, not a fragment',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _arabicCatalog()),
        edition: _arabicEdition,
        locale: _ar,
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'الثالث');

      expect(_highlighted(tester, _row('lec-013')), ['الثالث']);
      expect(_plain(tester, _row('lec-013')), contains('الدرس الثالث عشر'));
    });

    testWidgets(
        'matched only through another language: plain title, no highlight, '
        'no "Lecture n" line', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      // English chrome shows "Class 03"; "ایمان" only occurs in its Urdu title.
      await _type(tester, 'ایمان');

      expect(find.text('1 result'), findsOneWidget);
      expect(_classRow('class-03'), findsOneWidget);
      expect(_plain(tester, _classRow('class-03')), contains('Class 03'));
      expect(_highlighted(tester, _classRow('class-03')), isEmpty);
    });

    testWidgets('number-only hit highlights the number in "Lecture 12"',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      expect(_plain(tester, _row('lec-012')), contains('Lecture 12'));
      expect(_highlighted(tester, _row('lec-012')), ['12']);
      // The title itself ("Class 05 — Part 01") carries no highlight.
      expect(_plain(tester, _row('lec-012')), contains('Class 05 — Part 01'));
    });

    testWidgets('highlight uses the brand-subtle background', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      final semantic =
          Theme.of(tester.element(find.byType(LectureSearchScreen)))
              .extension<AppSemanticColors>()!;
      Color? background;
      _richContaining(tester, _classRow('class-12'), 'Class 12')
          .text
          .visitChildren((span) {
        if (span is TextSpan && span.style?.fontWeight == FontWeight.w700) {
          background = span.style?.backgroundColor;
        }
        return true;
      });
      expect(background, semantic.brandSubtle);
    });
  });

  // ── No results ───────────────────────────────────────────────────────────

  group('no results', () {
    for (final loc in _allLocales) {
      testWidgets('distinct state with edition totals (${loc.name})',
          (tester) async {
        await _pumpApp(
          tester,
          catalog: _StubCatalog(catalog: _urduCatalog()),
          locale: loc,
          initialLocation: '/lectures/search',
        );
        await _type(tester, 'class 40');

        final l = loc.l10n;
        expect(find.byKey(WidgetKeys.searchNoResults), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchResults), findsNothing);
        expect(find.text(l.searchNoMatchesTitle('class 40')), findsOneWidget);
        expect(
          find.text(
            loc.d(
              l.searchNoMatchesBody(
                l.searchClassesCount(15),
                l.partsCount(50),
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(WidgetKeys.searchClearAction), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchBrowseClasses), findsOneWidget);
        expect(
          tester.getSize(find.byKey(WidgetKeys.searchClearAction)).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byKey(WidgetKeys.searchBrowseClasses)).height,
          greaterThanOrEqualTo(48),
        );
        _expectNoOverflow(tester);
      });
    }

    testWidgets('the message is announced: title and body are one live region',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'class 40');

      final node = tester.getSemantics(find.text('No matches for “class 40”'));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(node.label, contains('No matches for “class 40”'));
      expect(node.label, contains('This edition has 15 classes and 50 parts.'));
      handle.dispose();
    });

    testWidgets('English wording', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'class 40');

      expect(find.text('No matches for “class 40”'), findsOneWidget);
      expect(
        find.textContaining('This edition has 15 classes and 50 parts.'),
        findsOneWidget,
      );
    });

    testWidgets('chapterless edition: lecture total, no Browse classes',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _arabicCatalog()),
        edition: _arabicEdition,
        locale: _en,
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'zzz');

      expect(find.byKey(WidgetKeys.searchNoResults), findsOneWidget);
      expect(
        find.textContaining('This edition has 18 lectures.'),
        findsOneWidget,
      );
      expect(find.byKey(WidgetKeys.searchClearAction), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchBrowseClasses), findsNothing);
    });

    testWidgets('Clear search and Browse all classes both return to the grid',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'class 40');
      await tester.tap(find.byKey(WidgetKeys.searchClearAction));
      await tester.pumpAndSettle();
      expect(_fieldText(tester), isEmpty);
      expect(find.byKey(WidgetKeys.searchClassGrid), findsOneWidget);

      await _type(tester, 'class 40');
      await tester.tap(find.byKey(WidgetKeys.searchBrowseClasses));
      await tester.pumpAndSettle();
      expect(_fieldText(tester), isEmpty);
      expect(find.byKey(WidgetKeys.searchClassGrid), findsOneWidget);
    });
  });

  // ── Unavailable / error / loading ────────────────────────────────────────

  group('catalogue not available', () {
    for (final loc in _allLocales) {
      testWidgets(
          'offline with no cache: unavailable, never "no matches" '
          '(${loc.name})', (tester) async {
        final provider = _StubCatalog(
          stubStatus: CatalogStatus.error,
          stubNeedsOnline: true,
        );
        await _pumpApp(
          tester,
          catalog: provider,
          locale: loc,
          initialLocation: '/lectures/search',
        );
        final l = loc.l10n;

        expect(find.byKey(WidgetKeys.searchUnavailable), findsOneWidget);
        expect(find.text(l.searchUnavailableTitle), findsOneWidget);
        expect(find.text(l.searchUnavailableMessage), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchRetry), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchOpenDownloads), findsOneWidget);
        for (final key in [
          WidgetKeys.searchRetry,
          WidgetKeys.searchOpenDownloads,
        ]) {
          expect(
            tester.getSize(find.byKey(key)).height,
            greaterThanOrEqualTo(48),
          );
        }

        // Typing cannot turn it into a (false) "no matches".
        await _type(tester, 'zzz');
        expect(find.byKey(WidgetKeys.searchUnavailable), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchNoResults), findsNothing);
        expect(find.text(l.searchNoMatchesTitle('zzz')), findsNothing);
        _expectNoOverflow(tester);
      });
    }

    testWidgets('no catalogue and nothing loading is unavailable too',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(stubStatus: CatalogStatus.idle),
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'zzz');

      expect(find.byKey(WidgetKeys.searchUnavailable), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchNoResults), findsNothing);
    });

    testWidgets('Retry reloads the catalogue', (tester) async {
      final provider = _StubCatalog(
        stubStatus: CatalogStatus.error,
        stubNeedsOnline: true,
      );
      await _pumpApp(
        tester,
        catalog: provider,
        initialLocation: '/lectures/search',
      );
      final before = provider.loads;

      await tester.tap(find.byKey(WidgetKeys.searchRetry));
      await tester.pump();

      expect(provider.loads, before + 1);
    });

    testWidgets('"Open your downloads" goes to Library > Downloads',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(
          stubStatus: CatalogStatus.error,
          stubNeedsOnline: true,
        ),
        initialLocation: '/lectures/search',
      );

      await tester.tap(find.byKey(WidgetKeys.searchOpenDownloads));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
      // The Downloads tab (not Bookmarks) is the selected one.
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        1,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('with downloads switched off there is nothing to open',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(
          stubStatus: CatalogStatus.error,
          stubNeedsOnline: true,
        ),
        downloadsEnabled: false,
        initialLocation: '/lectures/search',
      );

      expect(find.byKey(WidgetKeys.searchUnavailable), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchOpenDownloads), findsNothing);
      expect(find.byKey(WidgetKeys.searchRetry), findsOneWidget);
    });

    for (final loc in _allLocales) {
      testWidgets('load error: error state with Retry (${loc.name})',
          (tester) async {
        final provider = _StubCatalog(
          stubStatus: CatalogStatus.error,
          stubError: 'HTTP 503 from the CDN',
        );
        await _pumpApp(
          tester,
          catalog: provider,
          locale: loc,
          initialLocation: '/lectures/search',
        );

        expect(find.byKey(WidgetKeys.searchError), findsOneWidget);
        expect(find.text(loc.l10n.couldNotLoadLectures), findsWidgets);
        expect(find.text('HTTP 503 from the CDN'), findsWidgets);
        expect(find.byKey(WidgetKeys.searchRetry), findsOneWidget);
        expect(find.byKey(WidgetKeys.searchUnavailable), findsNothing);
        _expectNoOverflow(tester);
      });
    }

    testWidgets('a stale catalogue behind a failed reload is not searched',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(
          stubStatus: CatalogStatus.error,
          catalog: _urduCatalog(),
          stubError: 'boom',
        ),
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      expect(find.byKey(WidgetKeys.searchError), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchResults), findsNothing);
      expect(find.byKey(WidgetKeys.searchNoResults), findsNothing);
    });

    testWidgets('loading shows a spinner, not "no matches"', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(stubStatus: CatalogStatus.loading),
        initialLocation: '/lectures/search',
      );
      await _type(tester, 'zzz', settle: false);

      expect(find.byKey(WidgetKeys.searchLoading), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchNoResults), findsNothing);
      expect(find.byKey(WidgetKeys.searchUnavailable), findsNothing);
    });

    testWidgets('typed-then-loaded: results appear once the catalogue lands',
        (tester) async {
      final provider = _StubCatalog(
        stubStatus: CatalogStatus.loading,
        catalog: _urduCatalog(),
      );
      await _pumpApp(
        tester,
        catalog: provider,
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12', settle: false);
      expect(find.byKey(WidgetKeys.searchLoading), findsOneWidget);

      provider.stubStatus = CatalogStatus.loaded;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      provider.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.searchResults), findsOneWidget);
      expect(find.text('7 results'), findsOneWidget);
    });

    testWidgets('Retry button text is dark on gold in light and dark themes',
        (tester) async {
      for (final dark in [false, true]) {
        await _pumpApp(
          tester,
          catalog: _StubCatalog(
            stubStatus: CatalogStatus.error,
            stubNeedsOnline: true,
          ),
          dark: dark,
          initialLocation: '/lectures/search',
        );
        final style = tester
            .widget<FilledButton>(find.byKey(WidgetKeys.searchRetry))
            .style!;
        final foreground = style.foregroundColor!.resolve({})!;
        final background = style.backgroundColor?.resolve({}) ??
            Theme.of(tester.element(find.byType(LectureSearchScreen)))
                .extension<AppSemanticColors>()!
                .brand;
        expect(
          foreground.computeLuminance(),
          lessThan(0.2),
          reason: 'dark=$dark',
        );
        expect(background.computeLuminance(), greaterThan(0.2));
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  // ── Playing and jumping ──────────────────────────────────────────────────

  group('navigation', () {
    testWidgets(
        'a Lecture hit plays it and opens Player; Back returns to the results '
        'with the query and scroll position intact', (tester) async {
      final app = await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _arabicCatalog()),
        edition: _arabicEdition,
        locale: _ar,
        initialLocation: '/lectures/search',
        size: const Size(360, 420),
      );
      await _type(tester, 'الدرس');
      final results = find.byKey(WidgetKeys.searchResults);
      expect(results, findsOneWidget);
      await tester.drag(results, const Offset(0, -250));
      await tester.pumpAndSettle();
      final scrolled = _scroll(tester, results).pixels;
      expect(scrolled, greaterThan(0));

      await tester.tap(_row('lec-012'));
      await _pumpRoute(tester);

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(app.playback.loads.last.lecture.id, 'lec-012');

      await tester.binding.handlePopRoute();
      await _pumpRoute(tester);

      expect(find.byType(PlayerScreen), findsNothing);
      expect(find.byType(LectureSearchScreen), findsOneWidget);
      expect(_fieldText(tester), 'الدرس');
      expect(_scroll(tester, results).pixels, scrolled);
      expect(_location(tester), '/lectures/search');
      // The fake backend never reports ready; stop the load watchdog.
      app.player.dispose();
    });

    testWidgets('a Lecture hit queues the whole catalogue like Lectures does',
        (tester) async {
      final app = await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      await tester.tap(_row('lec-012'));
      await _pumpRoute(tester);
      final player = Provider.of<PlayerNotifier>(
        tester.element(find.byType(PlayerScreen)),
        listen: false,
      );
      expect(player.current?.id, 'lec-012');

      // Lecture 13 is not a search hit: the queue is the catalogue, not the
      // result list.
      await player.playNext();
      expect(app.playback.loads.last.lecture.id, 'lec-013');
      app.player.dispose();
    });

    testWidgets('offline and not downloaded: snackbar, no Player',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        connectivity: ConnectivityProvider.testOffline(),
        initialLocation: '/lectures/search',
      );
      await _type(tester, '12');

      await tester.tap(_row('lec-037'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PlayerScreen), findsNothing);
      expect(
        find.text('Download this lecture to listen offline.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'a Class hit pops to Lectures scrolled to that class (Class 15 from '
        'the top)', (tester) async {
      await _pumpApp(tester, catalog: _StubCatalog(catalog: _urduCatalog()));
      final lectures = find.byType(LectureListScreen);
      expect(_scroll(tester, lectures).pixels, 0);

      await tester.tap(find.byKey(WidgetKeys.lecturesSearchAction));
      await tester.pumpAndSettle();
      await _type(tester, 'class 15');
      expect(_classRow('class-15'), findsOneWidget);
      await tester.tap(_classRow('class-15'));
      await tester.pumpAndSettle();

      expect(find.byType(LectureSearchScreen), findsNothing);
      expect(_location(tester), '/lectures');
      final position = _scroll(tester, lectures);
      expect(position.pixels, greaterThan(0));
      final header = find.byKey(WidgetKeys.lecturesChapterHeader('class-15'));
      expect(header, findsOneWidget);
      expect(tester.getTopLeft(header).dy, lessThan(844));
      expect(position.pixels, position.maxScrollExtent);
      _expectNoOverflow(tester);
    });

    testWidgets('a Class hit for a middle class lands its header at the top',
        (tester) async {
      await _pumpApp(tester, catalog: _StubCatalog(catalog: _urduCatalog()));

      await tester.tap(find.byKey(WidgetKeys.lecturesSearchAction));
      await tester.pumpAndSettle();
      await _type(tester, 'class 09');
      await tester.tap(_classRow('class-09'));
      await tester.pumpAndSettle();

      final header = find.byKey(WidgetKeys.lecturesChapterHeader('class-09'));
      expect(tester.getTopLeft(header).dy, closeTo(kToolbarHeight, 1.0));
    });

    testWidgets('a grid cell pops to Lectures scrolled to that class',
        (tester) async {
      await _pumpApp(tester, catalog: _StubCatalog(catalog: _urduCatalog()));
      await tester.tap(find.byKey(WidgetKeys.lecturesSearchAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.searchClassCell('class-15')));
      await tester.pumpAndSettle();

      expect(find.byType(LectureSearchScreen), findsNothing);
      final lectures = find.byType(LectureListScreen);
      final position = _scroll(tester, lectures);
      expect(position.pixels, position.maxScrollExtent);
      expect(
        find.byKey(WidgetKeys.lecturesChapterHeader('class-15')),
        findsOneWidget,
      );
    });

    testWidgets('a grid cell for a middle class lands its header at the top',
        (tester) async {
      await _pumpApp(tester, catalog: _StubCatalog(catalog: _urduCatalog()));
      await tester.tap(find.byKey(WidgetKeys.lecturesSearchAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKeys.searchClassCell('class-06')));
      await tester.pumpAndSettle();

      final header = find.byKey(WidgetKeys.lecturesChapterHeader('class-06'));
      expect(tester.getTopLeft(header).dy, closeTo(kToolbarHeight, 1.0));
    });
  });

  // ── Class grid state from progress ───────────────────────────────────────

  group('class grid state', () {
    testWidgets('marks finished and continue-here from ProgressProvider',
        (tester) async {
      final handle = tester.ensureSemantics();
      final progress = ProgressProvider()..load();
      // Class 07 = lectures 20 and 21: both fully listened.
      await progress.saveProgress('lec-020', 600);
      await progress.saveProgress('lec-021', 600);
      // Last played: lecture 24, in Class 08.
      await progress.saveProgress('lec-024', 120);

      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        progress: progress,
        initialLocation: '/lectures/search',
      );

      Finder cell(String id) => find.byKey(WidgetKeys.searchClassCell(id));
      expect(
        tester.getSemantics(cell('class-07')).label,
        'Class 07, 2 parts, finished',
      );
      expect(
        tester.getSemantics(cell('class-08')).label,
        'Class 08, 4 parts, in progress',
      );
      expect(tester.getSemantics(cell('class-09')).label, 'Class 09, 2 parts');

      // A partially-listened class is not "finished".
      expect(
        find.descendant(
          of: cell('class-07'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cell('class-08'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      handle.dispose();
    });
  });

  // ── Layout: RTL, 2x text, dark ───────────────────────────────────────────

  // The shell draws the mini-player and NavigationBar over the body
  // (`extendBody: true`); the results list must clear them or its last hit is
  // unreachable.
  group('bottom inset', () {
    for (final (name, loc, query, scale) in [
      ('LTR', _en, 'class', 1.0),
      ('LTR', _en, 'class', 2.0),
      ('RTL (ur)', _ur, 'درس', 1.0),
      ('RTL (ur)', _ur, 'درس', 2.0),
    ]) {
      testWidgets(
          'results clear the mini-player: the last hit is tappable '
          '($name, ${scale}x text)', (tester) async {
        final catalog = _urduCatalog();
        final app = await _pumpApp(
          tester,
          catalog: _StubCatalog(catalog: catalog),
          locale: loc,
          textScaler: TextScaler.linear(scale),
          size: const Size(360, 800),
          initialLocation: '/lectures/search',
        );
        // A lecture is loaded, so the shell shows the mini-player.
        await app.player.loadAndPlay(catalog.lectures.first, catalog.lectures);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MiniPlayer), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);

        await _type(tester, query);
        final results = find.byKey(WidgetKeys.searchResults);
        expect(results, findsOneWidget);
        final position = _scroll(tester, results);
        // Rows far down only have estimated extents: re-jump until the
        // extent is measured and we really are at the end.
        for (var i = 0; i < 5; i++) {
          position.jumpTo(position.maxScrollExtent);
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Hits are ranked, so the last built lecture row is the last hit.
        final lastRow = find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>)
                      .value
                      .startsWith('search.lecture-row.'),
            )
            .last;
        final lastId = (tester.widget(lastRow).key! as ValueKey<String>)
            .value
            .split('.')
            .last;
        expect(lastId, isNot(catalog.lectures.first.id));
        final loadsBefore = app.playback.loads.length;
        final rowBottom = tester.getBottomLeft(lastRow).dy;
        final miniTop = tester.getTopLeft(find.byType(MiniPlayer)).dy;
        expect(
          rowBottom,
          lessThanOrEqualTo(miniTop),
          reason: 'last hit ($rowBottom) must end above the '
              'mini-player ($miniTop)',
        );

        // And it is actually hit by a tap, which plays that lecture.
        expect(lastRow.hitTestable(), findsOneWidget);
        await tester.tap(lastRow, warnIfMissed: true);
        await _pumpRoute(tester);
        expect(app.playback.loads.length, loadsBefore + 1);
        expect(app.playback.loads.last.lecture.id, lastId);
        expect(find.byType(PlayerScreen), findsOneWidget);
        // The fake backend never reports ready; stop the load watchdog.
        app.player.dispose();
      });
    }
  });

  group('layout', () {
    for (final loc in [_ar, _ur]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'every state fits at ${scale}x text, ${loc.name} (RTL), narrow '
            'phone', (tester) async {
          const narrow = Size(360, 740);
          final scaler = TextScaler.linear(scale);

          // idle + results + no-results share one catalogue.
          final urdu = _StubCatalog(catalog: _urduCatalog());
          await _pumpApp(
            tester,
            catalog: urdu,
            locale: loc,
            textScaler: scaler,
            size: narrow,
            initialLocation: '/lectures/search',
          );
          _expectNoOverflow(tester);
          await _type(tester, '12');
          _expectNoOverflow(tester);
          await _type(tester, 'class 40');
          expect(find.byKey(WidgetKeys.searchNoResults), findsOneWidget);
          _expectNoOverflow(tester);

          await tester.pumpWidget(const SizedBox());
          await _pumpApp(
            tester,
            catalog: _StubCatalog(
              stubStatus: CatalogStatus.error,
              stubNeedsOnline: true,
            ),
            locale: loc,
            textScaler: scaler,
            size: narrow,
            initialLocation: '/lectures/search',
          );
          expect(find.byKey(WidgetKeys.searchUnavailable), findsOneWidget);
          _expectNoOverflow(tester);

          await tester.pumpWidget(const SizedBox());
          await _pumpApp(
            tester,
            catalog: _StubCatalog(
              stubStatus: CatalogStatus.error,
              stubError: 'HTTP 503 from the CDN',
            ),
            locale: loc,
            textScaler: scaler,
            size: narrow,
            initialLocation: '/lectures/search',
          );
          expect(find.byKey(WidgetKeys.searchError), findsOneWidget);
          _expectNoOverflow(tester);

          await tester.pumpWidget(const SizedBox());
          await _pumpApp(
            tester,
            catalog: _StubCatalog(catalog: _arabicCatalog()),
            edition: _arabicEdition,
            locale: loc,
            textScaler: scaler,
            size: narrow,
            initialLocation: '/lectures/search',
          );
          _expectNoOverflow(tester);
          await _type(tester, 'الثالث');
          _expectNoOverflow(tester);
        });
      }
    }

    testWidgets('RTL mirrors the grid: class 01 sits at the right edge',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        locale: _ur,
        initialLocation: '/lectures/search',
      );

      final first = tester.getCenter(
        find.byKey(WidgetKeys.searchClassCell('class-01')),
      );
      final second = tester.getCenter(
        find.byKey(WidgetKeys.searchClassCell('class-02')),
      );
      expect(first.dx, greaterThan(second.dx));
      expect(first.dy, second.dy);
    });

    testWidgets('the grid has five columns', (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        initialLocation: '/lectures/search',
      );

      double top(int c) => tester
          .getTopLeft(find.byKey(WidgetKeys.searchClassCell('class-${_p2(c)}')))
          .dy;
      expect({for (var c = 1; c <= 5; c++) top(c)}, hasLength(1));
      expect(top(6), greaterThan(top(1)));
      expect(top(10), top(6));
      expect(top(11), greaterThan(top(10)));
    });

    for (final loc in [_en, _ur, _ar]) {
      testWidgets('dark theme: idle and results render (${loc.name})',
          (tester) async {
        await _pumpApp(
          tester,
          catalog: _StubCatalog(catalog: _urduCatalog()),
          locale: loc,
          dark: true,
          initialLocation: '/lectures/search',
        );
        _expectNoOverflow(tester);
        await _type(tester, '12');
        expect(find.byKey(WidgetKeys.searchResults), findsOneWidget);
        _expectNoOverflow(tester);
      });
    }

    testWidgets('every Urdu-chrome line gets Nastaliq leading (1.8-2.1)',
        (tester) async {
      await _pumpApp(
        tester,
        catalog: _StubCatalog(catalog: _urduCatalog()),
        locale: _ur,
        initialLocation: '/lectures/search',
      );

      // The effective line height: Text wraps its span in one carrying the
      // theme's default, so the innermost explicit height along the first-child
      // chain is the one that applies.
      double? leading(RichText r) {
        double? height;
        InlineSpan? span = r.text;
        while (span is TextSpan) {
          height = span.style?.height ?? height;
          final children = span.children;
          span = children == null || children.isEmpty ? null : children.first;
        }
        return height;
      }

      void expectLeading(Finder within, {required String why}) {
        final texts = tester
            .widgetList<RichText>(
              find.descendant(of: within, matching: find.byType(RichText)),
            )
            // Skip the glyph of an icon and the numeric badge: only prose.
            .where((r) => r.text.toPlainText().length > 3)
            .toList();
        expect(texts, isNotEmpty, reason: why);
        for (final r in texts) {
          expect(
            leading(r),
            inInclusiveRange(1.8, 2.1),
            reason: '$why: "${r.text.toPlainText()}"',
          );
        }
      }

      // Idle: the example chip, the grid heading and the grid cells.
      expectLeading(
        find.byKey(WidgetKeys.searchChip('درس ۰۵')),
        why: 'chip',
      );
      expectLeading(
        find.byKey(WidgetKeys.searchClassCell('class-12')),
        why: 'grid cell',
      );
      expectLeading(find.byKey(WidgetKeys.searchIdle), why: 'idle');

      await _type(tester, '12');
      expectLeading(_classRow('class-12'), why: 'class row');
      expectLeading(_row('lec-037'), why: 'lecture row');
      expectLeading(_row('lec-012'), why: 'number-only lecture row');
      expectLeading(
        find.byKey(WidgetKeys.searchResultCount),
        why: 'result count',
      );

      await _type(tester, 'class 40');
      expectLeading(find.byKey(WidgetKeys.searchNoResults), why: 'no results');
    });
  });
}
