// Layout-overflow smoke test: every user-facing screen, in every chrome
// language (en, ar, ur, ur_roman), at text scale 1.0 and 2.0, on a narrow
// 360x640 phone, with realistic content (the real Urdu and Arabic chapter
// titles from the bundled books, which run up to hundreds of characters).
//
// A `RenderFlex overflowed` report fails the test. Nothing is suppressed: the
// handler below records the report (so ALL overflows on a screen are listed,
// not just the first, which is the only one Flutter names) and the test then
// asserts the list is empty. Any other framework error still fails the test.
//
// When this test fails, the message lists, per overflow, the pixels, the edge
// and the `lib/` widget that overflowed. See docs/gotchas.md (RenderFlex
// overflow bisect entry) for why the first-report-only behaviour matters.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/app.dart' show createAppRouter;
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/announcement_model.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/saved_lecture_metadata.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/app_config_provider.dart';
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
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/about_page.dart';
import 'package:myapp/screens/book_reader_screen.dart';
import 'package:myapp/screens/choose_series_screen.dart';
import 'package:myapp/screens/edition_missing_screen.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/library_screen.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/screens/read_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/screens/study_class_complete_screen.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/widgets/announcements_banner.dart';
import 'package:myapp/widgets/catalog_connect_required.dart';
import 'package:myapp/widgets/catalog_error_body.dart';
import 'package:myapp/widgets/continue_listening_banner.dart';
import 'package:myapp/widgets/continue_reading_banner.dart';
import 'package:myapp/widgets/lecture_tile.dart';
import 'package:myapp/widgets/mini_player.dart';
import 'package:myapp/widgets/offline_sheet.dart' show showOfflineSheet;
import 'package:myapp/widgets/study/class_progress_card.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';

import 'support/fake_audio_playback.dart';

// ── Real content ────────────────────────────────────────────────────────────

Map<String, dynamic> _bookJson(String id) =>
    jsonDecode(File('assets/content/book_$id.json').readAsStringSync())
        as Map<String, dynamic>;

late final List<String> _urTitles; // real Urdu chapter titles, long
late final List<String> _arTitles; // real Arabic chapter titles
late final BookContent _urBook;
late final BookContent _arBook;
late final String _longestUrChapterId;

/// Cuts [s] at a word boundary at or before [max] code units.
String _cut(String s, int max) {
  if (s.length <= max) return s;
  final i = s.lastIndexOf(' ', max);
  return s.substring(0, i > 0 ? i : max);
}

String _p2(int n) => n.toString().padLeft(2, '0');

String _extDigits(String s) => s.replaceAllMapped(
      RegExp(r'\d'),
      (m) => String.fromCharCode(0x06F0 + int.parse(m[0]!)),
    );

// ── Editions ────────────────────────────────────────────────────────────────

const _urdu = SeriesConfig.legacyUrduFallback;
const _arabic = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {
    'en': 'Kitab at-Tawheed (Arabic)',
    'ur': 'کتاب التوحید (عربی)',
  },
  speakerName: {
    'en': 'Shaikh Salih al-Fawzan Hafizhahullah',
    'ar': 'الشيخ صالح بن فوزان الفوزان حفظه الله',
  },
);

