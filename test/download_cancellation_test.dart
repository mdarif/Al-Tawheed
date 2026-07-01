import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/services/download_service.dart';

Lecture _lec(String id,
        {int bytes = 5120, String chapterId = 'ch-01', required String audioUrl,}) =>
    Lecture(
      id: id,
      number: 1,
      chapterId: chapterId,
      title: const {'en': 'Test lecture'},
      audioUrl: audioUrl,
      durationSeconds: 60,
      fileSizeBytes: bytes,
    );

Future<({HttpServer server, String baseUrl})> _startSlowServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.host}:${server.port}/audio.mp3';
  server.listen((request) async {
    for (var i = 0; i < 80; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      request.response.add(List<int>.filled(64, 1));
    }
    await request.response.close();
  });
  return (server: server, baseUrl: baseUrl);
}

/// Integration tests for download cancellation.
/// Must NOT call TestWidgetsFlutterBinding.ensureInitialized() — that stubs HTTP.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dl_cancel_integration_');
    DownloadService.resetForTest(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('cancelDownload clears state and does not mark lecture downloaded',
      () async {
    final (:server, :baseUrl) = await _startSlowServer();
    addTearDown(() => server.close(force: true));

    final provider = DownloadsProvider();
    unawaited(provider.download(_lec('x', audioUrl: baseUrl)));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(provider.isDownloading('x'), isTrue);

    provider.cancelDownload('x');
    expect(provider.statusFor('x'), DownloadStatus.notDownloaded);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(provider.isDownloaded('x'), isFalse);
    expect(DownloadService.existsSync('x'), isFalse);
  });

  test('delete while downloading delegates to cancelDownload', () async {
    final (:server, :baseUrl) = await _startSlowServer();
    addTearDown(() => server.close(force: true));

    final provider = DownloadsProvider();
    unawaited(provider.download(_lec('y', audioUrl: baseUrl)));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await provider.delete('y');

    expect(provider.statusFor('y'), DownloadStatus.notDownloaded);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(provider.isDownloaded('y'), isFalse);
  });

  test('cancelChapterDownload aborts the active lecture and stops the batch',
      () async {
    final (:server, :baseUrl) = await _startSlowServer();
    addTearDown(() => server.close(force: true));

    final provider = DownloadsProvider();
    final lectures = [
      _lec('a', chapterId: 'ch-01', audioUrl: baseUrl),
      _lec('b', chapterId: 'ch-01', audioUrl: baseUrl),
    ];

    unawaited(provider.downloadChapter('ch-01', lectures));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(provider.isChapterDownloading('ch-01'), isTrue);
    expect(provider.isDownloading('a'), isTrue);

    provider.cancelChapterDownload('ch-01');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(provider.isChapterDownloading('ch-01'), isFalse);
    expect(provider.isDownloaded('a'), isFalse);
    expect(provider.isDownloaded('b'), isFalse);
  });
}
