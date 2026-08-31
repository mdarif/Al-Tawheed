import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/models/catalog.dart';

/// Controllable implementation of the production [AudioPlayback] seam.
///
/// Tests use its public event methods to model backend events; they never set
/// notifier state directly, so every assertion exercises PlayerNotifier's
/// production subscriptions and commands.
class FakeAudioPlayback implements AudioPlayback {
  final _states = StreamController<PlaybackState>.broadcast(sync: true);
  final _playbackEvents =
      StreamController<AudioPlaybackEvent<PlaybackState>>.broadcast(sync: true);
  final _positions =
      StreamController<AudioPlaybackEvent<Duration>>.broadcast(sync: true);
  final _durations =
      StreamController<AudioPlaybackEvent<Duration?>>.broadcast(sync: true);
  final _processing =
      StreamController<AudioPlaybackEvent<ProcessingState>>.broadcast(
    sync: true,
  );
  final _errors =
      StreamController<AudioPlaybackEvent<Object>>.broadcast(sync: true);

  final List<LoadCall> loads = [];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<Duration> seeks = [];
  final List<double> speeds = [];
  Object? failNextLoad;
  Completer<void>? pendingLoad;

  int get _latestSessionId => loads.last.sessionId;

  @override
  Future<void> Function()? onSkipToNext;

  @override
  Future<void> Function()? onSkipToPrevious;

  @override
  Stream<PlaybackState> get rawPlaybackState => _states.stream;

  Stream<PlaybackState> get playbackState => _states.stream;

  @override
  Stream<AudioPlaybackEvent<PlaybackState>> get playbackEvents =>
      _playbackEvents.stream;

  @override
  Stream<AudioPlaybackEvent<Duration>> get positionEvents => _positions.stream;

  @override
  Stream<AudioPlaybackEvent<Duration?>> get durationEvents => _durations.stream;

  @override
  Stream<AudioPlaybackEvent<ProcessingState>> get processingEvents =>
      _processing.stream;

  @override
  Stream<AudioPlaybackEvent<Object>> get errorEvents => _errors.stream;

  @override
  Future<void> loadLecture(
    Lecture lecture, {
    required int sessionId,
    Duration startFrom = Duration.zero,
    String? localFilePath,
    String artist = '',
    String? displayTitle,
  }) async {
    loads.add(
      LoadCall(
        lecture: lecture,
        sessionId: sessionId,
        startFrom: startFrom,
        localFilePath: localFilePath,
      ),
    );
    final error = failNextLoad;
    failNextLoad = null;
    if (error != null) throw error;
    await pendingLoad?.future;
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);

  @override
  Future<void> stop() async => stopCalls++;

  void emitPlaybackState({
    int? sessionId,
    bool playing = false,
    AudioProcessingState processingState = AudioProcessingState.ready,
    double speed = 1.0,
  }) =>
      _playbackEvents.add(
        AudioPlaybackEvent(
          sessionId ?? _latestSessionId,
          PlaybackState(
            processingState: processingState,
            playing: playing,
            speed: speed,
          ),
        ),
      );

  void emitPosition(Duration position, {int? sessionId}) => _positions
      .add(AudioPlaybackEvent(sessionId ?? _latestSessionId, position));
  void emitDuration(Duration? duration, {int? sessionId}) => _durations
      .add(AudioPlaybackEvent(sessionId ?? _latestSessionId, duration));
  void emitCompleted({int? sessionId}) => _processing.add(
        AudioPlaybackEvent(
          sessionId ?? _latestSessionId,
          ProcessingState.completed,
        ),
      );
  void emitError(Object error, {int? sessionId}) =>
      _errors.add(AudioPlaybackEvent(sessionId ?? _latestSessionId, error));

  /// Models TawheedAudioHandler's production failure fan-out: the same backend
  /// error reaches both BaseAudioHandler.playbackState and errorEvents.
  void emitHandlerError(Object error, {int? sessionId}) {
    final taggedSessionId = sessionId ?? _latestSessionId;
    _states.addError(AudioPlaybackFailure(taggedSessionId, error));
    _errors.add(AudioPlaybackEvent(taggedSessionId, error));
  }

  Future<void> triggerNext() => onSkipToNext?.call() ?? Future.value();
  Future<void> triggerPrevious() => onSkipToPrevious?.call() ?? Future.value();

  Future<void> dispose() async {
    await _states.close();
    await _playbackEvents.close();
    await _positions.close();
    await _durations.close();
    await _processing.close();
    await _errors.close();
  }
}

class LoadCall {
  const LoadCall({
    required this.lecture,
    required this.sessionId,
    required this.startFrom,
    required this.localFilePath,
  });

  final Lecture lecture;
  final int sessionId;
  final Duration startFrom;
  final String? localFilePath;
}