/// Urdu edition: 12 classes of 2-3 parts each (real chapter titles).
Catalog _urduCatalog() {
  final chapters = <Chapter>[];
  final lectures = <Lecture>[];
  var n = 0;
  // Class 12 is the book's longest chapter title (hundreds of characters).
  final picks = [
    for (var i = 0; i < 11; i++) i,
    _urTitles.indexOf(_urTitles.reduce((a, b) => a.length >= b.length ? a : b)),
  ];
  for (var c = 1; c <= picks.length; c++) {
    final id = 'class-${_p2(c)}';
    final real = _urTitles[picks[c - 1]];
    final parts = 2 + (c % 2);
    chapters.add(
      Chapter(
        id: id,
        number: c,
        title: {
          'en': 'Class ${_p2(c)}: The Book of Tawheed and what Allah is owed '
              'by His servants',
          'ur': 'درس ${_extDigits(_p2(c))}: ${_cut(real, 110)}',
          'roman': 'Dars ${_p2(c)}: Kitab at-Tawheed aur bandon par '
              'Allah ka haq',
        },
        lectureCount: parts,
        bookChapterId: 'ch-${_p2(picks[c - 1] + 1)}',
      ),
    );
    for (var p = 1; p <= parts; p++) {
      n++;
      lectures.add(
        Lecture(
          id: 'lec-${n.toString().padLeft(3, '0')}',
          number: n,
          chapterId: id,
          title: {
            'en': 'Class ${_p2(c)} — Part ${_p2(p)}: '
                'Tawheed and its virtue in forgiving sins',
            'ur': 'درس ${_extDigits(_p2(c))} — حصہ ${_extDigits(_p2(p))}: '
                '${_cut(real, 90)}',
            'roman': 'Dars ${_p2(c)} — Hissa ${_p2(p)}: Tawheed ki fazilat '
                'aur gunahon ka mitaya jana',
          },
          titleArabic: _cut(_arTitles[picks[c - 1]], 70),
          audioUrl: 'https://example.com/$n.mp3',
          durationSeconds: 2700 + n * 37,
          fileSizeBytes: 24 * 1024 * 1024 + n * 4096,
        ),
      );
    }
  }
  return Catalog(
    version: 1,
    book: Book(
      id: 'book-ur',
      title: const {
        'en': 'Sharah Kitab at-Tawheed',
        'ur': 'شرح کتاب التوحید',
        'roman': 'Sharah Kitab at-Tawheed',
      },
      speaker: const {
        'en': 'Shaikh Abdullah Nasir Rahmani Hafizahullah',
        'ur': 'شیخ عبداللہ ناصر رحمانی حفظہ اللہ',
        'roman': 'Shaikh Abdullah Nasir Rahmani Hafizahullah',
      },
      totalDurationSeconds: 83940,
      lectureCount: n,
      coverImageUrl: '',
      language: 'Urdu',
    ),
    chapters: chapters,
    lectures: lectures,
    dailyBenefits: const [],
  );
}

/// Arabic edition: flat (no chapters), real Arabic chapter titles.
Catalog _arabicCatalog() {
  final lectures = <Lecture>[
    for (var i = 0; i < 14; i++)
      Lecture(
        id: 'lec-${(i + 1).toString().padLeft(3, '0')}',
        number: i + 1,
        chapterId: '',
        title: {'ar': _arTitles[i], 'en': 'Dars ${_p2(i + 1)}'},
        audioUrl: 'https://example.com/${i + 1}.mp3',
        durationSeconds: 3100 + i * 41,
        fileSizeBytes: 30 * 1024 * 1024 + i * 4096,
      ),
  ];
  return Catalog(
    version: 1,
    book: Book(
      id: 'book-ar',
      title: const {'en': 'Kitab at-Tawheed', 'ar': 'كتاب التوحيد'},
      speaker: const {
        'en': 'Shaikh Salih al-Fawzan Hafizhahullah',
        'ar': 'الشيخ صالح بن فوزان الفوزان حفظه الله',
      },
      totalDurationSeconds: 14 * 3300,
      lectureCount: lectures.length,
      coverImageUrl: '',
      language: 'Arabic',
    ),
    chapters: const [],
    lectures: lectures,
    dailyBenefits: const [],
  );
}

// ── Chrome languages ────────────────────────────────────────────────────────

class _Loc {
  const _Loc(this.name, this.language, this.locale);
  final String name;
  final AppLanguage language;
  final Locale locale;
  bool get rtl => name == 'ar' || name == 'ur';
}

const _locales = [
  _Loc('en', AppLanguage.english, Locale('en')),
  _Loc('ar', AppLanguage.arabic, Locale('ar')),
  _Loc('ur', AppLanguage.urdu, Locale('ur')),
  _Loc(
    'ur_roman',
    AppLanguage.romanUrdu,
    Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman'),
  ),
];

// ── Catalogue states ────────────────────────────────────────────────────────

class _StubCatalog extends CatalogProvider {
  _StubCatalog({
    this.stubStatus = CatalogStatus.loaded,
    Catalog? catalog,
    this.stubNeedsOnline = false,
    this.stubError,
  }) : _stubCatalog = catalog;

  final CatalogStatus stubStatus;
  final Catalog? _stubCatalog;
  final bool stubNeedsOnline;
  final String? stubError;
  String? stubSeriesId;

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
  Future<void> load([SeriesConfig? series]) async {}
}

// ── The app under test ──────────────────────────────────────────────────────

