import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

/// Low-level download and file-management service.
///
/// Call [init] once in main() so that [localPath] stays synchronous
/// everywhere in the call graph — no async waiting in the hot path.
class DownloadService {
  DownloadService._();

  static String? _documentsPath;

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

  /// Downloads [url] to [localPath] streaming progress via [onProgress] (0.0–1.0).
  /// Cleans up partial file on failure and rethrows.
  static Future<void> download({
    required String url,
    required String savePath,
    required int fileSizeBytes,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(savePath);
    await file.parent.create(recursive: true);

    final client = HttpClient();
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
          sink.add(chunk);
          received += chunk.length;
          if (fileSizeBytes > 0) {
            onProgress((received / fileSizeBytes).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.close();
      }
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> delete(String lectureId) async {
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
}
