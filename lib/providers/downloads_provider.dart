import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded, failed }

class DownloadsProvider extends ChangeNotifier {
  final Map<String, DownloadStatus> _statuses = {};
  final Map<String, double> _progress = {};
  Set<String> _downloadedIds = {};

  void load() {
    _downloadedIds = PreferencesService.instance.loadDownloadedIds();
    // Reconcile: mark as downloaded only if the file actually exists on disk
    for (final id in List.of(_downloadedIds)) {
      if (DownloadService.existsSync(id)) {
        _statuses[id] = DownloadStatus.downloaded;
      } else {
        // File was deleted externally (e.g., storage cleared) — remove from registry
        _downloadedIds.remove(id);
      }
    }
    if (_downloadedIds.length != (PreferencesService.instance.loadDownloadedIds().length)) {
      PreferencesService.instance.saveDownloadedIds(_downloadedIds);
    }
    notifyListeners();
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  DownloadStatus statusFor(String lectureId) =>
      _statuses[lectureId] ?? DownloadStatus.notDownloaded;

  double progressFor(String lectureId) => _progress[lectureId] ?? 0.0;

  bool isDownloaded(String lectureId) =>
      statusFor(lectureId) == DownloadStatus.downloaded;

  bool isDownloading(String lectureId) =>
      statusFor(lectureId) == DownloadStatus.downloading;

  Set<String> get downloadedIds => Set.unmodifiable(_downloadedIds);

  int get downloadedCount => _downloadedIds.length;

  int get totalDownloadedBytes =>
      DownloadService.totalBytesSync(_downloadedIds);

  /// Returns local file path if downloaded, null otherwise.
  String? localPathIfDownloaded(String lectureId) {
    if (!isDownloaded(lectureId)) return null;
    final path = DownloadService.localPath(lectureId);
    return DownloadService.existsSync(lectureId) ? path : null;
  }

  // ── Commands ─────────────────────────────────────────────────────────────

  Future<void> download(Lecture lecture) async {
    if (_statuses[lecture.id] == DownloadStatus.downloading) return;

    _statuses[lecture.id] = DownloadStatus.downloading;
    _progress[lecture.id] = 0.0;
    notifyListeners();

    try {
      await DownloadService.download(
        url: lecture.audioUrl,
        savePath: DownloadService.localPath(lecture.id),
        fileSizeBytes: lecture.fileSizeBytes,
        onProgress: (p) {
          _progress[lecture.id] = p;
          notifyListeners();
        },
      );

      _statuses[lecture.id] = DownloadStatus.downloaded;
      _downloadedIds.add(lecture.id);
      _progress.remove(lecture.id);
      await PreferencesService.instance.saveDownloadedIds(_downloadedIds);
    } catch (_) {
      _statuses[lecture.id] = DownloadStatus.failed;
      _progress.remove(lecture.id);
    }
    notifyListeners();
  }

  Future<void> delete(String lectureId) async {
    await DownloadService.delete(lectureId);
    _statuses[lectureId] = DownloadStatus.notDownloaded;
    _downloadedIds.remove(lectureId);
    await PreferencesService.instance.saveDownloadedIds(_downloadedIds);
    notifyListeners();
  }

  Future<void> deleteAll() async {
    for (final id in List.of(_downloadedIds)) {
      await DownloadService.delete(id);
    }
    _statuses.clear();
    _downloadedIds.clear();
    await PreferencesService.instance.saveDownloadedIds({});
    notifyListeners();
  }
}
