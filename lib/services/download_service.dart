import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myapp/models/series.dart';

/// Thrown when a download is cancelled via [DownloadService.cancel].
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Local audio file path for [lectureId] within [seriesId] under [documentsPath].
/// The default series (`tawheed-ur`) keeps its original, unprefixed layout
/// (`{docs}/audio/{id}.mp3`) — zero migration for existing downloads.
String _localPathFor(String documentsPath, String seriesId, String lectureId) {
  if (seriesId == SeriesConfig.legacyId) {
    return '$documentsPath/audio/$lectureId.mp3';
  }
  return '$documentsPath/audio/$seriesId/$lectureId.mp3';
}

/// Reconciles persisted download IDs against files on disk (runs off UI thread).
Future<Set<String>> reconcileDownloadedIds(
  (List<String> ids, String documentsPath, String seriesId) args,
) async {
  final (ids, documentsPath, seriesId) = args;
  final valid = <String>{};
  for (final id in ids) {
    if (await File(_localPathFor(documentsPath, seriesId, id)).exists()) {
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
    return File(localPath(lectureId, seriesId: seriesId)).existsSync();
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

  static Future<void> delete(
    String lectureId, {
    String seriesId = SeriesConfig.legacyId,
  }) async {
    cancel(lectureId);
    // The cancel above is synchronous but its file-cleanup runs asynchronously.
    // If the download's catch block deletes the partial file between our
    // exists() check and delete() call, swallow the PathNotFoundException —
    // the file is already gone, which is the desired outcome.
    try {
      final file = File(localPath(lectureId, seriesId: seriesId));
      if (await file.exists()) await file.delete();
    } on PathNotFoundException {
      // Already removed by cancel cleanup — nothing to do.
    }
  }

  /// Total bytes used by all downloaded lectures.
  static int totalBytesSync(
    Iterable<String> lectureIds, {
    String seriesId = SeriesConfig.legacyId,
  }) {
    if (_documentsPath == null) return 0;
    int total = 0;
    for (final id in lectureIds) {
      final f = File(localPath(id, seriesId: seriesId));
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
