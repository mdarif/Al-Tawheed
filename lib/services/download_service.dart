import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myapp/models/series.dart';

/// Base type for failures that can be surfaced by an audio download.
abstract class DownloadException implements Exception {
  const DownloadException(this.detail);

  final String detail;

  @override
  String toString() => '$runtimeType: $detail';
}

/// Thrown when a download is cancelled via [DownloadService.cancel].
///
/// This keeps its existing public name so callers that already distinguish a
/// user cancellation continue to do so.
class DownloadCancelled extends DownloadException {
  const DownloadCancelled() : super('download cancelled');
}

/// The streamed bytes did not match a catalog size or HTTP `Content-Length`.
class DownloadIntegrityException extends DownloadException {
  const DownloadIntegrityException(super.detail);
}

/// A non-retry-policy HTTP or transport error (invalid URL, connection drop,
/// or an unexpected non-success response).
class DownloadTransferException extends DownloadException {
  const DownloadTransferException(super.detail);
}

/// The CDN asked the app to back off (`429`) or reported a transient server
/// failure (`5xx`).
class RateLimitedException extends DownloadException {
  RateLimitedException({
    required this.url,
    required this.statusCode,
    this.retryAfter,
  }) : super('$url: HTTP $statusCode');

  final Uri url;
  final int statusCode;
  final Duration? retryAfter;
}

/// The operating system reported that the device has no usable free storage.
class InsufficientStorageException extends DownloadException {
  const InsufficientStorageException(super.detail);
}

final _safeSegment = RegExp(r'^[A-Za-z0-9._-]+$');

/// Whether [segment] is safe to interpolate as a single path component.
///
/// Lecture and series ids come straight from the remote catalog JSON, which is
/// attacker-influenceable (compromised endpoint / MITM). Without this check an
/// id like `../../databases/x` would let a download escape the `audio/`
/// directory and overwrite arbitrary app files. The allowlist admits only
/// `[A-Za-z0-9._-]` and rejects the `.`/`..` traversal segments, which also
/// blocks path separators, null bytes, and whitespace.
bool isSafePathSegment(String segment) =>
    _safeSegment.hasMatch(segment) && segment != '.' && segment != '..';

/// Local audio file path for [lectureId] within [seriesId] under [documentsPath].
/// The default series (`tawheed-ur`) keeps its original, unprefixed layout
/// (`{docs}/audio/{id}.mp3`) — zero migration for existing downloads.
///
/// Throws [ArgumentError] if either id is not a safe path segment, so a
/// tampered catalog can never produce a path outside `audio/`.
String _localPathFor(String documentsPath, String seriesId, String lectureId) {
  if (!isSafePathSegment(lectureId)) {
    throw ArgumentError.value(lectureId, 'lectureId', 'unsafe path segment');
  }
  if (seriesId == SeriesConfig.legacyId) {
    return '$documentsPath/audio/$lectureId.mp3';
  }
  if (!isSafePathSegment(seriesId)) {
    throw ArgumentError.value(seriesId, 'seriesId', 'unsafe path segment');
  }
  return '$documentsPath/audio/$seriesId/$lectureId.mp3';
}

/// Reconciles persisted download IDs against files on disk (runs off UI thread).
Future<Set<String>> reconcileDownloadedIds(
  (List<String> ids, String documentsPath, String seriesId) args,
) async {
  final (ids, documentsPath, seriesId) = args;
  final valid = <String>{};
  if (seriesId != SeriesConfig.legacyId && !isSafePathSegment(seriesId)) {
    return valid;
  }
  for (final id in ids) {
    if (!isSafePathSegment(id)) continue;
    if (await File(_localPathFor(documentsPath, seriesId, id)).exists()) {
      valid.add(id);
    }
  }
  return valid;
}

