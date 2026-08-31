import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/download_service.dart';

Future<({HttpServer server, String baseUrl})> _startServer(
  int totalBytes, {
  int? sentBytes,
  int? contentLength,
  int statusCode = HttpStatus.ok,
  Duration chunkDelay = Duration.zero,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.host}:${server.port}';

  server.listen((request) async {
    request.response.statusCode = statusCode;
    if (contentLength != null) {
      request.response.contentLength = contentLength;
    }
    final bytesToSend = sentBytes ?? totalBytes;
    final chunks = (bytesToSend / 64).ceil();
    var sent = 0;
    for (var i = 0; i < chunks; i++) {
      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }
      final remaining = bytesToSend - sent;
      final size = remaining < 64 ? remaining : 64;
      request.response.add(List<int>.filled(size, 1));
      sent += size;
    }
    await request.response.close();
  });

  return (server: server, baseUrl: baseUrl);
}

Future<({ServerSocket server, String baseUrl})>
    _startTruncatedContentLengthServer() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.host}:${server.port}';

  server.listen((socket) {
    var replied = false;
    socket.listen((_) async {
      if (replied) return;
      replied = true;
      socket.add(
        ascii.encode(
          'HTTP/1.1 200 OK\r\nContent-Length: 256\r\nConnection: close\r\n\r\n',
        ),
      );
      socket.add(List<int>.filled(128, 1));
      await socket.flush();
      await socket.close();
    });
  });

  return (server: server, baseUrl: baseUrl);
}