/// Everything a scenario can tune before the app is pumped.
class _Env {
  _Env(this.loc, this.scale, this.edition) {
    series = SeriesProvider()
      ..setAvailableSeriesForTest([_urdu, _arabic])
      ..setCurrentSeriesForTest(edition);
    catalog = _StubCatalog(
      catalog: edition == _urdu ? _urduCatalog() : _arabicCatalog(),
    );
    progress = ProgressProvider()..load();
    downloads = DownloadsProvider();
    connectivity = ConnectivityProvider.testOnline();
    playback = FakeAudioPlayback();
    announcements = AnnouncementsProvider();
    book = BookProvider()..setBookForTest(edition == _urdu ? _urBook : _arBook);
    reading = ReadingProvider(series)..load();
    flags = FeatureFlagsProvider()
      ..setExperimentalJsonForTest({'multiSeries': true})
      ..setFeaturesJsonForTest({
        'downloads': true,
        'shareButton': true,
        'shareLectureRow': true,
        'playbackSpeed': true,
        'continueListening': true,
        'announcements': true,
        'language': true,
        'appLinks': true,
        'studyMode': true,
      });
  }

  final _Loc loc;
  final double scale;
  final SeriesConfig edition;
  String location = '/lectures';

  late final SeriesProvider series;
  late _StubCatalog catalog;
  late final ProgressProvider progress;
  late final DownloadsProvider downloads;
  late ConnectivityProvider connectivity;
  late final FakeAudioPlayback playback;
  late final AnnouncementsProvider announcements;
  late final BookProvider book;
  late final ReadingProvider reading;
  late final FeatureFlagsProvider flags;
  late PlayerNotifier player;

  bool get isUrdu => edition == _urdu;
  Catalog get cat => catalog.catalog!;
  List<Lecture> get lectures => cat.lectures;

  void catalogState(
    CatalogStatus status, {
    bool needsOnline = false,
    String? error,
    Catalog? withCatalog,
  }) {
    catalog = _StubCatalog(
      stubStatus: status,
      catalog: withCatalog,
      stubNeedsOnline: needsOnline,
      stubError: error,
    );
  }
}

typedef _Seed = Future<void> Function(_Env env);
typedef _Act = Future<void> Function(WidgetTester tester, _Env env);

class _Scenario {
  const _Scenario(
    this.name, {
    this.location = '/lectures',
    this.editions = const [_urdu, _arabic],
    this.seed,
    this.act,
    this.shows,
  });
  final String name;
  final String location;
  final List<SeriesConfig> editions;
  final _Seed? seed;
  final _Act? act;

  /// What must be on screen once the scenario is set up: proves the case
  /// reached the intended screen rather than a redirect or an empty page.
  final Finder Function()? shows;
}

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  // Never pumpAndSettle: loading states spin forever.
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpApp(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  env.catalog.stubSeriesId = env.edition.id;
  final lang = LanguageProvider()..load();
  lang.applyLanguageFeatureFlag(true);
  lang.applySeriesDefault(env.edition);
  await lang.setLanguage(env.loc.language);

  env.player = PlayerNotifier(
    env.playback,
    env.progress,
    env.downloads,
    env.connectivity,
    env.catalog,
  );
  addTearDown(env.player.dispose);
  final study = StudyProgressProvider(env.progress, env.catalog, env.series)
    ..load();
  addTearDown(study.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        ChangeNotifierProvider.value(value: env.flags),
        ChangeNotifierProvider.value(value: env.announcements),
        ChangeNotifierProvider.value(value: env.series),
        ChangeNotifierProvider.value(value: env.connectivity),
        ChangeNotifierProvider<CatalogProvider>.value(value: env.catalog),
        ChangeNotifierProvider.value(value: env.book),
        ChangeNotifierProvider.value(value: env.progress),
        ChangeNotifierProvider.value(value: study),
        ChangeNotifierProvider.value(value: env.downloads),
        ChangeNotifierProvider.value(value: env.player),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider.value(value: env.reading),
        ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
        ChangeNotifierProvider.value(value: lang),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: lang.locale,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return Directionality(
            textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(env.scale)),
              child: child!,
            ),
          );
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: createAppRouter(initialLocation: env.location),
      ),
    ),
  );
  await _settle(tester);
}

// ── Overflow capture ────────────────────────────────────────────────────────

