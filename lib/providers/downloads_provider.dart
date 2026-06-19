import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded, failed }

class DownloadsProvider extends ChangeNotifier {
  DownloadsProvider([this._series]);

  final SeriesProvider? _series;

  SeriesConfig get _activeSeries =>
      _series?.currentSeries ?? SeriesConfig.legacyUrduFallback;
  String get _prefix => _activeSeries.storagePrefix;
  String get _seriesId => _activeSeries.id;

  final Map<String, DownloadStatus> _statuses = {};
  final Map<String, double> _progress = {};
  Set<String> _downloadedIds = {};
  int _totalDownloadedBytes = 0;
  final Set<String> _downloadingChapterIds = {};
  final Set<String> _cancelledChapterIds = {};
  final Map<String, String> _chapterActiveLectureId = {};
  Lecture? _queuedDownload;

  /// Reconcile disk state off the UI thread — call once at startup.
  Future<void> load() async {
    _downloadedIds =
        PreferencesService.instance.loadDownloadedIds(prefix: _prefix);
    final savedCount = _downloadedIds.length;

    if (_downloadedIds.isNotEmpty) {
      _downloadedIds = await compute(
        reconcileDownloadedIds,
        (_downloadedIds.toList(), DownloadService.documentsPath, _seriesId),
      );
    }

    for (final id in _downloadedIds) {
      _statuses[id] = DownloadStatus.downloaded;
    }

    if (_downloadedIds.length != savedCount) {
      await PreferencesService.instance
          .saveDownloadedIds(_downloadedIds, prefix: _prefix);
    }

    _refreshTotalBytes();
    notifyListeners();
  }

