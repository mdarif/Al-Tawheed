import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded, failed }

class DownloadsProvider extends ChangeNotifier {
  final Map<String, DownloadStatus> _statuses = {};
  final Map<String, double> _progress = {};
  Set<String> _downloadedIds = {};
  int _totalDownloadedBytes = 0;

  /// Reconcile disk state off the UI thread — call once at startup.
  Future<void> load() async {
    _downloadedIds = PreferencesService.instance.loadDownloadedIds();
    final savedCount = _downloadedIds.length;

    if (_downloadedIds.isNotEmpty) {
      _downloadedIds = await compute(
        reconcileDownloadedIds,
        (_downloadedIds.toList(), DownloadService.documentsPath),
      );
    }

    for (final id in _downloadedIds) {
      _statuses[id] = DownloadStatus.downloaded;
    }

    if (_downloadedIds.length != savedCount) {
      await PreferencesService.instance.saveDownloadedIds(_downloadedIds);
    }

    _refreshTotalBytes();
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

  int get totalDownloadedBytes => _totalDownloadedBytes;

  /// Returns local file path if downloaded, null otherwise.
  String? localPathIfDownloaded(String lectureId) {
    if (!isDownloaded(lectureId)) return null;
    return DownloadService.localPath(lectureId);
  }

  // ── Commands ─────────────────────────────────────────────────────────────

  Future<void> download(Lecture lecture) async {
    if (_statuses[lecture.id] == DownloadStatus.downloading) return;

    _statuses[lecture.id] = DownloadStatus.downloading;
    _progress[lecture.id] = 0.0;
    notifyListeners();

    var lastNotifiedProgress = -1.0;

    try {
      await DownloadService.download(
        url: lecture.audioUrl,
        savePath: DownloadService.localPath(lecture.id),
        fileSizeBytes: lecture.fileSizeBytes,
        onProgress: (p) {
          _progress[lecture.id] = p;
          final stepped = (p * 100).floorToDouble() / 100;
          if (stepped != lastNotifiedProgress || p >= 1.0) {
            lastNotifiedProgress = stepped;
            notifyListeners();
          }
        },
      );

      _statuses[lecture.id] = DownloadStatus.downloaded;
      _downloadedIds.add(lecture.id);
      _progress.remove(lecture.id);
      await PreferencesService.instance.saveDownloadedIds(_downloadedIds);
      _refreshTotalBytes();
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
    _refreshTotalBytes();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    for (final id in List.of(_downloadedIds)) {
      await DownloadService.delete(id);
    }
    _statuses.clear();
    _downloadedIds.clear();
    _totalDownloadedBytes = 0;
    await PreferencesService.instance.saveDownloadedIds({});
    notifyListeners();
  }

  void _refreshTotalBytes() {
    _totalDownloadedBytes = DownloadService.totalBytesSync(_downloadedIds);
  }
}