/// "name: 96px right @ lib/widgets/lecture_tile.dart:174" for one report.
String _describe(FlutterErrorDetails d) {
  final text = d.toString();
  final px = RegExp(r'overflowed by ([\d.]+) pixels on the (\w+)')
      .firstMatch(d.exceptionAsString());
  final where = RegExp(r'(lib/[\w/]+\.dart:\d+)').firstMatch(text)?.group(1);
  final widget = RegExp(r'creator: ([^\n]*)').firstMatch(text)?.group(1);
  final box = RegExp(r'constraints: BoxConstraints\(([^)]*)\)')
      .firstMatch(text)
      ?.group(1);
  return '${px?.group(1)}px ${px?.group(2)} '
      '@ ${where ?? 'unnamed (see creator)'}'
      '${box == null ? '' : '  [flex box: $box]'}'
      '${widget == null ? '' : '  [creator: ${_cut(widget, 90)}]'}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final ur = _bookJson('tawheed-ur');
    final ar = _bookJson('tawheed-ar');
    _urBook = BookContent.fromJson(ur);
    _arBook = BookContent.fromJson(ar);
    _urTitles = [for (final c in _urBook.chapters) c.title];
    _arTitles = [for (final c in _arBook.chapters) c.title];
    _longestUrChapterId = _urBook.chapters
        .reduce((a, b) => a.title.length >= b.title.length ? a : b)
        .id;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    // Playing a saved lecture resolves its file path under the app's
    // documents directory.
    DownloadService.resetForTest(
      Directory.systemTemp.createTempSync('overflow_smoke_').path,
    );
    PackageInfo.setMockInitialValues(
      appName: 'Al-Tawheed',
      packageName: 'com.almarfa.tawheed',
      version: '2.4.1',
      buildNumber: '41',
      buildSignature: '',
    );
  });

  final scenarios = _scenarios();
  for (final s in scenarios) {
    group(s.name, () {
      for (final edition in s.editions) {
        for (final loc in _locales) {
          for (final scale in const [1.0, 2.0]) {
            testWidgets(
                '${edition == _urdu ? 'ur-edition' : 'ar-edition'} · '
                '${loc.name} · ${scale}x', (tester) async {
              final overflows = <String>[];
              final original = FlutterError.onError;
              FlutterError.onError = (details) {
                if (details.exceptionAsString().contains('overflowed by')) {
                  overflows.add(_describe(details));
                  return;
                }
                original?.call(details);
              };
              addTearDown(() => FlutterError.onError = original);

              final env = _Env(loc, scale, edition)..location = s.location;
              await s.seed?.call(env);
              await _pumpApp(tester, env);
              await s.act?.call(tester, env);
              await _settle(tester);
              if (s.shows != null) expect(s.shows!(), findsWidgets);
              // Lists build rows lazily: visit every row, not just the first.
              await _scrollThrough(tester);

              // Tear the tree down and stop the player now: playing audio
              // keeps a periodic save timer that must not outlive the test.
              await tester.pumpWidget(const SizedBox());
              env.player.dispose();

              expect(
                overflows,
                isEmpty,
                reason: 'RenderFlex overflow in "${s.name}" '
                    '(${edition.id}, ${loc.name}, ${scale}x, 360x640):\n'
                    '${overflows.toSet().join('\n')}',
              );
            });
          }
        }
      }
    });
  }
}

// ── Scenarios ───────────────────────────────────────────────────────────────

SavedLectureMetadata _snap(Lecture l) => SavedLectureMetadata.fromLecture(l);

Future<void> _startPlaying(_Env env, Lecture lecture) async {
  await env.player.loadAndPlay(lecture, env.lectures);
  // A refused load (offline, not saved) leaves nothing to emit events for.
  expect(env.playback.loads, isNotEmpty, reason: 'the lecture should load');
  env.playback
    ..emitDuration(Duration(seconds: lecture.durationSeconds))
    ..emitPosition(const Duration(minutes: 12, seconds: 5))
    ..emitPlaybackState(playing: true);
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).first);
  await _settle(tester);
}

