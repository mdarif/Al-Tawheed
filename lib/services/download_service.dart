import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Thrown when a download is cancelled via [DownloadService.cancel].
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Reconciles persisted download IDs against files on disk (runs off UI thread).
Future<Set<String>> reconcileDownloadedIds(
  (List<String> ids, String documentsPath) args,
) async {
  final (ids, documentsPath) = args;
  final valid = <String>{};
  for (final id in ids) {
    if (await File('$documentsPath/audio/$id.mp3').exists()) {
      valid.add(id);
    }
  }
  return valid;
}

class _ActiveDownload {
  _ActiveDownload(this.client);
  final HttpClient client;
  bool cancelled = false;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    client.close(force: true);
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

  /// Must be called before any other method.
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _documentsPath = dir.path;
  }

  /// Predictable local path for a lecture — always `{docs}/audio/{id}.mp3`.
  static String localPath(String lectureId) {
    assert(_documentsPath != null, 'DownloadService.init() must be called first');
    return '$_documentsPath/audio/$lectureId.mp3';
  }

  static String get documentsPath {
    assert(_documentsPath != null, 'DownloadService.init() must be called first');
    return _documentsPath!;
  }

  static bool existsSync(String lectureId) {
    if (_documentsPath == null) return false;
    return File(localPath(lectureId)).existsSync();
  }

  /// Aborts an in-flight download for [cancelKey] and deletes any partial file.
  static void cancel(String cancelKey) {
    _active[cancelKey]?.cancel();
  }

  /// Downloads [url] to [savePath] streaming progress via [onProgress] (0.0–1.0).
  /// Pass [cancelKey] so [cancel] can abort this transfer.
  /// Cleans up partial file on failure or cancellation and rethrows.
  static Future<void> download({
    required String cancelKey,
    required String url,
    required String savePath,
    required int fileSizeBytes,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(savePath);
    await file.parent.create(recursive: true);

    final client = HttpClient();
    final active = _ActiveDownload(client);
    _active[cancelKey] = active;

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed — HTTP ${response.statusCode}');
      }

      int received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          if (active.cancelled) throw const DownloadCancelled();
          sink.add(chunk);
          received += chunk.length;
          if (fileSizeBytes > 0) {
            onProgress((received / fileSizeBytes).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.close();
      }
    } catch (e) {
      if (await file.exists()) await file.delete();
      if (active.cancelled || e is DownloadCancelled) {
        throw const DownloadCancelled();
      }
      rethrow;
    } finally {
      _active.remove(cancelKey);
      client.close();
    }
  }

  static Future<void> delete(String lectureId) async {
    cancel(lectureId);
    final file = File(localPath(lectureId));
    if (await file.exists()) await file.delete();
  }

  /// Total bytes used by all downloaded lectures.
  static int totalBytesSync(Iterable<String> lectureIds) {
    if (_documentsPath == null) return 0;
    int total = 0;
    for (final id in lectureIds) {
      final f = File(localPath(id));
      if (f.existsSync()) total += f.lengthSync();
    }
    return total;
  }

  @visibleForTesting
  static void resetForTest(String documentsPath) {
    for (final active in _active.values) {
      active.cancel();
    }
    _active.clear();
    _documentsPath = documentsPath;
  }
}
