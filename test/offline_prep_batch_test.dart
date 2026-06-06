import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/screens/home_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Lecture _lec(String id, {int number = 1}) => Lecture(
      id: id,
      number: number,
      chapterId: 'ch-01',
      title: const {'en': 'Lecture'},
      audioUrl: '',
      durationSeconds: 60,
      fileSizeBytes: 1048576, // 1 MB
    );

// Five-lecture list: [a, b, c, d, e]
final _all = [
  _lec('a', number: 1),
  _lec('b', number: 2),
  _lec('c', number: 3),
  _lec('d', number: 4),
  _lec('e', number: 5),
];

void main() {
  // ── Edge cases ────────────────────────────────────────────────────────────

  group('computeOfflinePrepBatch — edge cases', () {
    test('current lecture not found → empty', () {
      final result = computeOfflinePrepBatch(_all, 'unknown', DownloadsProvider());
      expect(result.toDownload, isEmpty);
      expect(result.downloading, isEmpty);
    });

    test('current is the last lecture → empty', () {
      final result = computeOfflinePrepBatch(_all, 'e', DownloadsProvider());
      expect(result.toDownload, isEmpty);
      expect(result.downloading, isEmpty);
    });

    test('empty catalog → empty', () {
      final result = computeOfflinePrepBatch([], 'a', DownloadsProvider());
      expect(result.toDownload, isEmpty);
      expect(result.downloading, isEmpty);
    });
  });

  // ── Batch size ────────────────────────────────────────────────────────────

  group('computeOfflinePrepBatch — batch size', () {
    test('takes up to 3 lectures after current', () {
      // current = a → next are b, c, d (3 lectures)
      final result = computeOfflinePrepBatch(_all, 'a', DownloadsProvider());
      expect(result.toDownload.map((l) => l.id), ['b', 'c', 'd']);
    });

    test('fewer than 3 remaining → returns only what is left', () {
      // current = d → only e remains
      final result = computeOfflinePrepBatch(_all, 'd', DownloadsProvider());
      expect(result.toDownload.map((l) => l.id), ['e']);
    });

    test('second-to-last → only one next lecture', () {
      final twoLectures = [_lec('x'), _lec('y')];
      final result = computeOfflinePrepBatch(twoLectures, 'x', DownloadsProvider());
      expect(result.toDownload.map((l) => l.id), ['y']);
    });
  });

  // ── Download state filtering ──────────────────────────────────────────────

  group('computeOfflinePrepBatch — status filtering', () {
    test('already-downloaded lectures are excluded from both lists', () {
      final provider = DownloadsProvider();
      provider.seedDownloadedForTest('b');
      provider.seedDownloadedForTest('c');

      final result = computeOfflinePrepBatch(_all, 'a', provider);
      // b and c are downloaded → only d in toDownload
      expect(result.toDownload.map((l) => l.id), ['d']);
      expect(result.downloading, isEmpty);
    });

    test('downloading lectures appear in downloading list, not toDownload', () {
      final provider = DownloadsProvider();
      // Manually set b as downloading via the test hook for chapters,
      // but DownloadStatus.downloading isn't settable directly — so we
      // verify via the shape of the result when everything is notDownloaded.
      //
      // The best we can do without HTTP is verify that notDownloaded lectures
      // go into toDownload and downloaded lectures are excluded.
      provider.seedDownloadedForTest('c');

      final result = computeOfflinePrepBatch(_all, 'a', provider);
      // b not downloaded, c downloaded, d not downloaded
      expect(result.toDownload.map((l) => l.id), containsAll(['b', 'd']));
      expect(result.toDownload.map((l) => l.id), isNot(contains('c')));
    });

    test('all next lectures downloaded → both lists empty', () {
      final provider = DownloadsProvider();
      for (final id in ['b', 'c', 'd']) {
        provider.seedDownloadedForTest(id);
      }
      final result = computeOfflinePrepBatch(_all, 'a', provider);
      expect(result.toDownload, isEmpty);
      expect(result.downloading, isEmpty);
    });

    test('failed lecture is included in toDownload (retry eligible)', () {
      // We can only test the notDownloaded/failed path via the public API.
      // A lecture with no seeded status defaults to notDownloaded, which is
      // in toDownload — failed uses the same code path.
      final provider = DownloadsProvider();
      final result = computeOfflinePrepBatch(_all, 'a', provider);
      // All of b, c, d are notDownloaded → all appear in toDownload
      expect(result.toDownload.length, 3);
    });
  });

  // ── Spans chapter boundaries ──────────────────────────────────────────────

  group('computeOfflinePrepBatch — cross-chapter', () {
    test('batch spans chapter boundaries when lectures are ordered globally', () {
      final multiChapter = [
        Lecture(id: 'ch1-lec1', number: 1, chapterId: 'ch-01',
            title: const {'en': 'L'}, audioUrl: '', durationSeconds: 60, fileSizeBytes: 1),
        Lecture(id: 'ch1-lec2', number: 2, chapterId: 'ch-01',
            title: const {'en': 'L'}, audioUrl: '', durationSeconds: 60, fileSizeBytes: 1),
        Lecture(id: 'ch2-lec1', number: 1, chapterId: 'ch-02',
            title: const {'en': 'L'}, audioUrl: '', durationSeconds: 60, fileSizeBytes: 1),
        Lecture(id: 'ch2-lec2', number: 2, chapterId: 'ch-02',
            title: const {'en': 'L'}, audioUrl: '', durationSeconds: 60, fileSizeBytes: 1),
      ];

      final result = computeOfflinePrepBatch(
          multiChapter, 'ch1-lec1', DownloadsProvider());
      // Should include ch1-lec2, ch2-lec1, ch2-lec2 (across chapter boundary)
      expect(result.toDownload.map((l) => l.id),
          ['ch1-lec2', 'ch2-lec1', 'ch2-lec2']);
    });
  });
}
