import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Lecture _lec(String id,
        {int bytes = 1000, String chapterId = 'ch-01', String audioUrl = '',}) =>
    Lecture(
      id: id,
      number: 1,
      chapterId: chapterId,
      title: const {'en': 'Test lecture'},
      audioUrl: audioUrl,
      durationSeconds: 60,
      fileSizeBytes: bytes,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  // ── Wi-Fi only preference ─────────────────────────────────────────────────

  group('downloadOnWifiOnly', () {
    test('defaults to false', () {
      final provider = DownloadsProvider();
      expect(provider.downloadOnWifiOnly, isFalse);
    });

    test('setDownloadOnWifiOnly(true) persists and is readable', () async {
      final provider = DownloadsProvider();
      await provider.setDownloadOnWifiOnly(true);
      expect(provider.downloadOnWifiOnly, isTrue);
    });

    test('round-trips back to false', () async {
      final provider = DownloadsProvider();
      await provider.setDownloadOnWifiOnly(true);
      await provider.setDownloadOnWifiOnly(false);
      expect(provider.downloadOnWifiOnly, isFalse);
    });

    test('notifies listeners when changed', () async {
      final provider = DownloadsProvider();
      var fired = 0;
      provider.addListener(() => fired++);
      await provider.setDownloadOnWifiOnly(true);
      expect(fired, 1);
    });
  });

  // ── isChapterFullyDownloaded ──────────────────────────────────────────────

  group('isChapterFullyDownloaded', () {
    test('empty lecture list → false', () {
      expect(DownloadsProvider().isChapterFullyDownloaded([]), isFalse);
    });

    test('none downloaded → false', () {
      final provider = DownloadsProvider();
      expect(
        provider.isChapterFullyDownloaded([_lec('a'), _lec('b')]),
        isFalse,
      );
    });

    test('partial download → false', () {
      final provider = DownloadsProvider();
      provider.seedDownloadedForTest('a');
      expect(
        provider.isChapterFullyDownloaded([_lec('a'), _lec('b')]),
        isFalse,
      );
    });

    test('all downloaded → true', () {
      final provider = DownloadsProvider();
      provider.seedDownloadedForTest('a');
      provider.seedDownloadedForTest('b');
      expect(
        provider.isChapterFullyDownloaded([_lec('a'), _lec('b')]),
        isTrue,
      );
    });
  });

  // ── chapterDownloadedCount ────────────────────────────────────────────────

  group('chapterDownloadedCount', () {
    test('zero when nothing downloaded', () {
      expect(
        DownloadsProvider().chapterDownloadedCount([_lec('a'), _lec('b')]),
        0,
      );
    });

    test('counts only lectures with downloaded status', () {
      final provider = DownloadsProvider();
      final lectures = [_lec('a'), _lec('b'), _lec('c')];
      provider.seedDownloadedForTest('a');
      provider.seedDownloadedForTest('c');
      expect(provider.chapterDownloadedCount(lectures), 2);
    });
  });

  // ── chapterTotalBytes ─────────────────────────────────────────────────────

  group('chapterTotalBytes', () {
    test('empty list → 0', () {
      expect(DownloadsProvider().chapterTotalBytes([]), 0);
    });

    test('sums all lectures regardless of download status', () {
      final provider = DownloadsProvider();
      final lectures = [_lec('a', bytes: 1000), _lec('b', bytes: 2000)];
      provider.seedDownloadedForTest('a'); // only one downloaded
      expect(provider.chapterTotalBytes(lectures), 3000);
    });
  });

  // ── chapterDownloadedBytes ────────────────────────────────────────────────

  group('chapterDownloadedBytes', () {
    test('zero when nothing downloaded', () {
      expect(
        DownloadsProvider().chapterDownloadedBytes([_lec('a', bytes: 5000)]),
        0,
      );
    });

    test('sums only downloaded lectures', () {
      final provider = DownloadsProvider();
      final lectures = [
        _lec('a', bytes: 1000),
        _lec('b', bytes: 2000),
        _lec('c', bytes: 500),
      ];
      provider.seedDownloadedForTest('a');
      provider.seedDownloadedForTest('c');
      expect(provider.chapterDownloadedBytes(lectures), 1500);
    });
  });

  // ── isChapterDownloading ──────────────────────────────────────────────────

  group('isChapterDownloading', () {
    test('false when chapter has not been seeded as downloading', () {
      expect(DownloadsProvider().isChapterDownloading('ch-01'), isFalse);
    });

    test('true after seedChapterDownloadingForTest', () {
      final provider = DownloadsProvider();
      provider.seedChapterDownloadingForTest('ch-01');
      expect(provider.isChapterDownloading('ch-01'), isTrue);
    });

    test('cancelChapterDownload is a no-op when chapter is not downloading', () {
      final provider = DownloadsProvider();
      expect(
        () => provider.cancelChapterDownload('ch-01'),
        returnsNormally,
      );
      expect(provider.isChapterDownloading('ch-01'), isFalse);
    });
  });
}