Future<List<FileSystemEntity>> _partFilesFor(String savePath) async {
  final parent = File(savePath).parent;
  if (!await parent.exists()) return const [];
  return parent
      .list()
      .where((entity) => entity.path.endsWith('.part'))
      .toList();
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

  test('does not promote a response shorter than the catalog byte count',
      () async {
    final (:server, :baseUrl) = await _startServer(256, sentBytes: 128);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/truncated.mp3';

    await expectLater(
      DownloadService.download(
        cancelKey: 'truncated',
        url: '$baseUrl/audio.mp3',
        savePath: savePath,
        fileSizeBytes: 256,
        onProgress: (_) {},
      ),
      throwsA(isA<DownloadIntegrityException>()),
    );

    expect(await File(savePath).exists(), isFalse);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('uses response Content-Length when the catalog byte count is unknown',
      () async {
    final (:server, :baseUrl) = await _startServer(256, contentLength: 256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/content-length.mp3';
    await DownloadService.download(
      cancelKey: 'content-length',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 0,
      onProgress: (_) {},
    );

    expect(await File(savePath).length(), 256);
  });

  test('fails closed when neither catalog bytes nor Content-Length is known',
      () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/unknown-length.mp3';
    await expectLater(
      DownloadService.download(
        cancelKey: 'unknown-length',
        url: '$baseUrl/audio.mp3',
        savePath: savePath,
        fileSizeBytes: 0,
        onProgress: (_) {},
      ),
      throwsA(isA<DownloadIntegrityException>()),
    );

    expect(await File(savePath).exists(), isFalse);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('does not promote a response shorter than its Content-Length', () async {
    final (:server, :baseUrl) = await _startTruncatedContentLengthServer();
    addTearDown(() => server.close());

    final savePath = '${tempDir.path}/audio/content-length-truncated.mp3';
    await expectLater(
      DownloadService.download(
        cancelKey: 'content-length-truncated',
        url: '$baseUrl/audio.mp3',
        savePath: savePath,
        fileSizeBytes: 0,
        onProgress: (_) {},
      ),
      throwsA(isA<DownloadIntegrityException>()),
    );

    expect(await File(savePath).exists(), isFalse);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('keeps an existing destination when verification fails', () async {
    final (:server, :baseUrl) = await _startServer(256, sentBytes: 128);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/existing.mp3';
    final existing = File(savePath);
    await existing.parent.create(recursive: true);
    await existing.writeAsBytes([7, 8, 9]);

    await expectLater(
      DownloadService.download(
        cancelKey: 'existing',
        url: '$baseUrl/audio.mp3',
        savePath: savePath,
        fileSizeBytes: 256,
        onProgress: (_) {},
      ),
      throwsA(isA<DownloadIntegrityException>()),
    );

    expect(await existing.readAsBytes(), [7, 8, 9]);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('keeps the old destination visible until atomic replacement', () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/atomic.mp3';
    final destination = File(savePath);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes([9, 9, 9]);
    final enteredPromotion = Completer<void>();
    final releasePromotion = Completer<void>();
    DownloadService.beforePromotionForTest = (_) async {
      enteredPromotion.complete();
      await releasePromotion.future;
    };

    final done = DownloadService.download(
      cancelKey: 'atomic',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    await enteredPromotion.future;

    expect(await destination.readAsBytes(), [9, 9, 9]);
    final partPath = DownloadService.activePartPathForTest(savePath);
    expect(partPath, isNotNull);
    expect(await File(partPath!).exists(), isTrue);

    releasePromotion.complete();
    await done;
    expect(await destination.length(), 256);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('does not expose a new destination before promotion', () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/invisible.mp3';
    final enteredPromotion = Completer<void>();
    final releasePromotion = Completer<void>();
    DownloadService.beforePromotionForTest = (_) async {
      enteredPromotion.complete();
      await releasePromotion.future;
    };

    final done = DownloadService.download(
      cancelKey: 'invisible',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    await enteredPromotion.future;

    expect(await File(savePath).exists(), isFalse);
    final partPath = DownloadService.activePartPathForTest(savePath);
    expect(partPath, isNotNull);
    expect(await File(partPath!).exists(), isTrue);

    releasePromotion.complete();
    await done;
    expect(await File(savePath).exists(), isTrue);
  });

  test('cancellation before promotion preserves an existing destination',
      () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/promotion-cancel.mp3';
    final destination = File(savePath);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes([4, 5, 6]);
    final enteredPromotion = Completer<void>();
    final releasePromotion = Completer<void>();
    DownloadService.beforePromotionForTest = (_) async {
      enteredPromotion.complete();
      await releasePromotion.future;
    };

    final done = DownloadService.download(
      cancelKey: 'promotion-cancel',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    final cancelled = expectLater(done, throwsA(isA<DownloadCancelled>()));
    await enteredPromotion.future;
    expect(DownloadService.cancel('promotion-cancel'), isTrue);
    await File(DownloadService.activePartPathForTest(savePath)!).delete();
    releasePromotion.complete();

    await cancelled;
    expect(await destination.readAsBytes(), [4, 5, 6]);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('cancellation after atomic rename leaves the successful file intact',
      () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/post-rename-cancel.mp3';
    final enteredAfterRename = Completer<void>();
    final releaseAfterRename = Completer<void>();
    DownloadService.afterPromotionForTest = (_) async {
      enteredAfterRename.complete();
      await releaseAfterRename.future;
    };

    final done = DownloadService.download(
      cancelKey: 'post-rename-cancel',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    await enteredAfterRename.future;

    expect(DownloadService.cancel('post-rename-cancel'), isFalse);
    releaseAfterRename.complete();
    await done;
    expect(await File(savePath).length(), 256);
  });

  test('immediate retry waits for the old operation before owning the path',
      () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/immediate-retry.mp3';
    final firstAtPartOpen = Completer<void>();
    final releaseFirst = Completer<void>();
    var partOpenCount = 0;
    DownloadService.beforePartFileOpenForTest = (_) async {
      if (partOpenCount++ == 0) {
        firstAtPartOpen.complete();
        await releaseFirst.future;
      }
    };
    final secondAtPromotion = Completer<void>();
    final releaseSecond = Completer<void>();
    DownloadService.beforePromotionForTest = (_) async {
      secondAtPromotion.complete();
      await releaseSecond.future;
    };

    final first = DownloadService.download(
      cancelKey: 'retry',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    final firstCancelled =
        expectLater(first, throwsA(isA<DownloadCancelled>()));
    await firstAtPartOpen.future;

    final second = DownloadService.download(
      cancelKey: 'retry',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    releaseFirst.complete();
    await firstCancelled;
    await secondAtPromotion.future;

    // The old finalizer has completed; this cancellation must still find the
    // second operation, proving it did not unregister the retry's ownership.
    expect(DownloadService.cancel('retry'), isTrue);
    releaseSecond.complete();
    await expectLater(second, throwsA(isA<DownloadCancelled>()));
    expect(await File(savePath).exists(), isFalse);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('two queued successors reserve distinct destination turns', () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/two-successors.mp3';
    final firstAtPartOpen = Completer<void>();
    final releaseFirst = Completer<void>();
    var partOpenCalls = 0;
    DownloadService.beforePartFileOpenForTest = (_) async {
      if (partOpenCalls++ == 0) {
        firstAtPartOpen.complete();
        await releaseFirst.future;
      }
    };

    final first = DownloadService.download(
      cancelKey: 'first',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    final firstCancelled =
        expectLater(first, throwsA(isA<DownloadCancelled>()));
    await firstAtPartOpen.future;

    // Both successors are queued before the old finalizer is released. The
    // second is cancelled by the newer request, so only the third can enter
    // the write hook. A snapshot-and-wait implementation runs both here.
    final second = DownloadService.download(
      cancelKey: 'second',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    final secondCancelled =
        expectLater(second, throwsA(isA<DownloadCancelled>()));
    final third = DownloadService.download(
      cancelKey: 'third',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );

    releaseFirst.complete();
    await Future.wait([firstCancelled, secondCancelled]);
    await third;

    expect(partOpenCalls, 2);
    expect(await File(savePath).length(), 256);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('queued delete completes before a retry claims its destination',
      () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    final savePath = '${tempDir.path}/audio/delete-then-retry.mp3';
    final destination = File(savePath);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes([9, 9, 9]);
    final firstAtPartOpen = Completer<void>();
    final releaseFirst = Completer<void>();
    var partOpenCalls = 0;
    DownloadService.beforePartFileOpenForTest = (_) async {
      if (partOpenCalls++ == 0) {
        firstAtPartOpen.complete();
        await releaseFirst.future;
      }
    };

    final first = DownloadService.download(
      cancelKey: 'delete-first',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );
    final firstCancelled =
        expectLater(first, throwsA(isA<DownloadCancelled>()));
    await firstAtPartOpen.future;

    final delete = DownloadService.delete(
      'delete-then-retry',
      cancelKey: 'delete-first',
    );
    final retry = DownloadService.download(
      cancelKey: 'delete-retry',
      url: '$baseUrl/audio.mp3',
      savePath: savePath,
      fileSizeBytes: 256,
      onProgress: (_) {},
    );

    releaseFirst.complete();
    await firstCancelled;
    await delete;
    await retry;

    expect(partOpenCalls, 2);
    expect(await destination.length(), 256);
    expect(await _partFilesFor(savePath), isEmpty);
  });

  test('classifies a CDN backoff response', () async {
    final (:server, :baseUrl) = await _startServer(
      0,
      statusCode: HttpStatus.tooManyRequests,
    );
    addTearDown(() => server.close(force: true));

    await expectLater(
      DownloadService.download(
        cancelKey: 'rate-limit',
        url: '$baseUrl/audio.mp3',
        savePath: '${tempDir.path}/audio/rate-limit.mp3',
        fileSizeBytes: 0,
        onProgress: (_) {},
      ),
      throwsA(
        isA<RateLimitedException>()
            .having((error) => error.statusCode, 'statusCode', 429),
      ),
    );
  });

  test('classifies a no-space write failure', () async {
    final (:server, :baseUrl) = await _startServer(256);
    addTearDown(() => server.close(force: true));

    DownloadService.beforePartFileOpenForTest = (partFile) async {
      throw FileSystemException(
        'write',
        partFile.path,
        OSError('No space left on device', 28),
      );
    };

    await expectLater(
      DownloadService.download(
        cancelKey: 'no-space',
        url: '$baseUrl/audio.mp3',
        savePath: '${tempDir.path}/audio/no-space.mp3',
        fileSizeBytes: 256,
        onProgress: (_) {},
      ),
      throwsA(isA<InsufficientStorageException>()),
    );
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
    expect(await _partFilesFor(savePath), isEmpty);
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

    // Attach the matcher NOW, not after the delete. `done` is deliberately not
    // awaited while we let the download start and then cancel it — and it is
    // the delete that makes it reject. With the expectation attached after the
    // delete, the rejection lands in a window where nothing is listening, and
    // Dart reports it as an unhandled async error: a flake that only shows up
    // under parallel load, where the window is wide enough to lose the race.
    final cancelled = expectLater(done, throwsA(isA<DownloadCancelled>()));

    await Future<void>.delayed(const Duration(milliseconds: 30));
    await DownloadService.delete('lec-3');

    await cancelled;
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
      expect(
        DownloadService.fileSizeSync('missing', seriesId: 'tawheed-ar'),
        0,
      );
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
