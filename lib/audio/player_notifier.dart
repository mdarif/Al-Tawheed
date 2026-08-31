import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:myapp/app_config.dart';
import 'package:myapp/audio/playback_mode.dart';
import 'package:myapp/audio/playback_source.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';

class PlayerNotifier extends ChangeNotifier {
  final AudioPlayback _handler;
  final ProgressProvider _progress;
  final DownloadsProvider _downloads;
  final ConnectivityProvider _connectivity;
  final CatalogProvider? _catalog;
  final Duration _saveInterval;
  final Duration _stuckBufferingDelay;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _saveTimer;
  Timer? _stuckBufferingTimer;

  Lecture? _current;
  List<Lecture> _queue = const [];
  PlaybackMode _playbackMode = PlaybackMode.casual;
  Chapter? _studyChapter;
  String? _pendingStudyChapterCompleteId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  bool _isStuckBuffering = false;
  double _speed = 1.0;
  DateTime? _lastPositionNotify;
  PlaybackSource _playbackSource = PlaybackSource.stream;
  bool _pendingNextBlocked = false;
  String? _pendingNextBlockedTitle;
  Lecture? _pendingNextBlockedLecture;
  bool _pendingAllLecturesComplete = false;
  Object? _playbackError;
  int _loadEpoch = 0;
  int _activeSessionId = 0;
  int? _errorSessionId;
  bool _disposed = false;

  PlayerNotifier(
    this._handler,
    this._progress,
    this._downloads,
    this._connectivity, [
    this._catalog,
  ])  : _saveInterval = const Duration(seconds: 5),
        _stuckBufferingDelay = const Duration(seconds: 8) {
    _initialize();
  }

  /// Test-only construction keeps timing deterministic while all state changes
  /// still come from the production notifier and injected audio backend.
  @visibleForTesting
  PlayerNotifier.forTesting(
    this._handler,
    this._progress,
    this._downloads,
    this._connectivity, {
    CatalogProvider? catalog,
    Duration saveInterval = const Duration(seconds: 5),
    Duration stuckBufferingDelay = const Duration(seconds: 8),
  })  : _catalog = catalog,
        _saveInterval = saveInterval,
        _stuckBufferingDelay = stuckBufferingDelay {
    _initialize();
  }

  void _initialize() {
    final savedSpeed = PreferencesService.instance.playbackSpeed;
    if (savedSpeed != 1.0) {
      _speed = savedSpeed;
      _handler.setSpeed(savedSpeed);
    }
    _connectivity.addListener(_onConnectivityChanged);
    _downloads.addListener(_onDownloadsChanged);
    // Lock-screen / notification skip-to-next/previous taps land in the
    // handler (BaseAudioHandler.skipToNext/Previous) — wire them to our
    // queue logic, since the handler itself doesn't know about the queue.
    _handler.onSkipToNext = playNext;
    _handler.onSkipToPrevious = playPrevious;
    _subs.addAll([
      _handler.playbackEvents.listen((event) {
        if (!_accepts(event.sessionId)) return;
        final state = event.value;
        final wasLoading = _loading;
        final wasPlaying = _playing;
        _playing = state.playing;
        _loading = state.processingState == AudioProcessingState.loading ||
            state.processingState == AudioProcessingState.buffering;
        _speed = state.speed;

        if (_loading && !wasLoading) {
          _startStuckBufferingTimer();
        } else if (!_loading) {
          _cancelStuckBufferingTimer();
        }

        if (wasPlaying && !_playing) _saveCurrentPosition();
        notifyListeners();
      }),
      _handler.positionEvents.listen((event) {
        if (!_accepts(event.sessionId)) return;
        final pos = event.value;
        _position = pos;
        final now = DateTime.now();
        if (_lastPositionNotify == null ||
            now.difference(_lastPositionNotify!) >=
                const Duration(milliseconds: 200)) {
          _lastPositionNotify = now;
          notifyListeners();
        }
      }),
      _handler.durationEvents.listen((event) {
        if (!_accepts(event.sessionId)) return;
        final dur = event.value;
        if (dur != null) {
          _duration = dur;
          notifyListeners();
        }
      }),
      _handler.processingEvents.listen((event) {
        if (_accepts(event.sessionId) &&
            event.value == ProcessingState.completed) {
          _onCompleted();
        }
      }),
      // TawheedAudioHandler intentionally emits a backend failure through both
      // audio_service playbackState and its typed error stream. Handle both;
      // _handlePlaybackError de-duplicates that one backend failure.
      _handler.rawPlaybackState.listen(
        (_) {},
        onError: (Object error, StackTrace _) {
          if (error is AudioPlaybackFailure) {
            _handlePlaybackError(error.error, sessionId: error.sessionId);
          } else {
            _handlePlaybackError(error, sessionId: _activeSessionId);
          }
        },
      ),
      _handler.errorEvents.listen(
        (event) => _handlePlaybackError(
          event.value,
          sessionId: event.sessionId,
        ),
      ),
    ]);
  }

