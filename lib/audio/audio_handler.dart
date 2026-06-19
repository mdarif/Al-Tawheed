import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:myapp/models/catalog.dart';

class TawheedAudioHandler extends BaseAudioHandler with SeekHandler {
  // just_audio's own `handleInterruptions` can race with a user-initiated
  // pause: if a focus interruption "begin" event lands while we're playing,
  // it pauses internally and arms its `_playInterrupted` flag, then an
  // "end" event auto-resumes — even if the user paused in between. We
  // disable it and track interruption-vs-user pauses ourselves so a manual
  // pause (e.g. from the lock screen) always wins and is never overridden.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
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
    _player.playbackEventStream
        .map(_stateFromEvent)
        .listen(playbackState.add, onError: playbackState.addError);
  }

  AudioPlayer get player => _player;

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
  Future<void> loadLecture(
    Lecture lecture, {
    Duration startFrom = Duration.zero,
    String? localFilePath,
    String artist = 'Sharah Kitab al-Tawheed',
    String? displayTitle,
  }) async {
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
