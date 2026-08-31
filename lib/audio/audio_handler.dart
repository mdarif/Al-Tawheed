import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/catalog.dart';

/// The small portion of the audio backend that owns playback policy needs.
///
/// [TawheedAudioHandler] is the production implementation. Keeping this at
/// the app boundary lets [PlayerNotifier] react to real backend events without
/// depending on a platform-backed [AudioPlayer] in its tests.
class AudioPlaybackEvent<T> {
  const AudioPlaybackEvent(this.sessionId, this.value);

  final int sessionId;
  final T value;
}

/// An error from the backend's playback-state stream tagged with the source
/// load that produced it. Stream errors otherwise carry no correlation data.
class AudioPlaybackFailure implements Exception {
  const AudioPlaybackFailure(this.sessionId, this.error);

  final int sessionId;
  final Object error;
}

abstract interface class AudioPlayback {
  /// Raw audio_service state stream. Its error channel is intentionally part
  /// of the contract because backend failures are delivered there too.
  Stream<PlaybackState> get rawPlaybackState;
  Stream<AudioPlaybackEvent<PlaybackState>> get playbackEvents;
  Stream<AudioPlaybackEvent<Duration>> get positionEvents;
  Stream<AudioPlaybackEvent<Duration?>> get durationEvents;
  Stream<AudioPlaybackEvent<ProcessingState>> get processingEvents;
  Stream<AudioPlaybackEvent<Object>> get errorEvents;

  set onSkipToNext(Future<void> Function()? callback);
  set onSkipToPrevious(Future<void> Function()? callback);

  Future<void> loadLecture(
    Lecture lecture, {
    required int sessionId,
    Duration startFrom = Duration.zero,
    String? localFilePath,
    String artist = AppConfig.appTitle,
    String? displayTitle,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
}

class TawheedAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements AudioPlayback {
  // just_audio's own `handleInterruptions` can race with a user-initiated
  // pause: if a focus interruption "begin" event lands while we're playing,
  // it pauses internally and arms its `_playInterrupted` flag, then an
  // "end" event auto-resumes — even if the user paused in between. We
  // disable it and track interruption-vs-user pauses ourselves so a manual
  // pause (e.g. from the lock screen) always wins and is never overridden.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final _playbackEvents =
      StreamController<AudioPlaybackEvent<PlaybackState>>.broadcast();
  final _rawPlaybackStates = StreamController<PlaybackState>.broadcast();
  final _positionEvents =
      StreamController<AudioPlaybackEvent<Duration>>.broadcast();
  final _durationEvents =
      StreamController<AudioPlaybackEvent<Duration?>>.broadcast();
  final _processingEvents =
      StreamController<AudioPlaybackEvent<ProcessingState>>.broadcast();
  final _errorEvents = StreamController<AudioPlaybackEvent<Object>>.broadcast();
  int _activeSessionId = 0;
  bool _pausedByInterruption = false;

  // The handler is just a thin just_audio wrapper — it doesn't know about the
  // playback queue (that lives in PlayerNotifier). Lock-screen / notification
  // skip-to-next/previous taps land here via BaseAudioHandler, so PlayerNotifier
  // wires these to its own playNext/playPrevious after construction.
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  TawheedAudioHandler() {
    _init();
    // Forward just_audio playback events into audio_service's playbackState
    // stream. `.listen()` rather than `.pipe()` — `pipe()`/`addStream()`
    // would permanently lock `playbackState` against direct `.add()` calls
    // (e.g. from `super.stop()`) for as long as the player's event stream
    // stays open, which is its entire lifetime.
    _player.playbackEventStream.map(_stateFromEvent).listen(
      (state) {
        playbackState.add(state);
        _rawPlaybackStates.add(state);
        _playbackEvents.add(AudioPlaybackEvent(_activeSessionId, state));
      },
      onError: (Object error, StackTrace stackTrace) {
        _errorEvents.add(AudioPlaybackEvent(_activeSessionId, error));
        playbackState.addError(error, stackTrace);
        _rawPlaybackStates.addError(
          AudioPlaybackFailure(_activeSessionId, error),
          stackTrace,
        );
      },
    );
    _player.positionStream.listen(
      (position) =>
          _positionEvents.add(AudioPlaybackEvent(_activeSessionId, position)),
    );
    _player.durationStream.listen(
      (duration) =>
          _durationEvents.add(AudioPlaybackEvent(_activeSessionId, duration)),
    );
    _player.processingStateStream.listen(
      (state) =>
          _processingEvents.add(AudioPlaybackEvent(_activeSessionId, state)),
    );
  }

  AudioPlayer get player => _player;

  @override
  Stream<PlaybackState> get rawPlaybackState => _rawPlaybackStates.stream;

  @override
  Stream<AudioPlaybackEvent<PlaybackState>> get playbackEvents =>
      _playbackEvents.stream;

  @override
  Stream<AudioPlaybackEvent<Duration>> get positionEvents =>
      _positionEvents.stream;

  @override
  Stream<AudioPlaybackEvent<Duration?>> get durationEvents =>
      _durationEvents.stream;

  @override
  Stream<AudioPlaybackEvent<ProcessingState>> get processingEvents =>
      _processingEvents.stream;

  @override
  Stream<AudioPlaybackEvent<Object>> get errorEvents => _errorEvents.stream;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.becomingNoisyEventStream.listen((_) => pause());

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(_player.volume / 2);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_player.playing) {
              _pausedByInterruption = true;
              _player.pause();
            }
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(min(1.0, _player.volume * 2));
            break;
          case AudioInterruptionType.pause:
            if (_pausedByInterruption) _player.play();
            _pausedByInterruption = false;
            break;
          case AudioInterruptionType.unknown:
            _pausedByInterruption = false;
            break;
        }
      }
    });
  }

  /// Load a lecture and begin playing, optionally resuming from [startFrom].
  /// If [localFilePath] is provided and exists on disk, plays offline.
  @override
  Future<void> loadLecture(
    Lecture lecture, {
    required int sessionId,
    Duration startFrom = Duration.zero,
    String? localFilePath,
    String artist = AppConfig.appTitle,
    String? displayTitle,
  }) async {
    _activeSessionId = sessionId;
    mediaItem.add(
      MediaItem(
        id: lecture.id,
        title: displayTitle ?? lecture.title.en,
        artist: artist,
        duration: Duration(seconds: lecture.durationSeconds),
      ),
    );

    final useLocal = localFilePath != null && File(localFilePath).existsSync();
    final source = useLocal
        ? AudioSource.uri(Uri.file(localFilePath))
        : AudioSource.uri(Uri.parse(lecture.audioUrl));

    await _player.setAudioSource(source, initialPosition: startFrom);
    // A slower old source load must never resume over the latest request.
    if (sessionId != _activeSessionId) return;
    await play();
  }

  // ── BaseAudioHandler overrides ─────────────────────────────────────────
  @override
  Future<void> play() {
    _pausedByInterruption = false;
    return _player.play();
  }

  @override
  Future<void> pause() {
    // A deliberate pause (lock screen, in-app, etc.) always wins — clear the
    // flag so a subsequent interruption-end event can't resume playback
    // behind the user's back.
    _pausedByInterruption = false;
    return _player.pause();
  }

  @override
  Future<void> skipToNext() => onSkipToNext?.call() ?? Future.value();

  @override
  Future<void> skipToPrevious() => onSkipToPrevious?.call() ?? Future.value();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  // ── Map just_audio state to audio_service PlaybackState ───────────────
  PlaybackState _stateFromEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }
}
