import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';

class PlayerNotifier extends ChangeNotifier {
  final TawheedAudioHandler _handler;
  final ProgressProvider _progress;
  final DownloadsProvider _downloads;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _saveTimer;

  Lecture? _current;
  List<Lecture> _queue = const [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  double _speed = 1.0;
  DateTime? _lastPositionNotify;

  PlayerNotifier(this._handler, this._progress, this._downloads) {
    // Restore saved playback speed immediately so it's applied on first play
    final savedSpeed = PreferencesService.instance.playbackSpeed;
    if (savedSpeed != 1.0) {
      _speed = savedSpeed;
      _handler.setSpeed(savedSpeed);
    }
    _subs.addAll([
      _handler.playbackState.listen((state) {
        final wasPlaying = _playing;
        _playing = state.playing;
        _loading = state.processingState == AudioProcessingState.loading ||
            state.processingState == AudioProcessingState.buffering;
        _speed = state.speed;
        // Save whenever playback stops for any reason — covers lock screen
        // pause, incoming calls, headphone disconnect, background kill, etc.
        if (wasPlaying && !_playing) _saveCurrentPosition();
        notifyListeners();
      }),
      _handler.player.positionStream.listen((pos) {
        _position = pos;
        final now = DateTime.now();
        if (_lastPositionNotify == null ||
            now.difference(_lastPositionNotify!) >=
                const Duration(milliseconds: 200)) {
          _lastPositionNotify = now;
          notifyListeners();
        }
      }),
      _handler.player.durationStream.listen((dur) {
        if (dur != null) {
          _duration = dur;
          notifyListeners();
        }
      }),
      _handler.player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _onCompleted();
      }),
    ]);
  }

  // ── Getters ──────────────────────────────────────────────────────────────
  Lecture? get current => _current;
  bool get hasAudio => _current != null;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;

  double get progress {
    final total = _duration.inMilliseconds;
    return total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
  }

  int get _currentIndex => _queue.indexWhere((l) => l.id == _current?.id);
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex >= 0 && _currentIndex < _queue.length - 1;

  // ── Commands ─────────────────────────────────────────────────────────────

  Future<void> loadAndPlay(Lecture lecture, List<Lecture> queue) async {
    _saveCurrentPosition(); // persist position of previous lecture before switching
    _cancelSaveTimer();

    _current = lecture;
    _queue = List.unmodifiable(queue);
    _position = Duration.zero;
    _duration = Duration(seconds: lecture.durationSeconds);
    _loading = true;
    notifyListeners();

    // Restore saved position — skip if within 30s of start or within 30s of end
    final saved = _progress.getPositionSeconds(lecture.id);
    final resumeAt = saved > 30 && saved < lecture.durationSeconds - 30
        ? Duration(seconds: saved)
        : Duration.zero;

    final localPath = _downloads.localPathIfDownloaded(lecture.id);
    await _handler.loadLecture(
      lecture,
      startFrom: resumeAt,
      localFilePath: localPath,
    );
    _startSaveTimer();
  }

  Future<void> playPause() async {
    if (_playing) {
      _saveCurrentPosition(); // save before pausing so position survives restart
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> seek(Duration position) => _handler.seek(position);

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
      await loadAndPlay(_queue[idx + 1], _queue);
    }
  }

  Future<void> playPrevious() async {
    final idx = _currentIndex;
    if (idx > 0) await loadAndPlay(_queue[idx - 1], _queue);
  }

  Future<void> setSpeed(double s) async {
    await _handler.setSpeed(s);
    await PreferencesService.instance.savePlaybackSpeed(s);
  }

  Future<void> stop() async {
    _saveCurrentPosition();
    _cancelSaveTimer();
    await _handler.stop();
    _current = null;
    notifyListeners();
  }

  // ── Progress persistence ─────────────────────────────────────────────────

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_playing) _saveCurrentPosition(notify: false);
    });
  }

  void _cancelSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = null;
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

  void _onCompleted() {
    // Save completed position so the tile shows 100% done
    final id = _current?.id;
    final total = _current?.durationSeconds;
    if (id != null && total != null) {
      _progress.saveProgress(id, total);
    }
    // Auto-advance
    final idx = _currentIndex;
    if (idx >= 0 && idx < _queue.length - 1) {
      loadAndPlay(_queue[idx + 1], _queue);
    }
  }

  @override
  void dispose() {
    _saveCurrentPosition();
    _cancelSaveTimer();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