/// Total on-disk bytes for [ids] — runs off the UI thread via `compute`, so the
/// startup storage tally never stat()s files on the main isolate. Mirrors
/// [reconcileDownloadedIds]; unsafe ids are skipped.
int totalBytesForIds(
  (List<String> ids, String documentsPath, String seriesId) args,
) {
  final (ids, documentsPath, seriesId) = args;
  if (seriesId != SeriesConfig.legacyId && !isSafePathSegment(seriesId)) {
    return 0;
  }
  int total = 0;
  for (final id in ids) {
    if (!isSafePathSegment(id)) continue;
    final f = File(_localPathFor(documentsPath, seriesId, id));
    if (f.existsSync()) total += f.lengthSync();
  }
  return total;
}

class _ActiveDownload {
  _ActiveDownload(this.client, this.partFile);

  final HttpClient client;
  final File partFile;
  final Completer<void> _finished = Completer<void>();
  bool cancelled = false;
  bool promotionStarted = false;

  /// Cancellation is accepted only before atomic promotion starts. Once a
  /// verified file is entering `rename`, that commit is authoritative: callers
  /// see a successful download and can explicitly delete it afterwards.
  bool cancel() {
    if (cancelled || promotionStarted) return false;
    cancelled = true;
    client.close(force: true);
    return true;
  }

  Future<void> get finished => _finished.future;

  void finish() {
    if (!_finished.isCompleted) _finished.complete();
  }
}

/// Low-level download and file-management service.
///
/// Call [init] once in main() so that [localPath] stays synchronous
/// everywhere in the call graph — no async waiting in the hot path.
class DownloadService {
  DownloadService._();

  static String? _documentsPath;
  static final Map<String, _ActiveDownload> _active = {};
  static final Map<String, _ActiveDownload> _activeByDestination = {};
  static final Map<String, String> _destinationOwnerKeys = {};
  static int _nextOperationId = 0;

  /// Test-only seam for exercising OS storage failures without relying on a
  /// device-specific full disk. It intentionally runs immediately before the
  /// `.part` file is opened, so production still has exactly one write path.
  @visibleForTesting
  static Future<void> Function(File partFile)? beforePartFileOpenForTest;

  /// Test-only promotion barrier used to verify cancellation at the narrow
  /// boundary between a fully-written `.part` and its atomic rename.
  @visibleForTesting
  static Future<void> Function(File partFile)? beforePromotionForTest;

  /// Test-only post-rename barrier for defining cancellation semantics after a
  /// verified atomic promotion has already committed.
  @visibleForTesting
  static Future<void> Function(File destination)? afterPromotionForTest;

