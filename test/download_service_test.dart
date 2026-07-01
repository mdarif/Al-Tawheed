import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/download_service.dart';

Future<({HttpServer server, String baseUrl})> _startServer(
  int totalBytes, {
  Duration chunkDelay = Duration.zero,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.host}:${server.port}';

  server.listen((request) async {
    final chunks = (totalBytes / 64).ceil();
    var sent = 0;
    for (var i = 0; i < chunks; i++) {
      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }
      final remaining = totalBytes - sent;
      final size = remaining < 64 ? remaining : 64;
      request.response.add(List<int>.filled(size, 1));
      sent += size;
    }
    await request.response.close();
  });

  return (server: server, baseUrl: baseUrl);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_test_');
    DownloadService.resetForTest(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('completes download and writes file', () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/lec-1.mp3';
    var lastProgress = 0.0;

    await DownloadService.download(
      cancelKey: 'lec-1',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (p) => lastProgress = p,
    );

    expect(await File(savePath).exists(), isTrue);
    expect(await File(savePath).length(), 256);
    expect(lastProgress, 1.0);
  });

  test('cancel aborts transfer, deletes partial file, throws DownloadCancelled',
      () async {
    final (:server, :baseUrl) = await _startServer(
      4096,
      chunkDelay: const Duration(milliseconds: 20),
    );
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/lec-2.mp3';

    final done = DownloadService.download(
      cancelKey: 'lec-2',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 4096,
      onProgress: (_) {},
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    DownloadService.cancel('lec-2');

    await expectLater(done, throwsA(isA<DownloadCancelled>()));
    expect(await File(savePath).exists(), isFalse);
  });

  test('delete cancels an active download', () async {
    final (:server, :baseUrl) = await _startServer(
      4096,
      chunkDelay: const Duration(milliseconds: 20),
    );
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/lec-3.mp3';

    final done = DownloadService.download(
      cancelKey: 'lec-3',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 4096,
      onProgress: (_) {},
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    await DownloadService.delete('lec-3');

    await expectLater(done, throwsA(isA<DownloadCancelled>()));
    expect(await File(savePath).exists(), isFalse);
  });

  group('path-traversal defense', () {
    test('isSafePathSegment accepts real ids, rejects traversal', () {
      expect(isSafePathSegment('l1'), isTrue);
      expect(isSafePathSegment('tawheed-ur'), isTrue);
      expect(isSafePathSegment('dars_01'), isTrue);

      expect(isSafePathSegment('..'), isFalse);
      expect(isSafePathSegment('.'), isFalse);
      expect(isSafePathSegment('../evil'), isFalse);
      expect(isSafePathSegment('a/b'), isFalse);
      expect(isSafePathSegment(r'a\b'), isFalse);
      expect(isSafePathSegment(''), isFalse);
      expect(isSafePathSegment('with space'), isFalse);
    });

    test('localPath throws on a traversal lecture id', () {
      expect(
        () => DownloadService.localPath('../../databases/x'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('localPath throws on a traversal series id', () {
      expect(
        () => DownloadService.localPath('l1', seriesId: '../evil'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('localPath still resolves safe ids under the audio/ directory', () {
      final legacy = DownloadService.localPath('l1');
      expect(legacy, '${tempDir.path}/audio/l1.mp3');

      final scoped = DownloadService.localPath('l1', seriesId: 'tawheed-ar');
      expect(scoped, '${tempDir.path}/audio/tawheed-ar/l1.mp3');
    });

    test('reconcileDownloadedIds skips unsafe ids', () async {
      // Create a real file for a safe id (scoped-series layout) so it
      // reconciles as present.
      final safe = File('${tempDir.path}/audio/tawheed-ar/keep.mp3');
      await safe.parent.create(recursive: true);
      await safe.writeAsBytes([1, 2, 3]);

      final result = await reconcileDownloadedIds(
        (['keep', '../../etc/passwd', 'a/b'], tempDir.path, 'tawheed-ar'),
      );

      expect(result, {'keep'});
    });
  });

  group('byte accounting', () {
    test('fileSizeSync returns on-disk size, 0 for missing/unsafe', () async {
      final f = File('${tempDir.path}/audio/tawheed-ar/l1.mp3');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(List<int>.filled(1234, 0));

      expect(DownloadService.fileSizeSync('l1', seriesId: 'tawheed-ar'), 1234);
      expect(DownloadService.fileSizeSync('missing', seriesId: 'tawheed-ar'), 0);
      expect(DownloadService.fileSizeSync('../evil'), 0);
    });

    test('totalBytesForIds sums present files and skips unsafe ids', () async {
      final a = File('${tempDir.path}/audio/tawheed-ar/a.mp3');
      await a.parent.create(recursive: true);
      await a.writeAsBytes(List<int>.filled(100, 0));
      final b = File('${tempDir.path}/audio/tawheed-ar/b.mp3');
      await b.writeAsBytes(List<int>.filled(50, 0));

      final total = totalBytesForIds(
        (['a', 'b', 'missing', '../evil'], tempDir.path, 'tawheed-ar'),
      );

      expect(total, 150);
    });
  });
}