  // ── Getters ──────────────────────────────────────────────────────────────
  Lecture? get current => _current;
  bool get hasAudio => _current != null;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  bool get isStuckBuffering => _isStuckBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;
  PlaybackMode get playbackMode => _playbackMode;
  Chapter? get studyChapter => _studyChapter;
  String? get pendingStudyChapterCompleteId => _pendingStudyChapterCompleteId;
  PlaybackSource get playbackSource => _playbackSource;
  bool get pendingNextBlocked => _pendingNextBlocked;
  String? get pendingNextBlockedTitle => _pendingNextBlockedTitle;
  Lecture? get pendingNextBlockedLecture => _pendingNextBlockedLecture;
  bool get pendingAllLecturesComplete => _pendingAllLecturesComplete;
  bool get hasPlaybackError => _playbackError != null;

  String? get studyContextLabel => formatStudyContextLabel(
        mode: _playbackMode,
        chapter: _studyChapter,
        currentIndex: _currentIndex,
        queueLength: _queue.length,
      );

  double get progress {
    final total = _duration.inMilliseconds;
    return total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
  }

  int get _currentIndex => _queue.indexWhere((l) => l.id == _current?.id);
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex >= 0 && _currentIndex < _queue.length - 1;

  // ── Commands ─────────────────────────────────────────────────────────────

  Future<void> startStudySession({
    required Lecture lecture,
    required List<Lecture> queue,
    required Chapter chapter,
  }) =>
      loadAndPlay(
        lecture,
        queue,
        mode: PlaybackMode.study,
        studyChapter: chapter,
      );

  Future<void> loadAndPlay(
    Lecture lecture,
    List<Lecture> queue, {
    PlaybackMode? mode,
    Chapter? studyChapter,
  }) async {
    if (_disposed) return;
    final loadEpoch = ++_loadEpoch;
    _activeSessionId = loadEpoch;
    if (mode != null) {
      _playbackMode = mode;
      _studyChapter = studyChapter;
    } else {
      _playbackMode = PlaybackMode.casual;
      _studyChapter = null;
    }
    _pendingStudyChapterCompleteId = null;
    _pendingAllLecturesComplete = false;
    _saveCurrentPosition();
    _cancelSaveTimer();
    _cancelStuckBufferingTimer();

    _current = lecture;
    _queue = List.unmodifiable(queue);
    _position = Duration.zero;
    _duration = Duration(seconds: lecture.durationSeconds);
    _isStuckBuffering = false;
    _playbackError = null;
    _errorSessionId = null;

    final localPath = _downloads.localPathIfDownloaded(lecture.id);

    if (_connectivity.isOffline && localPath == null) {
      _playbackSource = PlaybackSource.blocked;
      _loading = false;
      // Do not leave the previous stream playing behind a blocked request.
      await _runPlaybackCommand(_handler.stop, sessionId: loadEpoch);
      if (!_accepts(loadEpoch)) return;
      notifyListeners();
      return;
    }

    _playbackSource =
        localPath != null ? PlaybackSource.local : PlaybackSource.stream;
    _loading = true;
    notifyListeners();
    // A backend may stay in its initial loading state without emitting a
    // false → true transition, so begin observing the load here as well.
    _startStuckBufferingTimer();

    final saved = _progress.getPositionSeconds(lecture.id);
    final resumeAt = saved > 30 && saved < lecture.durationSeconds - 30
        ? Duration(seconds: saved)
        : Duration.zero;

    final lang = _catalog?.currentSeriesLanguage ?? 'ur';
    final displayTitle = lecture.title.forLanguage(lang);
    final speaker = _catalog?.catalog?.book.speaker.forLanguage(lang);

    try {
      await _handler.loadLecture(
        lecture,
        sessionId: loadEpoch,
        startFrom: resumeAt,
        localFilePath: localPath,
        artist: speaker?.isNotEmpty == true ? speaker! : AppConfig.appTitle,
        displayTitle: displayTitle.isNotEmpty ? displayTitle : null,
      );
      if (_disposed || loadEpoch != _loadEpoch) return;
      _startSaveTimer();
    } catch (error) {
      if (_disposed || loadEpoch != _loadEpoch) return;
      _handlePlaybackError(error);
    }
  }

  Future<void> playPause() async {
    if (_playing) {
      _saveCurrentPosition();
      await _runPlaybackCommand(_handler.pause);
    } else {
      await _runPlaybackCommand(_handler.play);
    }
  }