  /// Must be called before any other method.
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _documentsPath = dir.path;
  }

  /// Predictable local path for a lecture. `tawheed-ur` (the default) keeps
  /// `{docs}/audio/{id}.mp3`; other series use `{docs}/audio/{seriesId}/{id}.mp3`.
  static String localPath(
    String lectureId, {
    String seriesId = SeriesConfig.legacyId,
  }) {
    assert(
      _documentsPath != null,
      'DownloadService.init() must be called first',
    );
    return _localPathFor(_documentsPath!, seriesId, lectureId);
  }

  static String get documentsPath {
    assert(
      _documentsPath != null,
      'DownloadService.init() must be called first',
    );
    return _documentsPath!;
  }

  static bool existsSync(
    String lectureId, {
    String seriesId = SeriesConfig.legacyId,
  }) {
    if (_documentsPath == null) return false;
    try {
      return File(localPath(lectureId, seriesId: seriesId)).existsSync();
    } on ArgumentError {
      return false;
    }
  }

  /// Requests cancellation for [cancelKey]. Returns false after atomic
  /// promotion has started, because that verified replacement must complete.
  static bool cancel(String cancelKey) => _active[cancelKey]?.cancel() ?? false;

  /// Downloads [url] to a sibling `.part` file, verifies its bytes, and then
  /// atomically promotes it to [savePath]. [fileSizeBytes] comes from the
  /// catalog; if it is unknown, a response `Content-Length` is used instead.
  ///
  /// Pass [cancelKey] so [cancel] can abort this transfer. Failures are typed:
  /// [DownloadCancelled], [DownloadIntegrityException],
  /// [DownloadTransferException], [RateLimitedException], and
  /// [InsufficientStorageException]. A failed attempt only removes its `.part`
  /// file, never an already-complete [savePath].
  static Future<void> download({
    required String cancelKey,
    required String url,
    required String savePath,
    required int fileSizeBytes,
    required void Function(double progress) onProgress,
  }) async {
    final destination = File(savePath);
    await _cancelAndWaitForPrior(cancelKey, destination.path);

    final client = HttpClient();
    final partFile = File('$savePath.${++_nextOperationId}.part');
    final active = _ActiveDownload(client, partFile);
    _active[cancelKey] = active;
    _activeByDestination[destination.path] = active;

    try {
      await destination.parent.create(recursive: true);
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == HttpStatus.tooManyRequests ||
          response.statusCode >= HttpStatus.internalServerError) {
        await _discardErrorResponse(response, client);
        throw RateLimitedException(
          url: uri,
          statusCode: response.statusCode,
          retryAfter: _parseRetryAfter(response.headers),
        );
      }
      if (response.statusCode != HttpStatus.ok) {
        await _discardErrorResponse(response, client);
        throw DownloadTransferException(
          '$url: HTTP ${response.statusCode}',
        );
      }

      final expectedBytes = fileSizeBytes > 0
          ? fileSizeBytes
          : response.contentLength >= 0
              ? response.contentLength
              : null;
      if (expectedBytes == null) {
        await _discardErrorResponse(response, client);
        throw DownloadIntegrityException(
          '$url: no trusted catalog byte count or Content-Length',
        );
      }
      var received = 0;
      await beforePartFileOpenForTest?.call(partFile);
      final sink = partFile.openWrite();
      try {
        await for (final chunk in response) {
          if (active.cancelled) throw const DownloadCancelled();
          sink.add(chunk);
          received += chunk.length;
          if (expectedBytes > 0) {
            onProgress((received / expectedBytes).clamp(0.0, 1.0));
          }
        }
      } catch (_) {
        // Dart's HTTP client can report a premature close as a stream error
        // before the loop reaches its post-stream byte check. If a size was
        // declared, it is still an integrity failure, not an opaque transfer
        // failure.
        if (active.cancelled) throw const DownloadCancelled();
        if (received != expectedBytes) {
          throw DownloadIntegrityException(
            '$url: expected $expectedBytes bytes, got $received',
          );
        }
        rethrow;
      } finally {
        await sink.close();
      }

      if (active.cancelled) throw const DownloadCancelled();
      if (received != expectedBytes) {
        throw DownloadIntegrityException(
          '$url: expected $expectedBytes bytes, got $received',
        );
      }

      await beforePromotionForTest?.call(partFile);
      if (active.cancelled) throw const DownloadCancelled();
      // POSIX rename replaces an existing destination atomically on Android
      // and iOS. Only a fully verified `.part` reaches this line.
      active.promotionStarted = true;
      await partFile.rename(destination.path);
      _destinationOwnerKeys[destination.path] = cancelKey;
      await afterPromotionForTest?.call(destination);
    } on FileSystemException catch (error) {
      if (active.cancelled) throw const DownloadCancelled();
      if (_isStorageError(error)) {
        throw InsufficientStorageException('$savePath: $error');
      }
      throw DownloadTransferException('$url: $error');
    } on DownloadException {
      rethrow;
    } catch (error) {
      if (active.cancelled) throw const DownloadCancelled();
      throw DownloadTransferException('$url: $error');
    } finally {
      client.close();
      // Best-effort cleanup. A concurrent delete() can race this path; if it
      // already removed the file, that is the intended final state.
      try {
        if (await partFile.exists()) await partFile.delete();
      } on PathNotFoundException {
        // Already removed by concurrent delete cleanup.
      }
      if (identical(_active[cancelKey], active)) _active.remove(cancelKey);
      if (identical(_activeByDestination[destination.path], active)) {
        _activeByDestination.remove(destination.path);
      }
      active.finish();
    }
  }

  static Future<void> delete(
    String lectureId, {
    String seriesId = SeriesConfig.legacyId,
    String? cancelKey,
    String? expectedOwnerKey,
  }) async {
    final file = File(localPath(lectureId, seriesId: seriesId));
    await _cancelAndWaitForPrior(cancelKey ?? lectureId, file.path);
    // A stale provider completion may only delete the destination it promoted.
    // If a newer operation already owns this path, it must survive.
    if (expectedOwnerKey != null &&
        _destinationOwnerKeys[file.path] != expectedOwnerKey) {
      return;
    }
    try {
      if (await file.exists()) await file.delete();
    } on PathNotFoundException {
      // Already removed by cancel cleanup — nothing to do.
    }
    if (expectedOwnerKey == null ||
        _destinationOwnerKeys[file.path] == expectedOwnerKey) {
      _destinationOwnerKeys.remove(file.path);
    }
  }

  /// On-disk byte size of one downloaded lecture, or 0 if missing/unsafe.
  /// Enables O(1) incremental byte accounting (add on complete, subtract on
  /// delete) instead of re-stat()ing every file after each change.
  static int fileSizeSync(
    String lectureId, {
    String seriesId = SeriesConfig.legacyId,
  }) {
    if (_documentsPath == null) return 0;
    try {
      final f = File(localPath(lectureId, seriesId: seriesId));
      return f.existsSync() ? f.lengthSync() : 0;
    } on ArgumentError {
      return 0;
    }
  }

  @visibleForTesting
  static void resetForTest(String documentsPath) {
    for (final active in _active.values) {
      active.cancel();
    }
    _active.clear();
    _activeByDestination.clear();
    _destinationOwnerKeys.clear();
    _nextOperationId = 0;
    _documentsPath = documentsPath;
    beforePartFileOpenForTest = null;
    beforePromotionForTest = null;
    afterPromotionForTest = null;
  }

  @visibleForTesting
  static String? activePartPathForTest(String savePath) =>
      _activeByDestination[savePath]?.partFile.path;

  static Duration? _parseRetryAfter(HttpHeaders headers) {
    // The app currently has no retry scheduler, so retain only the simple
    // delta-seconds form for a future caller. HTTP-date Retry-After is
    // intentionally left unparsed until that policy exists.
    final raw = headers.value(HttpHeaders.retryAfterHeader);
    final seconds = raw == null ? null : int.tryParse(raw.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static bool _isStorageError(FileSystemException error) {
    final osError = error.osError;
    return osError?.errorCode == 28 ||
        osError?.message.toLowerCase().contains('no space') == true;
  }

  static Future<void> _discardErrorResponse(
    HttpClientResponse response,
    HttpClient client,
  ) async {
    // No response body is useful for a failed audio request. Close the only
    // client first so a malicious/buggy endpoint cannot keep this operation
    // alive by streaming an endless error body, then drain best-effort to
    // release any buffered bytes.
    client.close(force: true);
    try {
      await response.drain<void>();
    } catch (_) {
      // Closing a live response can make drain fail; the socket is already
      // force-closed and the typed status failure below remains authoritative.
    }
  }

  static Future<void> _cancelAndWaitForPrior(
    String cancelKey,
    String destinationPath,
  ) async {
    final candidates = <_ActiveDownload>{
      if (_active[cancelKey] case final active?) active,
      if (_activeByDestination[destinationPath] case final active?) active,
    };
    for (final active in candidates) {
      active.cancel();
    }
    await Future.wait([for (final active in candidates) active.finished]);
  }
}
