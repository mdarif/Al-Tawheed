import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2.4.1 -> 2.4.2 upgrade proof, part 1: MIGRATION DURABILITY, in process.
//
// What an upgrading user already has on disk is whatever 2.4.1 wrote. These
// tests seed exactly that — the raw SharedPreferences keys and the download
// file layout of the 2.4.1 tag — and then construct the 2.4.2 persistence layer
// and providers FRESH over it, tear them down, and construct them again.
//
// The seed is written as literal key strings, NOT through today's
// PreferencesService, so a renamed key in 2.4.2 cannot quietly rename the
// fixture with it. The shapes come from:
//
//   git show 2.4.1:lib/services/preferences_service.dart
//   git show 2.4.1:lib/services/download_service.dart   (_localPathFor)
//
// Part 2 (a real process restart, which cannot be modelled in-process because
// AudioService initialises once per process) is the manual step in
// docs/release-runbook.md, "Upgrade proof: real process restart".

// ── The 2.4.1 fixture ────────────────────────────────────────────────────────

/// Bytes of each seeded audio file; the catalogue below reports the same size.
const _audioBytes = 4096;

/// 2.4.1 wrote one ID-only list per concern and no per-lecture metadata at all
/// (`bookmark_metadata`, `downloaded_metadata`, `queued_downloads` and
/// `last_chapter_id` are all new in 2.4.2).
Map<String, Object> _prefs241({
  Object bookFontSize = 26.0,
  bool withSelectedSeries = true,
}) =>
    {
      // Edition + onboarding
      if (withSelectedSeries) 'selected_series_id': 'tawheed-ur',
      'has_completed_onboarding': true,
      'seen_welcome_series_ids': ['tawheed-ur'],
      // Progress: per-lecture seconds, plus the "last played" pair.
      'progress_lec-001': 1700,
      'progress_lec-002': 95,
      'last_lecture_id': 'lec-002',
      'last_position': 95,
      // Bookmarks: IDs only.
      'bookmarks': ['lec-002', 'lec-004'],
      // Study mode
      'studied_chapter_ids': ['ch-01'],
      // Reading: font size + one JSON map of chapter id -> pixel offset.
      'book_font_size': bookFontSize,
      'book_scroll_offsets': jsonEncode({'ch-01': 812.5, 'ch-02': 40.0}),
      // Downloads: IDs only (+ the Wi-Fi switch).
      'downloaded_lecture_ids': ['lec-001', 'lec-002', 'lec-gone'],
      'download_wifi_only': false,
      // Chrome preferences
      'app_language': 'roman',
      'theme_mode': 'light',
      'playback_speed': 1.25,
    };

/// A two-lecture slice of the catalogue, with the audio sizes the files on
/// disk really have.
Catalog _catalog({int fileSizeBytes = _audioBytes}) => Catalog.fromJson({
      'version': 1,
      'book': {
        'id': 'tawheed-ur',
        'title': {'en': 'Kitab at-Tawheed'},
        'titleArabic': '',
        'speaker': {'en': 'Speaker'},
        'totalDurationSeconds': 4000,
        'lectureCount': 4,
        'coverImageUrl': '',
        'language': 'Urdu',
      },
      'chapters': [
        {
          'id': 'ch-01',
          'number': 1,
          'title': {'en': 'Class 01'},
          'lectureCount': 4,
        },
      ],
      'lectures': [
        for (var i = 1; i <= 4; i++)
          {
            'id': 'lec-00$i',
            'number': i,
            'chapterId': 'ch-01',
            'title': {'en': 'Class 01 — Part 0$i'},
            'audioUrl': 'https://example.com/lec-00$i.mp3',
            'durationSeconds': 1000,
            'fileSizeBytes': fileSizeBytes,
          },
      ],
      'dailyBenefits': <Map<String, dynamic>>[],
    });

/// 2.4.1's layout for the default series: `{docs}/audio/{id}.mp3`.
Future<void> _writeAudio241(Directory docs, String id) async {
  final file = File('${docs.path}/audio/$id.mp3');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(List.filled(_audioBytes, 7));
}

// ── The 2.4.2 app, constructed fresh over what 2.4.1 left ────────────────────

class _App {
  _App._(
    this.series,
    this.progress,
    this.reading,
    this.downloads,
    this.language,
    this.theme,
  );

  final SeriesProvider series;
  final ProgressProvider progress;
  final ReadingProvider reading;
  final DownloadsProvider downloads;
  final LanguageProvider language;
  final ThemeProvider theme;