List<_Scenario> _scenarios() => [
      // ── Lectures ──────────────────────────────────────────────────────────
      _Scenario('Lectures', shows: () => find.byType(LectureListScreen)),
      _Scenario(
        'Lectures + continue-listening banner',
        shows: () => find.byType(ContinueListeningBanner),
        seed: (env) async {
          await env.progress.saveProgress(env.lectures[3].id, 1100);
        },
      ),
      _Scenario(
        'Lectures + all-complete banner',
        shows: () => find.byIcon(Icons.workspace_premium_rounded),
        seed: (env) async {
          for (final l in env.lectures) {
            await env.progress.saveProgress(l.id, l.durationSeconds);
          }
        },
        // At large text the continue-listening banner above pushes it off the
        // first screen.
        act: (tester, env) => _scrollTo(
          tester,
          find.byIcon(Icons.workspace_premium_rounded),
        ),
      ),
      _Scenario(
        'Lectures rows in every state + mini-player',
        shows: () => find.byType(MiniPlayer),
        seed: (env) async {
          final l = env.lectures;
          await env.progress.saveProgress(l[1].id, 900); // part-listened
          await env.progress.saveProgress(l[2].id, l[2].durationSeconds);
          await env.progress.toggleBookmark(l[3]);
          env.downloads.seedDownloadedMetadataForTest(_snap(l[4]));
          env.downloads.seedDownloadedForTest(l[4].id);
          env.downloads.seedDownloadingForTest(l[5].id);
        },
        act: (tester, env) async {
          await _startPlaying(env, env.lectures[3]);
          await _settle(tester);
        },
      ),
      _Scenario(
        'Lectures offline: banner + not-downloaded rows',
        shows: () => find.byKey(WidgetKeys.offlineStatusBanner),
        seed: (env) async {
          env.connectivity = ConnectivityProvider.testOffline();
          env.downloads.seedDownloadedForTest(env.lectures[0].id);
        },
        act: (tester, env) async {
          await _startPlaying(env, env.lectures[0]);
          await _settle(tester);
        },
      ),
      _Scenario(
        'Lectures without a catalogue: load error',
        shows: () => find.byType(CatalogErrorBody),
        seed: (env) async => env.catalogState(
          CatalogStatus.error,
          error: 'Could not reach the server. Check your connection and try '
              'again in a moment.',
        ),
      ),
      _Scenario(
        'Lectures without a catalogue: connect required',
        shows: () => find.byType(CatalogConnectRequiredBody),
        seed: (env) async => env.catalogState(
          CatalogStatus.error,
          needsOnline: true,
          error: 'x',
        ),
      ),
      _Scenario(
        'Lectures without a catalogue: loading',
        shows: () => find.byType(CircularProgressIndicator),
        seed: (env) async => env.catalogState(CatalogStatus.loading),
      ),
      _Scenario(
        'Lectures with an empty catalogue',
        shows: () => find.byIcon(Icons.library_music_outlined),
        seed: (env) async => env.catalogState(
          CatalogStatus.loaded,
          withCatalog: Catalog(
            version: 1,
            book: env.cat.book,
            chapters: const [],
            lectures: const [],
            dailyBenefits: const [],
          ),
        ),
      ),
      _Scenario(
        'Lectures: announcement sheet',
        shows: () => find.byType(AnnouncementCard),
        seed: (env) async {
          env.announcements.setAnnouncementsForTest([
            Announcement(
              id: 'a1',
              type: 'info',
              title: const {
                'en': 'A new edition of the course is now available to listen',
                'ur': 'کورس کا نیا ایڈیشن اب سننے کے لیے دستیاب ہے',
                'ar': 'صدرت الطبعة الجديدة من الدروس وهي متاحة للاستماع الآن',
                'roman': 'Course ka naya edition ab sunne ke liye dastiyab hai',
              },
              body: const {
                'en': 'Open Settings, then choose the edition you would like '
                    'to listen to, and your progress is kept for each one.',
                'ur': 'ترتیبات کھولیے اور وہ ایڈیشن منتخب کیجیے جسے آپ سننا '
                    'چاہتے ہیں؛ ہر ایڈیشن کی پیش رفت الگ محفوظ رہتی ہے۔',
                'ar': 'افتح الإعدادات ثم اختر الطبعة التي تريد الاستماع إليها '
                    'وسيُحفظ تقدمك في كل طبعة على حدة.',
                'roman': 'Settings kholiye aur woh edition chuniye jise aap '
                    'sunna chahte hain.',
              },
              ctaLabel: const {
                'en': 'Open Settings now',
                'ur': 'ترتیبات کھولیں',
                'ar': 'افتح الإعدادات الآن',
                'roman': 'Settings kholein',
              },
              ctaUrl: 'https://example.com',
              platforms: const ['android', 'ios'],
            ),
            Announcement(
              id: 'a2',
              type: 'warning',
              title: const {'en': 'Short', 'ur': 'مختصر', 'ar': 'قصير'},
              body: const {'en': 'Body', 'ur': 'متن', 'ar': 'نص'},
              platforms: const ['android', 'ios'],
            ),
          ]);
        },
        act: (tester, env) async =>
            _tapIcon(tester, Icons.notifications_none_rounded),
      ),
      _Scenario(
        'Lectures: all-lectures-complete sheet',
        shows: () => find.byType(BottomSheet),
        seed: (env) async {
          for (final l in env.lectures) {
            await env.progress.saveProgress(l.id, l.durationSeconds);
          }
        },
        act: (tester, env) async {
          await env.player.loadAndPlay(env.lectures.last, env.lectures);
          env.playback.emitCompleted();
          await _settle(tester);
        },
      ),

      // ── Search ────────────────────────────────────────────────────────────
      _Scenario(
        'Search idle',
        shows: () => find.byKey(WidgetKeys.searchIdle),
        location: '/lectures/search',
      ),
      _Scenario(
        'Search results',
        shows: () => find.byKey(WidgetKeys.searchResults),
        location: '/lectures/search',
        act: (tester, env) async {
          await tester.enterText(find.byKey(WidgetKeys.searchField), 'باب');
          await _settle(tester);
        },
      ),
      _Scenario(
        'Search no results',
        shows: () => find.byKey(WidgetKeys.searchNoResults),
        location: '/lectures/search',
        act: (tester, env) async {
          await tester.enterText(find.byKey(WidgetKeys.searchField), 'zzzzqx');
          await _settle(tester);
        },
      ),
      _Scenario(
        'Search unavailable (catalogue not loaded)',
        shows: () => find.byKey(WidgetKeys.searchUnavailable),
        location: '/lectures/search',
        seed: (env) async => env.catalogState(
          CatalogStatus.error,
          needsOnline: true,
          error: 'x',
        ),
      ),
      _Scenario(
        'Search: load error',
        shows: () => find.byKey(WidgetKeys.searchError),
        location: '/lectures/search',
        seed: (env) async => env.catalogState(
          CatalogStatus.error,
          error: 'Could not reach the server.',
        ),
      ),

      // ── Player ────────────────────────────────────────────────────────────
      _Scenario(
        'Player',
        shows: () => find.byType(PlayerScreen),
        seed: (env) async {
          await env.progress.toggleBookmark(env.lectures[0]);
        },
        act: (tester, env) async {
          await _startPlaying(env, env.lectures[0]);
          await _push(tester, '/player');
        },
      ),
      _Scenario(
        'Player offline (playing a saved lecture)',
        shows: () => find.byType(PlayerScreen),
        seed: (env) async {
          env.connectivity = ConnectivityProvider.testOffline();
          env.downloads.seedDownloadedMetadataForTest(_snap(env.lectures[0]));
          env.downloads.seedDownloadedForTest(env.lectures[0].id);
        },
        act: (tester, env) async {
          await _startPlaying(env, env.lectures[0]);
          await _push(tester, '/player');
        },
      ),
      _Scenario(
        'Player: load error',
        shows: () => find.byType(PlayerScreen),
        seed: (env) async {
          env.playback.failNextLoad = Exception(
            'Could not load this lecture. Check your connection and try again.',
          );
        },
        act: (tester, env) async {
          await env.player.loadAndPlay(env.lectures[0], env.lectures);
          await _push(tester, '/player');
        },
      ),
      for (final saved in [false, true])
        _Scenario(
          'Player: saved-audio sheet (${saved ? 'saved' : 'not saved'})',
          shows: () => find.byType(BottomSheet),
          seed: (env) async {
            if (saved) {
              env.downloads
                  .seedDownloadedMetadataForTest(_snap(env.lectures[0]));
              env.downloads.seedDownloadedForTest(env.lectures[0].id);
            }
            env.downloads.seedDownloadingForTest(env.lectures[1].id);
          },
          act: (tester, env) async {
            await _startPlaying(env, env.lectures[2]);
            await _push(tester, '/player');
            showOfflineSheet(
              tester.element(find.byType(PlayerScreen)),
              env.lectures[0],
            );
          },
        ),

      // ── Read ──────────────────────────────────────────────────────────────
      _Scenario(
        'Read: Book list',
        shows: () => find.byType(ReadScreen),
        location: '/read',
      ),
      _Scenario(
        'Read: Book list + continue-reading banner',
        shows: () => find.byType(ContinueReadingBanner),
        location: '/read',
        seed: (env) async {
          await env.reading
              .setBookScrollOffset(env.book.book!.chapters[2].id, 120);
        },
      ),
      _Scenario(
        'Read: Book list load error',
        shows: () => find.byType(CatalogErrorBody),
        location: '/read',
        seed: (env) async => env.book.setErrorForTest('Could not load book'),
      ),
      _Scenario(
        'Read: Study load error',
        shows: () => find.byType(CatalogErrorBody),
        location: '/read?tab=study',
        editions: [_urdu],
        seed: (env) async => env.catalogState(
          CatalogStatus.error,
          error: 'Could not reach the server.',
        ),
      ),
      _Scenario(
        'Read: Study connect required',
        shows: () => find.byType(CatalogConnectRequiredBody),
        location: '/read?tab=study',
        editions: [_urdu],
        seed: (env) async => env.catalogState(
          CatalogStatus.error,
          needsOnline: true,
          error: 'x',
        ),
      ),
      _Scenario(
        'Read: Study',
        shows: () => find.byType(StudyBody),
        location: '/read?tab=study',
        editions: [_urdu],
      ),
      _Scenario(
        'Read: Study with progress',
        shows: () => find.byType(ClassProgressCard),
        location: '/read?tab=study',
        editions: const [_urdu],
        seed: (env) async {
          final l = env.lectures;
          for (final x in l.take(4)) {
            await env.progress.saveProgress(x.id, x.durationSeconds);
          }
          await env.progress.saveProgress(l[5].id, 700);
        },
        act: (tester, env) => _scrollTo(tester, find.byType(ClassProgressCard)),
      ),
      _Scenario(
        'Book reader',
        shows: () => find.byType(BookReaderScreen),
        location: '/book/ch-01',
      ),
      _Scenario(
        'Book reader: longest chapter title',
        shows: () => find.byType(BookReaderScreen),
        editions: const [_urdu],
        location: '/book/ch-01',
        seed: (env) async {
          env.location = '/book/$_longestUrChapterId';
        },
      ),
      _Scenario(
        'Book reader: Aa sheet',
        shows: () => find.byKey(WidgetKeys.settingsTextSizeSlider),
        location: '/book/ch-02',
        act: (tester, env) async =>
            tester.tap(find.byKey(WidgetKeys.readerTextSize)),
      ),
      _Scenario(
        'Book reader: colour-key sheet',
        shows: () => find.byType(BottomSheet),
        location: '/book/ch-02',
        act: (tester, env) async {
          await _tapIcon(tester, Icons.more_vert_rounded);
          await tester.tap(find.byIcon(Icons.palette_outlined));
          await _settle(tester);
        },
      ),
      _Scenario(
        'Study class complete',
        shows: () => find.byType(StudyClassCompleteScreen),
        location: '/study/complete?chapterId=class-02',
        editions: const [_urdu],
        seed: (env) async {
          await env.progress.saveProgress(env.lectures[0].id, 99999);
        },
      ),

      // ── Library ───────────────────────────────────────────────────────────
      _Scenario(
        'Library: Bookmarks empty',
        shows: () => find.byType(LibraryScreen),
        location: '/library',
      ),
      _Scenario(
        'Library: Bookmarks populated',
        shows: () => find.byType(LectureTile),
        location: '/library',
        seed: (env) async {
          for (final l in env.lectures.take(6)) {
            await env.progress.toggleBookmark(l);
          }
        },
      ),
      _Scenario(
        'Library: Downloads empty',
        shows: () => find.byType(LibraryScreen),
        location: '/library?tab=downloads',
      ),
      _Scenario(
        'Library: Downloads populated + downloading + unavailable',
        shows: () => find.byType(LibraryScreen),
        location: '/library?tab=downloads',
        seed: (env) async {
          for (final l in env.lectures.take(6)) {
            env.downloads.seedDownloadedMetadataForTest(_snap(l));
            env.downloads.seedDownloadedForTest(l.id);
          }
          env.downloads.seedDownloadingForTest(env.lectures[6].id);
          env.downloads.seedUnavailableMetadataForTest(_snap(env.lectures[7]));
        },
      ),
      _Scenario(
        'Library: Downloads offline banner + catalogue gone',
        shows: () => find.byKey(WidgetKeys.offlineStatusBanner),
        location: '/library?tab=downloads',
        seed: (env) async {
          env.connectivity = ConnectivityProvider.testOffline();
          for (final l in env.lectures.take(5)) {
            env.downloads.seedDownloadedMetadataForTest(_snap(l));
          }
          env.catalogState(CatalogStatus.error, needsOnline: true, error: 'x');
        },
      ),
      _Scenario(
        'Library: Downloads, no downloads feature rows + mini-player',
        shows: () => find.byType(MiniPlayer),
        location: '/library?tab=downloads',
        seed: (env) async {
          for (final l in env.lectures.take(3)) {
            env.downloads.seedDownloadedMetadataForTest(_snap(l));
            env.downloads.seedDownloadedForTest(l.id);
          }
        },
        act: (tester, env) async {
          await _startPlaying(env, env.lectures[0]);
          await _settle(tester);
        },
      ),
      _Scenario(
        'Library: delete-saved-audio confirm dialog',
        shows: () => find.byType(AlertDialog),
        location: '/library?tab=downloads',
        seed: (env) async {
          for (final l in env.lectures.take(3)) {
            env.downloads.seedDownloadedMetadataForTest(_snap(l));
            env.downloads.seedDownloadedForTest(l.id);
          }
        },
        act: (tester, env) => _tapIcon(tester, Icons.delete_outline_rounded),
      ),
      _Scenario(
        'Library: remove-all confirm dialog',
        shows: () => find.byType(AlertDialog),
        location: '/library?tab=downloads',
        seed: (env) async {
          for (final l in env.lectures.take(3)) {
            env.downloads.seedDownloadedMetadataForTest(_snap(l));
            env.downloads.seedDownloadedForTest(l.id);
          }
        },
        act: (tester, env) async {
          await tester.tap(find.byKey(WidgetKeys.libraryRemoveAllDownloads));
          await _settle(tester);
        },
      ),

      // ── Settings / About ──────────────────────────────────────────────────
      _Scenario(
        'Settings (all sections on)',
        shows: () => find.byType(SettingsScreen),
        location: '/settings',
      ),
      _Scenario(
        'Settings: playback-speed sheet',
        shows: () => find.byType(BottomSheet),
        location: '/settings',
        act: (tester, env) async {
          await _scrollTo(tester, find.byIcon(Icons.speed_rounded));
          await _tapIcon(tester, Icons.speed_rounded);
        },
      ),
      _Scenario(
        'About',
        shows: () => find.byType(AboutPage),
        location: '/about',
      ),

      // ── Onboarding ────────────────────────────────────────────────────────
      _Scenario(
        'Welcome',
        shows: () => find.byType(WelcomeScreen),
        location: '/',
      ),
      _Scenario(
        'Choose edition',
        shows: () => find.byType(ChooseSeriesScreen),
        location: '/choose-series',
      ),
      _Scenario(
        'Edition missing',
        shows: () => find.byType(EditionMissingScreen),
        location: '/edition-missing',
      ),
    ];

