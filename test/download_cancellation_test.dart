import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Lecture _lec(
  String id, {
  int bytes = 5120,
  String chapterId = 'ch-01',
  required String audioUrl,
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

Future<({HttpServer server, String baseUrl})> _startServer(
  int bytes, {
  int statusCode = HttpStatus.ok,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.host}:${server.port}/audio.mp3';
  server.listen((request) async {
    request.response.statusCode = statusCode;
    request.response.add(List<int>.filled(bytes, 1));
    await request.response.close();
  });
  return (server: server, baseUrl: baseUrl);
}

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: false,
  language: 'ar',
  displayName: {'en': 'Arabic'},
  speakerName: {'en': 'Speaker'},
);

/// Integration tests for download cancellation.
/// Must NOT call TestWidgetsFlutterBinding.ensureInitialized() — that stubs HTTP.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dl_cancel_integration_');
    DownloadService.resetForTest(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
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

  test('provider retains the concrete integrity failure', () async {
    final (:server, :baseUrl) = await _startServer(64);
    addTearDown(() => server.close(force: true));

    final provider = DownloadsProvider();
    await provider.download(_lec('integrity', bytes: 128, audioUrl: baseUrl));

    expect(provider.statusFor('integrity'), DownloadStatus.failed);
    expect(provider.failureFor('integrity'), isA<DownloadIntegrityException>());
  });

  test('provider retains the concrete rate-limit failure', () async {
    final (:server, :baseUrl) = await _startServer(
      0,
      statusCode: HttpStatus.tooManyRequests,
    );
    addTearDown(() => server.close(force: true));

    final provider = DownloadsProvider();
    await provider.download(_lec('rate-limit', bytes: 128, audioUrl: baseUrl));

    expect(provider.statusFor('rate-limit'), DownloadStatus.failed);
    expect(provider.failureFor('rate-limit'), isA<RateLimitedException>());
  });

  test('provider retains the concrete storage failure', () async {
    final (:server, :baseUrl) = await _startServer(128);
    addTearDown(() => server.close(force: true));
    DownloadService.beforePartFileOpenForTest = (partFile) async {
      throw FileSystemException(
        'write',
        partFile.path,
        OSError('No space left on device', 28),
      );
    };

    final provider = DownloadsProvider();
    await provider.download(_lec('storage', bytes: 128, audioUrl: baseUrl));

    expect(provider.statusFor('storage'), DownloadStatus.failed);
    expect(
      provider.failureFor('storage'),
      isA<InsufficientStorageException>(),
    );
  });

  test('a failed replacement keeps the existing download status and file',
      () async {
    final (:server, :baseUrl) = await _startServer(64);
    addTearDown(() => server.close(force: true));

    final provider = DownloadsProvider()..seedDownloadedForTest('replace');
    final destination = File(DownloadService.localPath('replace'));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes([7, 8, 9]);

    await provider.download(_lec('replace', bytes: 128, audioUrl: baseUrl));

    expect(provider.statusFor('replace'), DownloadStatus.downloaded);
    expect(provider.failureFor('replace'), isA<DownloadIntegrityException>());
    expect(await destination.readAsBytes(), [7, 8, 9]);
  });

  test('series reload fences an old same-id download from the new series',
      () async {
    final (:server, :baseUrl) = await _startSlowServer();
    addTearDown(() => server.close(force: true));
    final (server: fastServer, baseUrl: fastUrl) = await _startServer(128);
    addTearDown(() => fastServer.close(force: true));

    var activeSeries = SeriesConfig.legacyUrduFallback;
    final provider = DownloadsProvider.forSeries(() => activeSeries);
    final old = provider.download(
      _lec('same-id', bytes: 5120, audioUrl: baseUrl),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));

    activeSeries = _arabicSeries;
    await provider.reload();
    await provider.download(_lec('same-id', bytes: 128, audioUrl: fastUrl));
    await old;

    expect(provider.statusFor('same-id'), DownloadStatus.downloaded);
    expect(
      DownloadService.existsSync('same-id', seriesId: _arabicSeries.id),
      isTrue,
    );
    expect(DownloadService.existsSync('same-id'), isFalse);
  });
}
