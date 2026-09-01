import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/saved_lecture_metadata.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';

enum DownloadStatus { notDownloaded, queued, downloading, downloaded, failed }

class DownloadsProvider extends ChangeNotifier {
  DownloadsProvider([this._series, this._connectivity]) : _seriesForTest = null;

  @visibleForTesting
  DownloadsProvider.forSeries(this._seriesForTest, [this._connectivity])
      : _series = null;

  final SeriesProvider? _series;
  final SeriesConfig Function()? _seriesForTest;
  final ConnectivityProvider? _connectivity;
  static int _nextProviderIdentity = 0;
  final int _providerIdentity = ++_nextProviderIdentity;

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
  final Map<String, String> _attemptTokens = {};
  final Map<String, SavedLectureMetadata> _downloadedMetadata = {};
  final Map<String, SavedLectureMetadata> _unavailableMetadata = {};
  final List<SavedLectureMetadata> _queuedDownloads = [];
  int _generation = 0;
  int _nextAttemptToken = 0;

  String _downloadKey(
    String lectureId,
    String seriesId,
    int generation,
    String attemptToken,
  ) =>
      '$seriesId::$generation::$lectureId::$attemptToken';

  String _newAttemptToken() =>
      'provider-$_providerIdentity-attempt-${++_nextAttemptToken}';

  String _deleteKey(String lectureId, int generation) =>
      'provider-$_providerIdentity-delete-$generation-$lectureId';

  bool _isCurrentOperation(int generation, String seriesId) =>
      generation == _generation && _seriesId == seriesId;

  bool _isCurrentAttempt(
    String lectureId,
    String attemptToken,
    int generation,
    String seriesId,
  ) =>
      _isCurrentOperation(generation, seriesId) &&
      _attemptTokens[lectureId] == attemptToken;

