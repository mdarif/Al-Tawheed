import 'dart:async';
import 'dart:io';

/// Runs [body] while every `.mp3` download made through `dart:io`'s
/// [HttpClient] is throttled to roughly [bytesPerSecond].
///
/// Patrol runs the app in the test's own isolate, so [HttpOverrides.global]
/// reaches `DownloadService`'s `HttpClient()`. A catalogue lecture is ~8 MB and
/// finishes in seconds on a healthy link, which is shorter than it takes
/// Patrol to open the notification shade. Without this, a test that waits for
/// an in-progress download races the download and either misses it or has to
/// treat "already finished" as a pass. Everything that is not an `.mp3` (the
/// catalogue, config, images) is untouched, so launch is not slowed.
///
/// Only the `HttpClient` surface `DownloadService` uses (`getUrl`, `close`) is
/// implemented; any other member throws, so a future change to the download
/// path fails loudly here instead of silently bypassing the throttle.
Future<T> withSlowAudioDownloads<T>(
  Future<T> Function() body, {
  int bytesPerSecond = 100 * 1024,
}) async {
  final previous = HttpOverrides.current;
  HttpOverrides.global = _SlowAudioOverrides(bytesPerSecond);
  try {
    return await body();
  } finally {
    HttpOverrides.global = previous;
  }
}

/// Default behaviour: `HttpOverrides`' base `createHttpClient` is the real one.
class _PlatformDefault extends HttpOverrides {}

class _SlowAudioOverrides extends HttpOverrides {
  _SlowAudioOverrides(this._bytesPerSecond);

  final int _bytesPerSecond;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Build the real client inside a zone whose override is the plain default,
    // so this does not recurse into ourselves.
    final real = HttpOverrides.runWithHttpOverrides(
      () => HttpClient(context: context),
      _PlatformDefault(),
    );
    return _SlowClient(real, _bytesPerSecond);
  }
}

class _SlowClient implements HttpClient {
  _SlowClient(this._real, this._bytesPerSecond);

  final HttpClient _real;
  final int _bytesPerSecond;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final request = await _real.getUrl(url);
    if (!url.path.toLowerCase().endsWith('.mp3')) return request;
    return _SlowRequest(request, _bytesPerSecond);
  }

  @override
  void close({bool force = false}) => _real.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SlowRequest implements HttpClientRequest {
  _SlowRequest(this._real, this._bytesPerSecond);

  final HttpClientRequest _real;
  final int _bytesPerSecond;

  @override
  Future<HttpClientResponse> close() async =>
      _SlowResponse(await _real.close(), _bytesPerSecond);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SlowResponse extends Stream<List<int>> implements HttpClientResponse {
  _SlowResponse(this._real, this._bytesPerSecond);

  final HttpClientResponse _real;
  final int _bytesPerSecond;

  @override
  int get statusCode => _real.statusCode;

  @override
  int get contentLength => _real.contentLength;

  @override
  HttpHeaders get headers => _real.headers;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // asyncMap pauses the socket while it waits, so this is real back-pressure
    // rather than buffering the whole body and delaying it.
    return _real.asyncMap((chunk) async {
      await Future<void>.delayed(
        Duration(microseconds: chunk.length * 1000000 ~/ _bytesPerSecond),
      );
      return chunk;
    }).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