  /// A new process's startup: re-read preferences from the (persisted) store,
  /// then construct and load every provider, in app.dart's order.
  static Future<_App> launch({bool multiSeries = true}) async {
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();

    final series = SeriesProvider()..load(multiSeries, definitive: true);
    final progress = ProgressProvider(series)..load();
    final reading = ReadingProvider(series)..load();
    final downloads = DownloadsProvider(series);
    await downloads.load();
    final language = LanguageProvider()..load();
    final theme = ThemeProvider()..load();
    return _App._(series, progress, reading, downloads, language, theme);
  }

  void dispose() {
    series.dispose();
    progress.dispose();
    reading.dispose();
    downloads.dispose();
    language.dispose();
    theme.dispose();
  }
}

/// Everything the upgrade must preserve, as plain comparable values.
Map<String, Object?> _snapshot(_App app) => {
      'edition': app.series.currentSeries.id,
      'hasSelectedSeries': app.series.hasSelectedSeries,
      'onboarded': app.series.hasCompletedOnboarding,
      'showWelcome': app.series.shouldShowWelcomeForCurrentSeries,
      'lastLectureId': app.progress.lastLectureId,
      'lastPosition': app.progress.lastPositionSeconds,
      'lec001': app.progress.getPositionSeconds('lec-001'),
      'lec002': app.progress.getPositionSeconds('lec-002'),
      'lec003': app.progress.getPositionSeconds('lec-003'),
      'bookmarks': (app.progress.bookmarkedIds.toList()..sort()),
      'bookmarkRows':
          (app.progress.bookmarkedMetadata.map((row) => row.id).toList()
            ..sort()),
      'fontSize': app.reading.bookFontSize,
      'scrollCh01': app.reading.bookScrollOffsetFor('ch-01'),
      'scrollCh02': app.reading.bookScrollOffsetFor('ch-02'),
      'lastChapterId': app.reading.lastChapterId,
      'downloadedIds': (app.downloads.downloadedIds.toList()..sort()),
      'downloadedRows':
          (app.downloads.downloadedMetadata.map((row) => row.id).toList()
            ..sort()),
      'downloadedBytes': app.downloads.totalDownloadedBytes,
      'lec001Path': app.downloads.localPathIfDownloaded('lec-001'),
      'lec003Path': app.downloads.localPathIfDownloaded('lec-003'),
      'wifiOnly': app.downloads.downloadOnWifiOnly,
      'language': app.language.language.code,
      'theme': app.theme.themeMode,
      'speed': PreferencesService.instance.playbackSpeed,
      'studied': PreferencesService.instance.loadStudiedChapterIds().toList(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('upgrade_from_2_4_1_');
    DownloadService.resetForTest(docs.path);
    SharedPreferences.setMockInitialValues(_prefs241());
    await _writeAudio241(docs, 'lec-001');
    await _writeAudio241(docs, 'lec-002');
    // 'lec-gone' is in downloaded_lecture_ids but its file is not on disk, as
    // after a user cleared storage: 2.4.1 reconciled such ids away too.
  });

  tearDown(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  group('2.4.1 -> 2.4.2 migration durability', () {
    test('every 2.4.1 value reads correctly through the 2.4.2 providers',
        () async {
      final app = await _App.launch();
      addTearDown(app.dispose);

      // Edition + onboarding: a returning user lands on Lectures, never on the
      // welcome / series picker.
      expect(app.series.currentSeries.id, 'tawheed-ur');
      expect(app.series.hasSelectedSeries, isTrue);
      expect(app.series.hasCompletedOnboarding, isTrue);
      expect(app.series.shouldShowWelcomeForCurrentSeries, isFalse);
      expect(app.series.isSeriesReady, isTrue);

      // Progress.
      expect(app.progress.getPositionSeconds('lec-001'), 1700);
      expect(app.progress.getPositionSeconds('lec-002'), 95);
      expect(app.progress.getPositionSeconds('lec-003'), 0);
      expect(app.progress.lastLectureId, 'lec-002');
      expect(app.progress.lastPositionSeconds, 95);
      expect(app.progress.getFraction('lec-001', 3400), 0.5);

      // Bookmarks: the ids survive even though no row metadata exists yet.
      expect(app.progress.bookmarkedIds, {'lec-002', 'lec-004'});
      expect(app.progress.isBookmarked('lec-002'), isTrue);
      expect(app.progress.bookmarkedMetadata, isEmpty);

      // Reading.
      expect(app.reading.bookFontSize, 26.0);
      expect(app.reading.bookScrollOffsetFor('ch-01'), 812.5);
      expect(app.reading.bookScrollOffsetFor('ch-02'), 40.0);
      expect(app.reading.lastChapterId, isNull, reason: 'new in 2.4.2');

      // Downloads: the two files that exist are downloaded and playable from
      // their 2.4.1 path; the id whose file is gone is reconciled away.
      expect(app.downloads.downloadedIds, {'lec-001', 'lec-002'});
      expect(app.downloads.isDownloaded('lec-001'), isTrue);
      expect(app.downloads.isDownloaded('lec-gone'), isFalse);
      expect(app.downloads.totalDownloadedBytes, 2 * _audioBytes);
      final path = app.downloads.localPathIfDownloaded('lec-001')!;
      expect(path, '${docs.path}/audio/lec-001.mp3');
      expect(File(path).existsSync(), isTrue);
      expect(app.downloads.downloadedMetadata, isEmpty);
      expect(app.downloads.downloadOnWifiOnly, isFalse);

      // Chrome preferences + study progress.
      expect(app.language.language, AppLanguage.romanUrdu);
      expect(app.theme.themeMode, ThemeMode.light);
      expect(PreferencesService.instance.playbackSpeed, 1.25);
      expect(PreferencesService.instance.loadStudiedChapterIds(), {'ch-01'});
    });

    test('a second launch over the same store reads identically', () async {
      final first = await _App.launch();
      final before = _snapshot(first);
      first.dispose();

      final second = await _App.launch();
      addTearDown(second.dispose);

      expect(_snapshot(second), before);
    });

    test(
        'metadata backfill (first catalogue after upgrade) upgrades ids to '
        'rows, persists them, and a later launch still reads everything',
        () async {
      final catalog = _catalog();

      final first = await _App.launch();
      await first.progress.backfillBookmarkMetadata(catalog.lectures);
      await first.downloads.backfillDownloadedMetadata(catalog.lectures);
      expect(first.progress.bookmarkedMetadata.map((r) => r.id).toSet(), {
        'lec-002',
        'lec-004',
      });
      expect(
        first.downloads.downloadedMetadata.map((r) => r.id).toSet(),
        {'lec-001', 'lec-002'},
      );
      final backfilled = _snapshot(first);
      first.dispose();

      // The rows are now on disk. This launch reads them back, and the
      // download reconcile now also checks each file against the row's size.
      final second = await _App.launch();
      addTearDown(second.dispose);

      expect(_snapshot(second), backfilled);
      expect(second.downloads.isDownloaded('lec-001'), isTrue);
      expect(second.downloads.isDownloaded('lec-002'), isTrue);
      expect(second.progress.bookmarkedMetadata, hasLength(2));
      // The row is enough to play from, with no catalogue at all.
      final row = second.downloads.downloadedMetadata
          .singleWhere((r) => r.id == 'lec-001');
      expect(row.toLecture().audioUrl, 'https://example.com/lec-001.mp3');
    });

    test(
        'a 2.4.1 file whose size differs from the catalogue is KEPT: it '
        'survives backfill and later launches, on disk and playable', () async {
      // 2.4.1 never compared a finished file to the catalogue size (it was a
      // progress estimate only), so a catalogue/CDN disagreement is not
      // evidence the file is broken. Re-encoded CDN audio must never cost an
      // upgrading user the downloads they already paid data for.
      final catalog = _catalog(fileSizeBytes: _audioBytes + 1000);

      final first = await _App.launch();
      await first.downloads.backfillDownloadedMetadata(catalog.lectures);
      expect(first.downloads.isDownloaded('lec-001'), isTrue);
      first.dispose();

      for (var launch = 2; launch <= 3; launch++) {
        final app = await _App.launch();

        for (final id in ['lec-001', 'lec-002']) {
          expect(
            app.downloads.isDownloaded(id),
            isTrue,
            reason: '$id, launch $launch',
          );
          expect(app.downloads.isUnavailable(id), isFalse, reason: id);
          final path = app.downloads.localPathIfDownloaded(id);
          expect(path, '${docs.path}/audio/$id.mp3');
          expect(File(path!).existsSync(), isTrue, reason: '$id on disk');
          expect(File(path).lengthSync(), _audioBytes, reason: 'untouched');
        }
        expect(app.downloads.downloadedMetadata.map((r) => r.id).toSet(), {
          'lec-001',
          'lec-002',
        });
        expect(app.downloads.totalDownloadedBytes, 2 * _audioBytes);
        app.dispose();
      }
    });

    test('Arabic-prefixed 2.4.1 state is read from its own `ar_` keys',
        () async {
      SharedPreferences.setMockInitialValues({
        ..._prefs241(),
        'selected_series_id': 'tawheed-ar',
        'seen_welcome_series_ids': ['tawheed-ur', 'tawheed-ar'],
        'ar_progress_ar-001': 33,
        'ar_last_lecture_id': 'ar-001',
        'ar_last_position': 33,
        'ar_bookmarks': ['ar-001'],
        'ar_downloaded_lecture_ids': ['ar-001'],
      });
      // 2.4.1 laid a non-default edition out as {docs}/audio/{seriesId}/{id}.mp3
      final file = File('${docs.path}/audio/tawheed-ar/ar-001.mp3');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.filled(_audioBytes, 9));

      PreferencesService.instance.resetForTest();
      await PreferencesService.instance.init();
      const arabic = SeriesConfig(
        id: 'tawheed-ar',
        catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
        storagePrefix: 'ar_',
        hasStudyMode: false,
        hasBook: true,
        language: 'ar',
        displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
        speakerName: {'en': 'Speaker'},
      );
      final series = SeriesProvider()
        ..setAvailableSeriesForTest(const [
          SeriesConfig.legacyUrduFallback,
          arabic,
        ])
        ..load(true, definitive: true);
      addTearDown(series.dispose);
      final progress = ProgressProvider(series)..load();
      addTearDown(progress.dispose);
      final reading = ReadingProvider(series)..load();
      addTearDown(reading.dispose);
      final downloads = DownloadsProvider(series);
      addTearDown(downloads.dispose);
      await downloads.load();

      expect(series.currentSeries.id, 'tawheed-ar');
      expect(series.shouldShowWelcomeForCurrentSeries, isFalse);
      expect(progress.lastLectureId, 'ar-001');
      expect(progress.getPositionSeconds('ar-001'), 33);
      expect(progress.bookmarkedIds, {'ar-001'});
      expect(downloads.isDownloaded('ar-001'), isTrue);
      expect(
        downloads.localPathIfDownloaded('ar-001'),
        '${docs.path}/audio/tawheed-ar/ar-001.mp3',
      );
      // Not carried over: the Urdu edition's progress must not leak into it.
      expect(progress.getPositionSeconds('lec-001'), 0);
      // 2.4.1 kept ONE unscoped `book_scroll_offsets` for every edition (a
      // cross-edition leak fixed in 2.4.2), so the Arabic edition starts its
      // reading positions afresh rather than inheriting Urdu's.
      expect(reading.bookScrollOffsetFor('ch-01'), 0);
    });

    test(
        'an install that predates multi-series (no selected_series_id) is '
        'still pinned to Urdu and skips the welcome', () async {
      SharedPreferences.setMockInitialValues(
        _prefs241(withSelectedSeries: false)..remove('seen_welcome_series_ids'),
      );

      final app = await _App.launch();
      addTearDown(app.dispose);

      expect(app.series.hasSelectedSeries, isTrue);
      expect(app.series.currentSeries.id, 'tawheed-ur');
      expect(app.series.shouldShowWelcomeForCurrentSeries, isFalse);
      expect(PreferencesService.instance.selectedSeriesId, 'tawheed-ur');
    });

    test(
        'control: an empty store is a fresh install, so the seed is what '
        'the assertions above are reading', () async {
      SharedPreferences.setMockInitialValues({});

      final app = await _App.launch();
      addTearDown(app.dispose);

      expect(app.series.hasSelectedSeries, isFalse);
      expect(app.series.shouldShowWelcomeForCurrentSeries, isTrue);
      expect(app.progress.lastLectureId, isNull);
      expect(app.progress.bookmarkedIds, isEmpty);
      expect(app.downloads.downloadedIds, isEmpty);
      expect(app.reading.bookFontSize, ReadingProvider.defaultBookFontSize);
    });
  });

  group('2.4.1 font size is clamped into the 2.4.2 range', () {
    final cases = <String, (Object, double)>{
      'below the minimum': (8.0, ReadingProvider.minBookFontSize),
      'above the maximum': (99.0, ReadingProvider.maxBookFontSize),
      'non-finite': (double.nan, ReadingProvider.defaultBookFontSize),
      'inside the range, untouched': (14.0, 14.0),
    };
    cases.forEach((name, c) {
      test(name, () async {
        SharedPreferences.setMockInitialValues(_prefs241(bookFontSize: c.$1));

        final app = await _App.launch();
        addTearDown(app.dispose);

        expect(app.reading.bookFontSize, c.$2);
        // Restoring never needs to write: the stored value is corrected in
        // memory on every read, and a rebuilt provider agrees.
        final again = await _App.launch();
        addTearDown(again.dispose);
        expect(again.reading.bookFontSize, c.$2);
      });
    });
  });
}