  Future<void> seek(Duration position) =>
      _runPlaybackCommand(() => _handler.seek(position));

  Future<void> skipForward() {
    final next = _position + const Duration(seconds: 10);
    return seek(next < _duration ? next : _duration);
  }

  Future<void> skipBackward() {
    final prev = _position - const Duration(seconds: 10);
    return seek(prev > Duration.zero ? prev : Duration.zero);
  }

  Future<void> playNext() async {
    final idx = _currentIndex;
    if (idx >= 0 && idx < _queue.length - 1) {
      final next = _queue[idx + 1];
      if (_connectivity.isOffline && !_downloads.isDownloaded(next.id)) {
        _pendingNextBlocked = true;
        _pendingNextBlockedTitle = next.title.en;
        _pendingNextBlockedLecture = next;
        notifyListeners();
        return;
      }
      await loadAndPlay(
        next,
        _queue,
        mode: _playbackMode,
        studyChapter: _studyChapter,
      );
    }
  }

  Future<void> playPrevious() async {
    final idx = _currentIndex;
    if (idx > 0) {
      await loadAndPlay(
        _queue[idx - 1],
        _queue,
        mode: _playbackMode,
        studyChapter: _studyChapter,
      );
    }
  }

  Future<void> setSpeed(double s) async {
    try {
      await _handler.setSpeed(s);
    } catch (error) {
      _handlePlaybackError(error);
      return;
    }
    await PreferencesService.instance.savePlaybackSpeed(s);
  }

  /// Retries the same lecture through the same load path used by first play.
  /// This preserves the source choice (local versus stream) and resume policy.
  Future<void> retryPlayback() async {
    final current = _current;
    if (current == null) return;
    await loadAndPlay(
      current,
      _queue,
      mode: _playbackMode,
      studyChapter: _studyChapter,
    );
  }

  Future<void> stop() async {
    final stopSessionId = ++_loadEpoch;
    _activeSessionId = stopSessionId;
    _saveCurrentPosition();
    _cancelSaveTimer();
    _cancelStuckBufferingTimer();
    await _runPlaybackCommand(_handler.stop, sessionId: stopSessionId);
    if (!_accepts(stopSessionId)) return;
    _current = null;
    _playbackMode = PlaybackMode.casual;
    _studyChapter = null;
    _pendingStudyChapterCompleteId = null;
    _pendingNextBlocked = false;
    _pendingNextBlockedTitle = null;
    _pendingNextBlockedLecture = null;
    _playbackSource = PlaybackSource.stream;
    _isStuckBuffering = false;
    _playbackError = null;
    _errorSessionId = null;
    notifyListeners();
  }

  void clearPendingStudyComplete() {
    _pendingStudyChapterCompleteId = null;
  }

  void clearPendingNextBlocked() {
    _pendingNextBlocked = false;
    _pendingNextBlockedTitle = null;
    _pendingNextBlockedLecture = null;
    notifyListeners();
  }

  void clearPendingAllLecturesComplete() {
    _pendingAllLecturesComplete = false;
  }

  /// Injects playback state for the offline status strip without touching
  /// the audio player — for tests only.
  @visibleForTesting
  void setPlaybackStateForTest(
    Lecture lecture, {
    PlaybackSource source = PlaybackSource.stream,
    bool isStuckBuffering = false,
    bool isPlaying = false,
  }) {
    _current = lecture;
    _queue = [lecture];
    _duration = Duration(seconds: lecture.durationSeconds);
    _playbackSource = source;
    _isStuckBuffering = isStuckBuffering;
    _playing = isPlaying;
    notifyListeners();
  }

  /// Simulates the last lecture of a study chapter finishing — for tests only.
  @visibleForTesting
  void setPendingStudyCompleteForTest(String chapterId) {
    _pendingStudyChapterCompleteId = chapterId;
    notifyListeners();
  }

  // ── Connectivity recovery ────────────────────────────────────────────────

  void _onConnectivityChanged() {
    if (_disposed) return;
    if (_connectivity.isOnline && _isStuckBuffering && _current != null) {
      // Network came back while we were buffering — reload and resume.
      _isStuckBuffering = false;
      loadAndPlay(
        _current!,
        _queue,
        mode: _playbackMode,
        studyChapter: _studyChapter,
      );
    } else if (_connectivity.isOnline &&
        _playbackSource == PlaybackSource.blocked &&
        _current != null) {
      // Was blocked because offline; now online so the UI can unlock.
      // Don't auto-play — user may have put phone down. Just clear blocked state.
      _playbackSource = PlaybackSource.stream;
      notifyListeners();
    } else {
      // Went offline — notify so strip appears immediately without waiting for stuck timer.
      notifyListeners();
    }

    if (_connectivity.isOnline) {
      unawaited(
        _downloads.tryStartQueuedDownload(isWifi: _connectivity.isWifi),
      );
    }
  }

