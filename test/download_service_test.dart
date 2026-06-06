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
}
