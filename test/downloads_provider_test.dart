import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/saved_lecture_metadata.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake platform so the real `ConnectivityProvider()` constructor can be
/// exercised without a device — see connectivity_provider_test.dart for the
/// canonical version of this seam.
class _FakeConnectivityPlatform extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  _FakeConnectivityPlatform(this.checkResult);

  List<ConnectivityResult> checkResult;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => checkResult;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void close() => _controller.close();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Lecture _lec(
  String id, {
  int bytes = 1000,
  String chapterId = 'ch-01',
  String audioUrl = '',
}) =>
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

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('downloads_provider_test_');
    DownloadService.resetForTest(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // ── Wi-Fi only preference ─────────────────────────────────────────────────

  group('downloadOnWifiOnly', () {
    test('defaults to true', () {
      final provider = DownloadsProvider();
      expect(provider.downloadOnWifiOnly, isTrue);
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

  group('download failures', () {
    test('keeps failed status and exposes the typed transfer failure',
        () async {
      final provider = DownloadsProvider();

      await provider.download(_lec('bad-url', audioUrl: 'not a URL'));

      expect(provider.statusFor('bad-url'), DownloadStatus.failed);
      expect(provider.failureFor('bad-url'), isA<DownloadTransferException>());
    });
  });

  group('durable queue', () {
    test('queues every chapter request behind the same offline policy',
        () async {
      final provider = DownloadsProvider();
      final chapter = [
        _lec('chapter-policy-a'),
        _lec('chapter-policy-b'),
      ];

      final started = provider.downloadChapterNowOrQueue(
        chapterId: 'ch-01',
        lectures: chapter,
        isOnline: false,
        isWifi: false,
      );

      expect(started, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(provider.queuedDownloadCount, chapter.length);
    });

    test('deduplicates queue intent and restores it after provider restart',
        () async {
      final first = DownloadsProvider();
      final lecture = _lec('queued', audioUrl: 'not a URL');

      await first.queueDownload(lecture);
      await first.queueDownload(lecture);

      expect(first.queuedDownloadCount, 1);
      final restored = DownloadsProvider();
      await restored.load();
      expect(restored.queuedDownloadCount, 1);
    });

    test('starts restored work on a cold online launch', () async {
      final first = DownloadsProvider();
      await first.queueDownload(_lec('cold-start', audioUrl: 'not a URL'));

      final restored = DownloadsProvider();
      await restored.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restored.statusFor('cold-start'), DownloadStatus.failed);
    });

    test('leaves restored work queued on a confirmed-offline cold launch',
        () async {
      final first = DownloadsProvider();
      await first
          .queueDownload(_lec('offline-cold-start', audioUrl: 'not a URL'));

      final restored = DownloadsProvider(
        null,
        ConnectivityProvider.testOffline(),
      );
      await restored.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restored.statusFor('offline-cold-start'), DownloadStatus.queued);
      expect(restored.queuedDownloadCount, 1);
      expect(
        PreferencesService.instance.loadQueuedDownloads().single.id,
        'offline-cold-start',
      );
    });

    test(
        'does not attempt restored work before the real ConnectivityProvider '
        'confirms its first platform check', () async {
      // ConnectivityProvider.testOffline() sets its state synchronously in
      // the constructor, so it can never reproduce the real app-startup
      // race: the production ConnectivityProvider() constructor starts
      // optimistically online and only learns the true state after an
      // awaited platform-channel round trip. DownloadsProvider.load() is
      // called in the same synchronous provider-tree build as
      // ConnectivityProvider(), so it must not trust `isOnline` until that
      // first check actually resolves — otherwise a genuinely offline cold
      // launch still attempts (and fails) restored work.
      final fake = _FakeConnectivityPlatform([ConnectivityResult.none]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final first = DownloadsProvider();
      await first.queueDownload(_lec('race-cold-start', audioUrl: 'not a URL'));

      // Mirrors lib/app.dart: both providers are constructed back-to-back
      // in the same synchronous provider-tree build, before
      // ConnectivityProvider's own async `_init()` has resolved.
      final connectivity = ConnectivityProvider();
      addTearDown(connectivity.dispose);
      final restored = DownloadsProvider(null, connectivity);
      await restored.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restored.statusFor('race-cold-start'), DownloadStatus.queued);
      expect(restored.queuedDownloadCount, 1);
    });

    test('cancels queued work durably before it starts', () async {
      final provider = DownloadsProvider();
      await provider.queueDownload(_lec('cancel-queued'));

      expect(provider.cancelDownload('cancel-queued'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(provider.queuedDownloadCount, 0);
      expect(
        PreferencesService.instance.loadQueuedDownloads(),
        isEmpty,
      );
    });

    test('delete clears queued intent when removing an unstarted request',
        () async {
      final provider = DownloadsProvider();
      await provider.queueDownload(_lec('queued-then-deleted'));
      expect(provider.queuedDownloadCount, 1);

      await provider.delete('queued-then-deleted');

      expect(provider.queuedDownloadCount, 0);
      expect(PreferencesService.instance.loadQueuedDownloads(), isEmpty);
    });

    test('deleteAll clears queued work in memory and preferences', () async {
      final provider = DownloadsProvider();
      await provider.queueDownload(_lec('delete-all-queued-a'));
      await provider.queueDownload(_lec('delete-all-queued-b'));

      await provider.deleteAll();

      expect(provider.queuedDownloadCount, 0);
      expect(PreferencesService.instance.loadQueuedDownloads(), isEmpty);
    });

    test('reconciles every queued chapter job after a provider restart',
        () async {
      final chapter = [
        _lec('chapter-a', chapterId: 'chapter-queued', audioUrl: 'not a URL'),
        _lec('chapter-b', chapterId: 'chapter-queued', audioUrl: 'not a URL'),
        _lec('chapter-c', chapterId: 'chapter-queued', audioUrl: 'not a URL'),
      ];
      final first = DownloadsProvider();

      await first.downloadChapter('chapter-queued', chapter);
      expect(first.queuedDownloadCount, chapter.length);

      // Model the narrow crash window after atomic file promotion but before
      // its preferences write. The restarted provider must adopt this file,
      // not download it a second time or lose the other queued jobs.
      final promoted = File(DownloadService.localPath('chapter-b'));
      await promoted.parent.create(recursive: true);
      await promoted.writeAsBytes(List.filled(1000, 0));

      // A new provider models process restart: no in-memory chapter state
      // survives, but the durable jobs do. Retrying them neither drops nor
      // duplicates the three chapter requests when their transfer fails.
      final restored = DownloadsProvider();
      await restored.load();
      expect(restored.isDownloaded('chapter-b'), isTrue);
      expect(restored.queuedDownloadCount, chapter.length - 1);
      await restored.tryStartQueuedDownload(isOnline: true, isWifi: true);
      expect(restored.queuedDownloadCount, chapter.length - 1);
    });

    test(
        'persists a reconciled downloaded-id set even when its size matches '
        'the old one', () async {
      // old-a's file is missing (dropped) while queued-c's file already
      // exists on disk (promoted, adopted) — the reconciled set has the same
      // *count* as the original persisted set but different *members*. A
      // count-only comparison would wrongly skip persisting the correction.
      const oldA = SavedLectureMetadata(
        id: 'old-a',
        number: 1,
        chapterId: 'ch-01',
        title: {'en': 'Old A'},
        audioUrl: 'https://example.test/old-a.mp3',
        durationSeconds: 60,
        fileSizeBytes: 100,
      );
      const oldB = SavedLectureMetadata(
        id: 'old-b',
        number: 2,
        chapterId: 'ch-01',
        title: {'en': 'Old B'},
        audioUrl: 'https://example.test/old-b.mp3',
        durationSeconds: 60,
        fileSizeBytes: 100,
      );
      const queuedC = SavedLectureMetadata(
        id: 'queued-c',
        number: 3,
        chapterId: 'ch-01',
        title: {'en': 'Queued C'},
        audioUrl: 'https://example.test/queued-c.mp3',
        durationSeconds: 60,
        fileSizeBytes: 100,
      );

      await File(DownloadService.localPath('old-b'))
          .create(recursive: true)
          .then((f) => f.writeAsBytes(List.filled(100, 0)));
      await File(DownloadService.localPath('queued-c'))
          .create(recursive: true)
          .then((f) => f.writeAsBytes(List.filled(100, 0)));

      await PreferencesService.instance.saveDownloadedIds({'old-a', 'old-b'});
      await PreferencesService.instance.saveDownloadedMetadata([oldA, oldB]);
      await PreferencesService.instance.saveQueuedDownloads([queuedC]);

      final first = DownloadsProvider();
      await first.load();
      // The first load's in-memory state is already correct...
      expect(first.isDownloaded('queued-c'), isTrue);
      expect(first.isDownloaded('old-a'), isFalse);

      // ...but a second restart must still see it: proves the correction
      // was actually persisted, not just held in the first provider's
      // memory.
      final second = DownloadsProvider();
      await second.load();
      expect(second.isDownloaded('queued-c'), isTrue);
      expect(second.isDownloaded('old-a'), isFalse);
      expect(second.isDownloaded('old-b'), isTrue);
    });
  });

  group('local-file recovery', () {
    test('keeps a corrupt saved file as unavailable instead of playable',
        () async {
      const row = SavedLectureMetadata(
        id: 'corrupt',
        number: 1,
        chapterId: 'ch-01',
        title: {'en': 'Corrupt'},
        audioUrl: 'https://example.test/corrupt.mp3',
        durationSeconds: 60,
        fileSizeBytes: 100,
      );
      final path = DownloadService.localPath('corrupt');
      await File(path).parent.create(recursive: true);
      await File(path).writeAsBytes(List.filled(10, 0));
      await PreferencesService.instance.saveDownloadedIds({'corrupt'});
      await PreferencesService.instance.saveDownloadedMetadata([row]);

      final provider = DownloadsProvider();
      await provider.load();

      expect(provider.isDownloaded('corrupt'), isFalse);
      expect(provider.isUnavailable('corrupt'), isTrue);
      expect(provider.unavailableMetadata.single.id, 'corrupt');
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

    test('cancelChapterDownload is a no-op when chapter is not downloading',
        () {
      final provider = DownloadsProvider();
      expect(
        () => provider.cancelChapterDownload('ch-01'),
        returnsNormally,
      );
      expect(provider.isChapterDownloading('ch-01'), isFalse);
    });
  });
}