  void _onDownloadsChanged() {
    if (_disposed) return;
    final id = _current?.id;
    if (id == null || _downloads.isDownloaded(id)) return;

    if (_playbackSource != PlaybackSource.local) return;

    unawaited(_reloadAfterActiveLocalDeletion());
  }

  // ── Progress persistence ─────────────────────────────────────────────────

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(_saveInterval, (_) {
      if (_playing) _saveCurrentPosition(notify: false);
    });
  }

  void _cancelSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  void _startStuckBufferingTimer() {
    _stuckBufferingTimer?.cancel();
    _stuckBufferingTimer = Timer(_stuckBufferingDelay, () {
      if (!_disposed && _loading) {
        _isStuckBuffering = true;
        notifyListeners();
      }
    });
  }

  void _cancelStuckBufferingTimer() {
    _stuckBufferingTimer?.cancel();
    _stuckBufferingTimer = null;
    _isStuckBuffering = false;
  }

  void _saveCurrentPosition({bool notify = true}) {
    final id = _current?.id;
    if (id != null && _position.inSeconds > 0) {
      if (notify) {
        _progress.saveProgress(id, _position.inSeconds);
      } else {
        _progress.saveProgressSilent(id, _position.inSeconds);
      }
    }
  }

  bool _accepts(int sessionId) => !_disposed && sessionId == _activeSessionId;

  Future<void> _runPlaybackCommand(
    Future<void> Function() command, {
    int? sessionId,
  }) async {
    try {
      await command();
    } catch (error) {
      _handlePlaybackError(error, sessionId: sessionId);
    }
  }

  void _handlePlaybackError(Object error, {int? sessionId}) {
    final effectiveSessionId = sessionId ?? _activeSessionId;
    if (!_accepts(effectiveSessionId)) return;
    if (_playbackError != null &&
        _errorSessionId == effectiveSessionId &&
        identical(_playbackError, error)) {
      return;
    }
    _playbackError = error;
    _errorSessionId = effectiveSessionId;
    _loading = false;
    _playing = false;
    _isStuckBuffering = false;
    _cancelStuckBufferingTimer();
    _saveCurrentPosition();
    notifyListeners();
  }

  Future<void> _reloadAfterActiveLocalDeletion() async {
    final current = _current;
    if (current == null || _playbackSource != PlaybackSource.local) return;
    if (_connectivity.isOffline) {
      final deletionSessionId = ++_loadEpoch;
      _activeSessionId = deletionSessionId;
      _playbackSource = PlaybackSource.blocked;
      _loading = false;
      await _runPlaybackCommand(_handler.stop, sessionId: deletionSessionId);
      if (!_accepts(deletionSessionId)) return;
      notifyListeners();
      return;
    }
    await loadAndPlay(
      current,
      _queue,
      mode: _playbackMode,
      studyChapter: _studyChapter,
    );
  }

  void _onCompleted() {
    if (_disposed) return;
    final id = _current?.id;
    final total = _current?.durationSeconds;
    if (id != null && total != null) {
      _progress.saveProgress(id, total);
    }

    final idx = _currentIndex;
    if (shouldCompleteStudyChapter(
      mode: _playbackMode,
      currentIndex: idx,
      queueLength: _queue.length,
    )) {
      _pendingStudyChapterCompleteId = _studyChapter?.id;
      notifyListeners();
      return;
    }

    if (idx >= 0 && idx < _queue.length - 1) {
      final next = _queue[idx + 1];
      if (_connectivity.isOffline && !_downloads.isDownloaded(next.id)) {
        _pendingNextBlocked = true;
        _pendingNextBlockedTitle = next.title.en;
        _pendingNextBlockedLecture = next;
        notifyListeners();
        return;
      }
      loadAndPlay(
        next,
        _queue,
        mode: _playbackMode,
        studyChapter: _studyChapter,
      );
    } else if (idx == _queue.length - 1) {
      final allLectures = _catalog?.catalog?.lectures;
      if (allLectures != null && _progress.allComplete(allLectures)) {
        _pendingAllLecturesComplete = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _activeSessionId = ++_loadEpoch;
    _connectivity.removeListener(_onConnectivityChanged);
    _downloads.removeListener(_onDownloadsChanged);
    _saveCurrentPosition();
    _cancelSaveTimer();
    _cancelStuckBufferingTimer();
    for (final s in _subs) {
      s.cancel();
    }
    // The handler outlives this notifier (it is the app-wide audio_service
    // singleton), so callbacks must not keep a disposed notifier alive.
    _handler.onSkipToNext = null;
    _handler.onSkipToPrevious = null;
    super.dispose();
  }
}