/// Scrolls the first vertical scrollable until [target] is on screen and
/// clear of the bottom navigation bar that the shell draws over the body.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final scrollable = find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
      .first;
  for (var i = 0; i < 60 && target.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pump();
  }
  final viewHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final clearBottom = viewHeight - 140; // nav bar + mini-player
  final y = tester.getCenter(target.first).dy;
  // A drag shorter than the touch slop is a TAP on whatever is under it.
  if (y > clearBottom + 24) {
    await tester.drag(scrollable, Offset(0, clearBottom - y));
  }
  await _settle(tester, 4);
}

/// Scrolls every vertical scrollable to its end in screen-sized steps so each
/// lazily-built row is laid out (and any overflow in it reported).
Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable).evaluate().toList();
  for (final element in scrollables) {
    if (!element.mounted) continue;
    final position =
        ((element as StatefulElement).state as ScrollableState).position;
    if (position.axis != Axis.vertical) continue;
    for (var i = 0; i < 80 && position.pixels < position.maxScrollExtent; i++) {
      position.jumpTo(
        math.min(position.pixels + 500, position.maxScrollExtent),
      );
      await tester.pump();
    }
  }
}

Future<void> _push(WidgetTester tester, String path) async {
  final ctx = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(ctx).push(path));
  await _settle(tester);
}