  /// Re-scopes all in-memory state to the current series and reloads from
  /// disk — call after switching series.
  Future<void> reload() async {
    _statuses.clear();
    _progress.clear();
    _downloadedIds = {};
    _totalDownloadedBytes = 0;
    _downloadingChapterIds.clear();
    _cancelledChapterIds.clear();
    _chapterActiveLectureId.clear();
    _queuedDownload = null;
    await load();
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

  bool get downloadOnWifiOnly => PreferencesService.instance.downloadOnWifiOnly;

  // ── Chapter-level getters ─────────────────────────────────────────────────

  bool isChapterDownloading(String chapterId) =>
      _downloadingChapterIds.contains(chapterId);

  bool isChapterFullyDownloaded(List<Lecture> lectures) =>
      lectures.isNotEmpty && lectures.every((l) => isDownloaded(l.id));

  int chapterDownloadedCount(List<Lecture> lectures) =>
      lectures.where((l) => isDownloaded(l.id)).length;

  int chapterTotalBytes(List<Lecture> lectures) =>
      lectures.fold(0, (sum, l) => sum + l.fileSizeBytes);

  int chapterDownloadedBytes(List<Lecture> lectures) => lectures
      .where((l) => isDownloaded(l.id))
      .fold(0, (sum, l) => sum + l.fileSizeBytes);

  /// Returns local file path if downloaded, null otherwise.
  String? localPathIfDownloaded(String lectureId) {
    if (!isDownloaded(lectureId)) return null;
    return DownloadService.localPath(lectureId, seriesId: _seriesId);
  }

  /// Queues a lecture to download when connectivity allows.
  void queueDownload(Lecture lecture) {
    _queuedDownload = lecture;
  }

  /// Starts a queued download once online (and on Wi‑Fi if required).
  Future<void> tryStartQueuedDownload({required bool isWifi}) async {
    final lecture = _queuedDownload;
    if (lecture == null || isDownloaded(lecture.id)) {
      _queuedDownload = null;
      return;
    }
    if (downloadOnWifiOnly && !isWifi) return;
    _queuedDownload = null;
    await download(lecture);
  }

  /// Starts [lecture] now or queues it when offline / Wi‑Fi blocked.
  /// Returns true if the download started immediately.
  bool downloadNowOrQueue({
    required Lecture lecture,
    required bool isOnline,
    required bool isWifi,
  }) {
    if (!isOnline) {
      queueDownload(lecture);
      return false;
    }
    if (downloadOnWifiOnly && !isWifi) return false;
    unawaited(download(lecture));
    return true;
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
        cancelKey: lecture.id,
        url: lecture.audioUrl,
        savePath: DownloadService.localPath(lecture.id, seriesId: _seriesId),
        fileSizeBytes: lecture.fileSizeBytes,
        onProgress: (p) {
          if (_statuses[lecture.id] != DownloadStatus.downloading) return;
          _progress[lecture.id] = p;
          final stepped = (p * 100).floorToDouble() / 100;
          if (stepped != lastNotifiedProgress || p >= 1.0) {
            lastNotifiedProgress = stepped;
            unawaited(
              DownloadNotificationService.instance
                  .showProgress(lecture.id, lecture.title.en, p),
            );
            notifyListeners();
          }
        },
      );

      if (_statuses[lecture.id] != DownloadStatus.downloading) {
        await DownloadService.delete(lecture.id, seriesId: _seriesId);
        return;
      }

      _statuses[lecture.id] = DownloadStatus.downloaded;
      _downloadedIds.add(lecture.id);
      _progress.remove(lecture.id);
      await PreferencesService.instance
          .saveDownloadedIds(_downloadedIds, prefix: _prefix);
      _refreshTotalBytes();
      unawaited(
        DownloadNotificationService.instance
            .showComplete(lecture.id, lecture.title.en),
      );
    } on DownloadCancelled {
      _resetAfterCancel(lecture.id);
    } catch (_) {
      if (_statuses[lecture.id] == DownloadStatus.downloading) {
        _statuses[lecture.id] = DownloadStatus.failed;
        _progress.remove(lecture.id);
        unawaited(DownloadNotificationService.instance.dismiss(lecture.id));
      }
    }
    notifyListeners();
  }

  /// Aborts an in-flight download and clears progress immediately.
  void cancelDownload(String lectureId) {
    if (_statuses[lectureId] != DownloadStatus.downloading) return;
    DownloadService.cancel(lectureId);
    _resetAfterCancel(lectureId);
    notifyListeners();
  }

  /// Downloads all lectures in a chapter serially. Safe to call if already running.
  Future<void> downloadChapter(String chapterId, List<Lecture> lectures) async {
    if (_downloadingChapterIds.contains(chapterId)) return;
    _downloadingChapterIds.add(chapterId);
    _cancelledChapterIds.remove(chapterId);
    notifyListeners();

    for (final lecture in lectures) {
      if (_cancelledChapterIds.contains(chapterId)) break;
      if (!isDownloaded(lecture.id)) {
        _chapterActiveLectureId[chapterId] = lecture.id;
        await download(lecture);
        if (_cancelledChapterIds.contains(chapterId)) break;
      }
    }

    _chapterActiveLectureId.remove(chapterId);
    _downloadingChapterIds.remove(chapterId);
    _cancelledChapterIds.remove(chapterId);
    notifyListeners();
  }

  void cancelChapterDownload(String chapterId) {
    if (!_downloadingChapterIds.contains(chapterId)) return;
    _cancelledChapterIds.add(chapterId);
    final activeId = _chapterActiveLectureId[chapterId];
    if (activeId != null) cancelDownload(activeId);
    notifyListeners();
  }

  Future<void> delete(String lectureId) async {
    if (isDownloading(lectureId)) {
      cancelDownload(lectureId);
      return;
    }
    unawaited(DownloadNotificationService.instance.dismiss(lectureId));
    await DownloadService.delete(lectureId, seriesId: _seriesId);
    _statuses[lectureId] = DownloadStatus.notDownloaded;
    _downloadedIds.remove(lectureId);
    await PreferencesService.instance
        .saveDownloadedIds(_downloadedIds, prefix: _prefix);
    _refreshTotalBytes();
    notifyListeners();
  }

  Future<void> deleteChapter(List<Lecture> lectures) async {
    for (final lecture in lectures) {
      if (isDownloading(lecture.id)) {
        cancelDownload(lecture.id);
      } else if (isDownloaded(lecture.id)) {
        await DownloadService.delete(lecture.id, seriesId: _seriesId);
        _statuses[lecture.id] = DownloadStatus.notDownloaded;
        _downloadedIds.remove(lecture.id);
      }
    }
    await PreferencesService.instance
        .saveDownloadedIds(_downloadedIds, prefix: _prefix);
    _refreshTotalBytes();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    for (final id in List.of(_downloadedIds)) {
      await DownloadService.delete(id, seriesId: _seriesId);
    }
    for (final id in _statuses.keys.toList()) {
      if (_statuses[id] == DownloadStatus.downloading) {
        cancelDownload(id);
      }
    }
    _statuses.clear();
    _downloadedIds.clear();
    _totalDownloadedBytes = 0;
    await PreferencesService.instance.saveDownloadedIds({}, prefix: _prefix);
    notifyListeners();
  }

  Future<void> setDownloadOnWifiOnly(bool value) async {
    await PreferencesService.instance.saveDownloadOnWifiOnly(value);
    notifyListeners();
  }

  void _resetAfterCancel(String lectureId) {
    _statuses[lectureId] = DownloadStatus.notDownloaded;
    _progress.remove(lectureId);
    unawaited(DownloadNotificationService.instance.dismiss(lectureId));
  }

  void _refreshTotalBytes() {
    _totalDownloadedBytes =
        DownloadService.totalBytesSync(_downloadedIds, seriesId: _seriesId);
  }

  // ── Test helpers ─────────────────────────────────────────────────────────

  @visibleForTesting
  void seedDownloadedForTest(String lectureId) {
    _statuses[lectureId] = DownloadStatus.downloaded;
    _downloadedIds.add(lectureId);
  }

  @visibleForTesting
  void seedDownloadingForTest(String lectureId) {
    _statuses[lectureId] = DownloadStatus.downloading;
    _progress[lectureId] = 0.5;
  }

  @visibleForTesting
  void seedChapterDownloadingForTest(String chapterId) {
    _downloadingChapterIds.add(chapterId);
  }

  @visibleForTesting
  String? chapterActiveLectureIdForTest(String chapterId) =>
      _chapterActiveLectureId[chapterId];
}