  /// Reconcile disk state off the UI thread — call once at startup.
  Future<void> load() async {
    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    var downloadedIds =
        PreferencesService.instance.loadDownloadedIds(prefix: prefix);
    final persistedMetadata =
        PreferencesService.instance.loadDownloadedMetadata(prefix: prefix);
    final persistedQueued =
        PreferencesService.instance.loadQueuedDownloads(prefix: prefix);
    final metadataById = {
      for (final row in persistedMetadata) row.id: row,
      for (final row in persistedQueued) row.id: row,
    };
    final savedCount = downloadedIds.length;
    final candidateIds = {
      ...downloadedIds,
      ...persistedQueued.map((row) => row.id),
    };

    if (candidateIds.isNotEmpty) {
      downloadedIds = await compute(
        reconcileDownloadedIdsWithExpectedBytes,
        (
          candidateIds.toList(),
          {
            for (final entry in metadataById.entries)
              entry.key: entry.value.fileSizeBytes,
          },
          DownloadService.documentsPath,
          seriesId,
        ),
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
    _downloadedMetadata
      ..clear()
      ..addEntries(
        persistedMetadata
            .where((row) => downloadedIds.contains(row.id))
            .map((row) => MapEntry(row.id, row)),
      )
      ..addEntries(
        persistedQueued
            .where((row) => downloadedIds.contains(row.id))
            .map((row) => MapEntry(row.id, row)),
      );
    _unavailableMetadata
      ..clear()
      ..addEntries(
        persistedMetadata
            .where((row) => !downloadedIds.contains(row.id))
            .map((row) => MapEntry(row.id, row)),
      );
    if (_downloadedMetadata.length + _unavailableMetadata.length !=
        persistedMetadata.length) {
      await PreferencesService.instance.saveDownloadedMetadata(
        _allMetadata,
        prefix: prefix,
      );
      if (!_isCurrentOperation(generation, seriesId)) return;
    }
    _queuedDownloads
      ..clear()
      ..addAll(
        PreferencesService.instance
            .loadQueuedDownloads(prefix: prefix)
            .where((row) => !downloadedIds.contains(row.id)),
      );
    if (_queuedDownloads.length != persistedQueued.length) {
      await PreferencesService.instance
          .saveQueuedDownloads(_queuedDownloads, prefix: prefix);
      if (!_isCurrentOperation(generation, seriesId)) return;
    }
    for (final id in _downloadedIds) {
      _statuses[id] = DownloadStatus.downloaded;
    }
    for (final row in _queuedDownloads) {
      _statuses[row.id] = DownloadStatus.queued;
    }
    _totalDownloadedBytes = totalBytes;
    notifyListeners();
    // The app wires a confirmed connectivity result before this provider.
    // Keep the legacy no-connectivity constructor optimistic for lightweight
    // callers/tests, but never attempt restored jobs when it is confirmed
    // offline.
    final isOnline = _connectivity?.isOnline ?? true;
    if (isOnline) {
      unawaited(
        tryStartQueuedDownload(
          isOnline: true,
          isWifi: _connectivity?.isWifi ?? true,
        ),
      );
    }
  }

  /// Re-scopes all in-memory state to the current series and reloads from
  /// disk — call after switching series.
  Future<void> reload() async {
    _generation++;
    for (final key in _activeDownloadKeys) {
      DownloadService.cancel(key);
    }
    _attemptTokens.clear();
    _statuses.clear();
    _progress.clear();
    _failures.clear();
    _downloadedIds = {};
    _totalDownloadedBytes = 0;
    _downloadingChapterIds.clear();
    _cancelledChapterIds.clear();
    _chapterActiveLectureId.clear();
    _downloadedMetadata.clear();
    _unavailableMetadata.clear();
    _queuedDownloads.clear();
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
  List<SavedLectureMetadata> get downloadedMetadata =>
      _downloadedMetadata.values
          .where((row) => _downloadedIds.contains(row.id))
          .toList(growable: false);
  List<SavedLectureMetadata> get unavailableMetadata =>
      _unavailableMetadata.values.toList(growable: false);
  bool isUnavailable(String lectureId) =>
      _unavailableMetadata.containsKey(lectureId);
  int get queuedDownloadCount => _queuedDownloads.length;

  /// Migrates legacy ID-only completed downloads once a catalogue is available.
  Future<void> backfillDownloadedMetadata(Iterable<Lecture> lectures) async {
    final byId = {for (final lecture in lectures) lecture.id: lecture};
    var changed = false;
    for (final id in _downloadedIds) {
      if (_downloadedMetadata.containsKey(id)) continue;
      final lecture = byId[id];
      if (lecture == null) continue;
      _downloadedMetadata[id] = SavedLectureMetadata.fromLecture(lecture);
      changed = true;
    }
    if (!changed) return;
    await PreferencesService.instance.saveDownloadedMetadata(
      _allMetadata,
      prefix: _prefix,
    );
    notifyListeners();
  }

  Iterable<SavedLectureMetadata> get _allMetadata => [
        ..._downloadedMetadata.values,
        ..._unavailableMetadata.values,
      ];

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
  Future<void> queueDownload(Lecture lecture) async {
    if (isDownloaded(lecture.id) || isDownloading(lecture.id)) return;
    _queuedDownloads.removeWhere((row) => row.id == lecture.id);
    _queuedDownloads.add(SavedLectureMetadata.fromLecture(lecture));
    _statuses[lecture.id] = DownloadStatus.queued;
    await PreferencesService.instance
        .saveQueuedDownloads(_queuedDownloads, prefix: _prefix);
    notifyListeners();
  }

  Future<void> _removeQueuedDownload(String lectureId) async {
    final before = _queuedDownloads.length;
    _queuedDownloads.removeWhere((row) => row.id == lectureId);
    if (_queuedDownloads.length == before) return;
    await PreferencesService.instance
        .saveQueuedDownloads(_queuedDownloads, prefix: _prefix);
  }

  /// Starts a queued download once online (and on Wi‑Fi if required).
  Future<void> tryStartQueuedDownload({
    required bool isOnline,
    required bool isWifi,
  }) async {
    if (!isOnline) return;
    if (_queuedDownloads.isEmpty) return;
    if (downloadOnWifiOnly && !isWifi) return;
    final generation = _generation;
    final seriesId = _seriesId;
    final queued = List<SavedLectureMetadata>.from(_queuedDownloads);
    for (final row in queued) {
      if (!_isCurrentOperation(generation, seriesId)) return;
      if (!isDownloaded(row.id)) await download(row.toLecture());
      if (!_isCurrentOperation(generation, seriesId)) return;
    }
  }

  /// Starts [lecture] now or queues it when offline / Wi‑Fi blocked.
  /// Returns true if the download started immediately.
  bool downloadNowOrQueue({
    required Lecture lecture,
    required bool isOnline,
    required bool isWifi,
  }) {
    if (!isOnline) {
      unawaited(queueDownload(lecture));
      return false;
    }
    if (downloadOnWifiOnly && !isWifi) {
      unawaited(queueDownload(lecture));
      return false;
    }
    // Persist the request before opening the transfer. Completion is the only
    // normal path that removes this intent, so a process death during transfer
    // (or after file promotion but before preference writes) is recoverable.
    unawaited(_queueThenDownload(lecture));
    return true;
  }

  Future<void> _queueThenDownload(Lecture lecture) async {
    await queueDownload(lecture);
    await download(lecture);
  }

  /// Starts a chapter now or durably queues each remaining lecture under the
  /// exact same connectivity policy as an individual download.
  bool downloadChapterNowOrQueue({
    required String chapterId,
    required List<Lecture> lectures,
    required bool isOnline,
    required bool isWifi,
  }) {
    if (!isOnline || (downloadOnWifiOnly && !isWifi)) {
      for (final lecture in lectures) {
        if (!isDownloaded(lecture.id)) unawaited(queueDownload(lecture));
      }
      return false;
    }
    unawaited(downloadChapter(chapterId, lectures));
    return true;
  }

  // ── Commands ─────────────────────────────────────────────────────────────

  Future<void> download(Lecture lecture) async {
    if (_statuses[lecture.id] == DownloadStatus.downloading) return;

    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    final attemptToken = _newAttemptToken();
    final downloadKey = _downloadKey(
      lecture.id,
      seriesId,
      generation,
      attemptToken,
    );
    final hadValidDownload = _downloadedIds.contains(lecture.id) &&
        DownloadService.existsSync(lecture.id, seriesId: seriesId);

    _statuses[lecture.id] = DownloadStatus.downloading;
    _progress[lecture.id] = 0.0;
    _failures.remove(lecture.id);
    _attemptTokens[lecture.id] = attemptToken;
    _activeDownloadKeys.add(downloadKey);
    notifyListeners();

    var lastNotifiedProgress = -1.0;
    var shouldNotifyAfterAttempt = false;

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
        operationOwnerKey: attemptToken,
        onProgress: (p) {
          if (!_isCurrentAttempt(
                lecture.id,
                attemptToken,
                generation,
                seriesId,
              ) ||
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

      if (!_isCurrentAttempt(
            lecture.id,
            attemptToken,
            generation,
            seriesId,
          ) ||
          _statuses[lecture.id] != DownloadStatus.downloading) {
        await DownloadService.delete(
          lecture.id,
          seriesId: seriesId,
          cancelKey: downloadKey,
          expectedOwnerKey: attemptToken,
        );
        return;
      }

      final wasDownloaded = _downloadedIds.contains(lecture.id);
      _statuses[lecture.id] = DownloadStatus.downloaded;
      _downloadedIds.add(lecture.id);
      _downloadedMetadata[lecture.id] =
          SavedLectureMetadata.fromLecture(lecture);
      _unavailableMetadata.remove(lecture.id);
      _progress.remove(lecture.id);
      await Future.wait([
        PreferencesService.instance
            .saveDownloadedIds(_downloadedIds, prefix: prefix),
        PreferencesService.instance.saveDownloadedMetadata(
          _allMetadata,
          prefix: prefix,
        ),
      ]);
      if (!_isCurrentAttempt(
        lecture.id,
        attemptToken,
        generation,
        seriesId,
      )) {
        return;
      }
      await _removeQueuedDownload(lecture.id);
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
      if (_isCurrentAttempt(
        lecture.id,
        attemptToken,
        generation,
        seriesId,
      )) {
        _resetAfterCancel(lecture.id, seriesId: seriesId);
      }
    } on DownloadException catch (error) {
      debugPrint('DownloadsProvider: download error for ${lecture.id}: $error');
      if (_isCurrentAttempt(
            lecture.id,
            attemptToken,
            generation,
            seriesId,
          ) &&
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
      if (_isCurrentAttempt(
            lecture.id,
            attemptToken,
            generation,
            seriesId,
          ) &&
          _statuses[lecture.id] == DownloadStatus.downloading) {
        _statuses[lecture.id] = hadValidDownload
            ? DownloadStatus.downloaded
            : DownloadStatus.failed;
        _progress.remove(lecture.id);
        _failures[lecture.id] = DownloadTransferException('$e');
        unawaited(DownloadNotificationService.instance.dismiss(lecture.id));
      }
    } finally {
      shouldNotifyAfterAttempt = _isCurrentAttempt(
        lecture.id,
        attemptToken,
        generation,
        seriesId,
      );
      _activeDownloadKeys.remove(downloadKey);
      if (_attemptTokens[lecture.id] == attemptToken) {
        _attemptTokens.remove(lecture.id);
      }
    }
    if (shouldNotifyAfterAttempt) {
      notifyListeners();
    }
  }

  /// Aborts an in-flight download and clears progress immediately.
  bool cancelDownload(String lectureId) {
    if (_statuses[lectureId] == DownloadStatus.queued) {
      _statuses[lectureId] = DownloadStatus.notDownloaded;
      unawaited(_removeQueuedDownload(lectureId));
      notifyListeners();
      return true;
    }
    if (_statuses[lectureId] != DownloadStatus.downloading) return false;
    final seriesId = _seriesId;
    final attemptToken = _attemptTokens[lectureId];
    if (attemptToken == null) return false;
    final cancelled = DownloadService.cancel(
      _downloadKey(lectureId, seriesId, _generation, attemptToken),
    );
    if (!cancelled) return false;
    _resetAfterCancel(lectureId, seriesId: seriesId);
    notifyListeners();
    return true;
  }

  /// Downloads all lectures in a chapter serially. Safe to call if already running.
  Future<void> downloadChapter(String chapterId, List<Lecture> lectures) async {
    if (_downloadingChapterIds.contains(chapterId)) return;
    final generation = _generation;
    final seriesId = _seriesId;
    _downloadingChapterIds.add(chapterId);
    _cancelledChapterIds.remove(chapterId);
    // Keep every remaining chapter job durable before starting the first
    // transfer. If the process dies between lectures, startup can reconcile
    // the same per-lecture queue without duplicating completed files.
    for (final lecture in lectures) {
      if (!isDownloaded(lecture.id)) await queueDownload(lecture);
    }
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
    unawaited(_removeQueuedDownloadsForChapter(chapterId));
    notifyListeners();
  }

  Future<void> _removeQueuedDownloadsForChapter(String chapterId) async {
    final before = _queuedDownloads.length;
    _queuedDownloads.removeWhere((row) => row.chapterId == chapterId);
    if (_queuedDownloads.length == before) return;
    await PreferencesService.instance
        .saveQueuedDownloads(_queuedDownloads, prefix: _prefix);
  }

  Future<void> delete(String lectureId) async {
    final generation = _generation;
    final seriesId = _seriesId;
    final prefix = _prefix;
    if (isDownloading(lectureId)) {
      if (cancelDownload(lectureId)) return;
      // Promotion has begun. Mark the user intent now so the successful
      // operation's completion cannot re-add the file while delete() waits for
      // its finalizer and removes the captured-series destination.
      _statuses[lectureId] = DownloadStatus.notDownloaded;
      _progress.remove(lectureId);
      _failures.remove(lectureId);
      notifyListeners();
    }
    unawaited(DownloadNotificationService.instance.dismiss(lectureId));
    // Read the size before deleting the file, then subtract incrementally.
    final freed = DownloadService.fileSizeSync(lectureId, seriesId: seriesId);
    await DownloadService.delete(
      lectureId,
      seriesId: seriesId,
      cancelKey: _deleteKey(lectureId, generation),
    );
    if (!_isCurrentOperation(generation, seriesId)) return;
    _statuses[lectureId] = DownloadStatus.notDownloaded;
    _downloadedIds.remove(lectureId);
    _downloadedMetadata.remove(lectureId);
    _unavailableMetadata.remove(lectureId);
    _failures.remove(lectureId);
    await Future.wait([
      PreferencesService.instance
          .saveDownloadedIds(_downloadedIds, prefix: prefix),
      PreferencesService.instance.saveDownloadedMetadata(
        _allMetadata,
        prefix: prefix,
      ),
    ]);
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
          cancelKey: _deleteKey(lecture.id, generation),
        );
        if (!_isCurrentOperation(generation, seriesId)) return;
        _statuses[lecture.id] = DownloadStatus.notDownloaded;
        _downloadedIds.remove(lecture.id);
        _downloadedMetadata.remove(lecture.id);
        _unavailableMetadata.remove(lecture.id);
        _reduceTotalBytes(freed);
      }
    }
    await Future.wait([
      PreferencesService.instance
          .saveDownloadedIds(_downloadedIds, prefix: prefix),
      PreferencesService.instance.saveDownloadedMetadata(
        _allMetadata,
        prefix: prefix,
      ),
    ]);
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
        cancelKey: _deleteKey(id, generation),
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
    _downloadedMetadata.clear();
    _unavailableMetadata.clear();
    _queuedDownloads.clear();
    _totalDownloadedBytes = 0;
    await Future.wait([
      PreferencesService.instance.saveDownloadedIds({}, prefix: prefix),
      PreferencesService.instance.saveDownloadedMetadata({}, prefix: prefix),
      PreferencesService.instance.saveQueuedDownloads({}, prefix: prefix),
    ]);
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
      _downloadedMetadata.remove(lectureId);
      _unavailableMetadata.remove(lectureId);
      unawaited(
        PreferencesService.instance
            .saveDownloadedIds(_downloadedIds, prefix: _prefix),
      );
      unawaited(
        PreferencesService.instance.saveDownloadedMetadata(
          _allMetadata,
          prefix: _prefix,
        ),
      );
      unawaited(_removeQueuedDownload(lectureId));
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
  void seedDownloadedMetadataForTest(SavedLectureMetadata row) {
    _statuses[row.id] = DownloadStatus.downloaded;
    _downloadedIds.add(row.id);
    _downloadedMetadata[row.id] = row;
  }

  @visibleForTesting
  void seedUnavailableMetadataForTest(SavedLectureMetadata row) {
    _unavailableMetadata[row.id] = row;
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
