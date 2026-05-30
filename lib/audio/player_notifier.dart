import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/models/catalog.dart';

class PlayerNotifier extends ChangeNotifier {
  final TawheedAudioHandler _handler;
  final List<StreamSubscription<dynamic>> _subs = [];

  Lecture? _current;
  List<Lecture> _queue = const [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  double _speed = 1.0;

  PlayerNotifier(this._handler) {
    _subs.addAll([
      _handler.playbackState.listen((state) {
        _playing = state.playing;
        _loading = state.processingState == AudioProcessingState.loading ||
            state.processingState == AudioProcessingState.buffering;
        _speed = state.speed;
        notifyListeners();
      }),
      _handler.player.positionStream.listen((pos) {
        _position = pos;
        notifyListeners();
      }),
      _handler.player.durationStream.listen((dur) {
        if (dur != null) {
          _duration = dur;
          notifyListeners();
        }
      }),
      // Auto-advance to next lecture when current one finishes
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
    _current = lecture;
    _queue = List.unmodifiable(queue);
    _position = Duration.zero;
    _duration = Duration(seconds: lecture.durationSeconds);
    _loading = true;
    notifyListeners();
    await _handler.loadLecture(lecture);
  }

  Future<void> playPause() =>
      _playing ? _handler.pause() : _handler.play();

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

  Future<void> setSpeed(double s) => _handler.setSpeed(s);

  Future<void> stop() async {
    await _handler.stop();
    _current = null;
    notifyListeners();
  }

  void _onCompleted() {
    final idx = _currentIndex;
    if (idx >= 0 && idx < _queue.length - 1) {
      loadAndPlay(_queue[idx + 1], _queue);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
