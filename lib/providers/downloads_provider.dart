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
  DownloadsProvider([this._series]) : _seriesForTest = null;

  @visibleForTesting
  DownloadsProvider.forSeries(this._seriesForTest) : _series = null;

  final SeriesProvider? _series;
  final SeriesConfig Function()? _seriesForTest;

  SeriesConfig get _activeSeries =>
      _seriesForTest?.call() ??
      _series?.currentSeries ??
      SeriesConfig.legacyUrduFallback;
  String get _prefix => _activeSeries.storagePrefix;
  String get _seriesId => _activeSeries.id;

  final Map<String, DownloadStatus> _statuses = {};
  final Map<String, double> _progress = {};
  final Map<String, DownloadException> _failures = {};
  Set<String> _downloadedIds = {};
  int _totalDownloadedBytes = 0;
  final Set<String> _downloadingChapterIds = {};
  final Set<String> _cancelledChapterIds = {};
  final Map<String, String> _chapterActiveLectureId = {};
  final Set<String> _activeDownloadKeys = {};
  Lecture? _queuedDownload;
  int _generation = 0;

  String _downloadKey(String lectureId, String seriesId, int generation) =>
      '$seriesId::$generation::$lectureId';

  bool _isCurrentOperation(int generation, String seriesId) =>
      generation == _generation && _seriesId == seriesId;

  /// Reconcile disk state off the UI thread — call once at startup.
  Future<void> load() async {
    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    var downloadedIds =
        PreferencesService.instance.loadDownloadedIds(prefix: prefix);
    final savedCount = downloadedIds.length;

    if (downloadedIds.isNotEmpty) {
      downloadedIds = await compute(
        reconcileDownloadedIds,
        (downloadedIds.toList(), DownloadService.documentsPath, seriesId),
      );
    }
    if (!_isCurrentOperation(generation, seriesId)) return;

    if (downloadedIds.length != savedCount) {
      await PreferencesService.instance
          .saveDownloadedIds(downloadedIds, prefix: prefix);
      if (!_isCurrentOperation(generation, seriesId)) return;
    }

    // Tally storage off the UI thread; kept in sync incrementally thereafter.
    final totalBytes = downloadedIds.isEmpty
        ? 0
        : await compute(
            totalBytesForIds,
            (downloadedIds.toList(), DownloadService.documentsPath, seriesId),
          );
    if (!_isCurrentOperation(generation, seriesId)) return;

    _downloadedIds = downloadedIds;
    for (final id in _downloadedIds) {
      _statuses[id] = DownloadStatus.downloaded;
    }
    _totalDownloadedBytes = totalBytes;
    notifyListeners();
  }

  /// Re-scopes all in-memory state to the current series and reloads from
  /// disk — call after switching series.
  Future<void> reload() async {
    _generation++;
    for (final key in _activeDownloadKeys) {
      DownloadService.cancel(key);
    }
    _activeDownloadKeys.clear();
    _statuses.clear();
    _progress.clear();
    _failures.clear();
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

  /// The typed reason for a failed download, if its latest attempt failed.
  /// Existing consumers can keep using [statusFor]; this gives future owned UI
  /// a safe way to distinguish an integrity failure from a CDN backoff or a
  /// device-storage problem.
  DownloadException? failureFor(String lectureId) => _failures[lectureId];

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

    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    final downloadKey = _downloadKey(lecture.id, seriesId, generation);
    final hadValidDownload = _downloadedIds.contains(lecture.id) &&
        DownloadService.existsSync(lecture.id, seriesId: seriesId);

    _statuses[lecture.id] = DownloadStatus.downloading;
    _progress[lecture.id] = 0.0;
    _failures.remove(lecture.id);
    _activeDownloadKeys.add(downloadKey);
    notifyListeners();

    var lastNotifiedProgress = -1.0;

    try {
      // Preserve the existing provider contract: an uninitialized service is
      // surfaced as a typed failed download rather than escaping this method.
      final savePath =
          DownloadService.localPath(lecture.id, seriesId: seriesId);
      await DownloadService.download(
        cancelKey: downloadKey,
        url: lecture.audioUrl,
        savePath: savePath,
        fileSizeBytes: lecture.fileSizeBytes,
        onProgress: (p) {
          if (!_isCurrentOperation(generation, seriesId) ||
              _statuses[lecture.id] != DownloadStatus.downloading) {
            return;
          }
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

      if (!_isCurrentOperation(generation, seriesId) ||
          _statuses[lecture.id] != DownloadStatus.downloading) {
        await DownloadService.delete(
          lecture.id,
          seriesId: seriesId,
          cancelKey: downloadKey,
        );
        return;
      }

      final wasDownloaded = _downloadedIds.contains(lecture.id);
      _statuses[lecture.id] = DownloadStatus.downloaded;
      _downloadedIds.add(lecture.id);
      _progress.remove(lecture.id);
      await PreferencesService.instance
          .saveDownloadedIds(_downloadedIds, prefix: prefix);
      if (!_isCurrentOperation(generation, seriesId)) return;
      // Add just this file's size — no full re-stat of every download.
      if (!wasDownloaded) {
        _totalDownloadedBytes +=
            DownloadService.fileSizeSync(lecture.id, seriesId: seriesId);
      }
      unawaited(
        DownloadNotificationService.instance
            .showComplete(lecture.id, lecture.title.en),
      );
    } on DownloadCancelled {
      if (_isCurrentOperation(generation, seriesId)) {
        _resetAfterCancel(lecture.id, seriesId: seriesId);
      }
    } on DownloadException catch (error) {
      debugPrint('DownloadsProvider: download error for ${lecture.id}: $error');
      if (_isCurrentOperation(generation, seriesId) &&
          _statuses[lecture.id] == DownloadStatus.downloading) {
        _statuses[lecture.id] = hadValidDownload
            ? DownloadStatus.downloaded
            : DownloadStatus.failed;
        _progress.remove(lecture.id);
        _failures[lecture.id] = error;
        unawaited(DownloadNotificationService.instance.dismiss(lecture.id));
      }
    } catch (e) {
      debugPrint('DownloadsProvider: download error for ${lecture.id}: $e');
      if (_isCurrentOperation(generation, seriesId) &&
          _statuses[lecture.id] == DownloadStatus.downloading) {
        _statuses[lecture.id] = hadValidDownload
            ? DownloadStatus.downloaded
            : DownloadStatus.failed;
        _progress.remove(lecture.id);
        _failures[lecture.id] = DownloadTransferException('$e');
        unawaited(DownloadNotificationService.instance.dismiss(lecture.id));
      }
    } finally {
      _activeDownloadKeys.remove(downloadKey);
    }
    if (_isCurrentOperation(generation, seriesId)) notifyListeners();
  }

  /// Aborts an in-flight download and clears progress immediately.
  void cancelDownload(String lectureId) {
    if (_statuses[lectureId] != DownloadStatus.downloading) return;
    final seriesId = _seriesId;
    DownloadService.cancel(_downloadKey(lectureId, seriesId, _generation));
    _resetAfterCancel(lectureId, seriesId: seriesId);
    notifyListeners();
  }

  /// Downloads all lectures in a chapter serially. Safe to call if already running.
  Future<void> downloadChapter(String chapterId, List<Lecture> lectures) async {
    if (_downloadingChapterIds.contains(chapterId)) return;
    final generation = _generation;
    final seriesId = _seriesId;
    _downloadingChapterIds.add(chapterId);
    _cancelledChapterIds.remove(chapterId);
    notifyListeners();

    for (final lecture in lectures) {
      if (!_isCurrentOperation(generation, seriesId)) return;
      if (_cancelledChapterIds.contains(chapterId)) break;
      if (!isDownloaded(lecture.id)) {
        _chapterActiveLectureId[chapterId] = lecture.id;
        await download(lecture);
        if (!_isCurrentOperation(generation, seriesId)) return;
        if (_cancelledChapterIds.contains(chapterId)) break;
      }
    }

    if (!_isCurrentOperation(generation, seriesId)) return;
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
    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    unawaited(DownloadNotificationService.instance.dismiss(lectureId));
    // Read the size before deleting the file, then subtract incrementally.
    final freed = DownloadService.fileSizeSync(lectureId, seriesId: seriesId);
    await DownloadService.delete(
      lectureId,
      seriesId: seriesId,
      cancelKey: _downloadKey(lectureId, seriesId, generation),
    );
    if (!_isCurrentOperation(generation, seriesId)) return;
    _statuses[lectureId] = DownloadStatus.notDownloaded;
    _downloadedIds.remove(lectureId);
    _failures.remove(lectureId);
    await PreferencesService.instance
        .saveDownloadedIds(_downloadedIds, prefix: prefix);
    if (!_isCurrentOperation(generation, seriesId)) return;
    _reduceTotalBytes(freed);
    notifyListeners();
  }

  Future<void> deleteChapter(List<Lecture> lectures) async {
    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    for (final lecture in lectures) {
      if (!_isCurrentOperation(generation, seriesId)) return;
      if (isDownloading(lecture.id)) {
        cancelDownload(lecture.id);
      } else if (isDownloaded(lecture.id)) {
        final freed =
            DownloadService.fileSizeSync(lecture.id, seriesId: seriesId);
        await DownloadService.delete(
          lecture.id,
          seriesId: seriesId,
          cancelKey: _downloadKey(lecture.id, seriesId, generation),
        );
        if (!_isCurrentOperation(generation, seriesId)) return;
        _statuses[lecture.id] = DownloadStatus.notDownloaded;
        _downloadedIds.remove(lecture.id);
        _reduceTotalBytes(freed);
      }
    }
    await PreferencesService.instance
        .saveDownloadedIds(_downloadedIds, prefix: prefix);
    if (!_isCurrentOperation(generation, seriesId)) return;
    notifyListeners();
  }

  Future<void> deleteAll() async {
    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    for (final id in List.of(_downloadedIds)) {
      await DownloadService.delete(
        id,
        seriesId: seriesId,
        cancelKey: _downloadKey(id, seriesId, generation),
      );
      if (!_isCurrentOperation(generation, seriesId)) return;
    }
    for (final id in _statuses.keys.toList()) {
      if (_statuses[id] == DownloadStatus.downloading) {
        cancelDownload(id);
      }
    }
    _statuses.clear();
    _failures.clear();
    _downloadedIds.clear();
    _totalDownloadedBytes = 0;
    await PreferencesService.instance.saveDownloadedIds({}, prefix: prefix);
    if (!_isCurrentOperation(generation, seriesId)) return;
    notifyListeners();
  }

  Future<void> setDownloadOnWifiOnly(bool value) async {
    await PreferencesService.instance.saveDownloadOnWifiOnly(value);
    notifyListeners();
  }

  void _resetAfterCancel(String lectureId, {required String seriesId}) {
    final stillDownloaded = _downloadedIds.contains(lectureId) &&
        DownloadService.existsSync(lectureId, seriesId: seriesId);
    _statuses[lectureId] = stillDownloaded
        ? DownloadStatus.downloaded
        : DownloadStatus.notDownloaded;
    if (!stillDownloaded) {
      _downloadedIds.remove(lectureId);
      unawaited(
        PreferencesService.instance
            .saveDownloadedIds(_downloadedIds, prefix: _prefix),
      );
    }
    _progress.remove(lectureId);
    _failures.remove(lectureId);
    unawaited(DownloadNotificationService.instance.dismiss(lectureId));
  }

  void _reduceTotalBytes(int freed) {
    _totalDownloadedBytes -= freed;
    if (_totalDownloadedBytes < 0) _totalDownloadedBytes = 0;
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
