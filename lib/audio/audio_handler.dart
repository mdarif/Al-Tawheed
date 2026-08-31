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

/// One concrete audio backend. A new instance is created for each load so its
/// callbacks have an immutable source-session provenance.
abstract interface class AudioEngine {
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<ProcessingState> get processingStateStream;
  bool get playing;
  ProcessingState get processingState;
  Duration get position;
  Duration get bufferedPosition;
  double get speed;
  double get volume;
  Future<void> setAudioSource(AudioSource source, {Duration? initialPosition});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine() : _player = AudioPlayer(handleInterruptions: false);

  final AudioPlayer _player;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  @override
  bool get playing => _player.playing;
  @override
  ProcessingState get processingState => _player.processingState;
  @override
  Duration get position => _player.position;
  @override
  Duration get bufferedPosition => _player.bufferedPosition;
  @override
  double get speed => _player.speed;
  @override
  double get volume => _player.volume;
  @override
  Future<void> setAudioSource(
    AudioSource source, {
    Duration? initialPosition,
  }) async {
    await _player.setAudioSource(source, initialPosition: initialPosition);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

/// The audio-session events the handler needs to apply its playback policy.
/// Keeping this narrow makes focus/noisy transitions deterministic to test.
abstract interface class PlaybackAudioSession {
  Future<void> configureMusic();
  Stream<void> get becomingNoisyEvents;
  Stream<AudioInterruptionEvent> get interruptionEvents;
}

class SystemPlaybackAudioSession implements PlaybackAudioSession {
  SystemPlaybackAudioSession(this._session);

  final AudioSession _session;

  static Future<PlaybackAudioSession> create() async =>
      SystemPlaybackAudioSession(await AudioSession.instance);

  @override
  Future<void> configureMusic() =>
      _session.configure(const AudioSessionConfiguration.music());

  @override
  Stream<void> get becomingNoisyEvents => _session.becomingNoisyEventStream;

  @override
  Stream<AudioInterruptionEvent> get interruptionEvents =>
      _session.interruptionEventStream;
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
  final AudioEngine Function() _engineFactory;
  final Future<PlaybackAudioSession> Function() _sessionFactory;
  late AudioEngine _player;
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
  int _loadGeneration = 0;
  bool _sourceReady = false;
  bool _wantsToPlay = false;
  bool _interruptionActive = false;
  bool _resumeAfterInterruption = false;
  double _speed = 1.0;

  // The handler is just a thin just_audio wrapper — it doesn't know about the
  // playback queue (that lives in PlayerNotifier). Lock-screen / notification
  // skip-to-next/previous taps land here via BaseAudioHandler, so PlayerNotifier
  // wires these to its own playNext/playPrevious after construction.
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  TawheedAudioHandler({
    AudioEngine Function()? engineFactory,
    Future<PlaybackAudioSession> Function()? sessionFactory,
    bool configureAudioSession = true,
  })  : _engineFactory = engineFactory ?? JustAudioEngine.new,
        _sessionFactory = sessionFactory ?? SystemPlaybackAudioSession.create {
    _player = _newEngine(0);
    if (configureAudioSession) _init();
  }

  AudioEngine _newEngine(int sessionId) {
    final engine = _engineFactory();
    // Forward just_audio playback events into audio_service's playbackState
    // stream. `.listen()` rather than `.pipe()` — `pipe()`/`addStream()`
    // would permanently lock `playbackState` against direct `.add()` calls
    // (e.g. from `super.stop()`) for as long as the player's event stream
    // stays open, which is its entire lifetime.
    engine.playbackEventStream
        .map((event) => _stateFromEvent(engine, event))
        .listen(
      (state) {
        _playbackEvents.add(AudioPlaybackEvent(sessionId, state));
        if (sessionId != _activeSessionId) return;
        playbackState.add(state);
        _rawPlaybackStates.add(state);
      },
      onError: (Object error, StackTrace stackTrace) {
        _errorEvents.add(AudioPlaybackEvent(sessionId, error));
        if (sessionId != _activeSessionId) return;
        playbackState.addError(error, stackTrace);
        _rawPlaybackStates.addError(
          AudioPlaybackFailure(sessionId, error),
          stackTrace,
        );
      },
    );
    engine.positionStream.listen(
      (position) =>
          _positionEvents.add(AudioPlaybackEvent(sessionId, position)),
    );
    engine.durationStream.listen(
      (duration) =>
          _durationEvents.add(AudioPlaybackEvent(sessionId, duration)),
    );
    engine.processingStateStream.listen(
      (state) => _processingEvents.add(AudioPlaybackEvent(sessionId, state)),
    );
    return engine;
  }

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
    final session = await _sessionFactory();
    await session.configureMusic();

    session.becomingNoisyEvents.listen((_) => unawaited(pause()));

    session.interruptionEvents.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            unawaited(_player.setVolume(_player.volume / 2));
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _interruptionActive = true;
            _resumeAfterInterruption = _wantsToPlay;
            unawaited(_player.pause());
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            unawaited(_player.setVolume(min(1.0, _player.volume * 2)));
            break;
          case AudioInterruptionType.pause:
            _interruptionActive = false;
            final resume = _resumeAfterInterruption && _wantsToPlay;
            _resumeAfterInterruption = false;
            if (resume) {
              unawaited(_playIfStillDesired(_player, _loadGeneration));
            }
            break;
          case AudioInterruptionType.unknown:
            _interruptionActive = false;
            _resumeAfterInterruption = false;
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
    final previous = _player;
    final loadGeneration = ++_loadGeneration;
    _activeSessionId = sessionId;
    _sourceReady = false;
    _wantsToPlay = true;
    if (_interruptionActive) _resumeAfterInterruption = true;
    final player = _newEngine(sessionId);
    _player = player;
    // Retiring an engine is deliberately asynchronous: just_audio may still
    // finish a native callback after stop. Its listener closes over the old
    // [sessionId], so that callback cannot be mistaken for this new load.
    unawaited(_retireEngine(previous));
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

    await player.setSpeed(_speed);
    await player.setAudioSource(source, initialPosition: startFrom);
    // A slower old source load or a stop must never resume over the latest
    // command. Pause/focus intent is checked separately by _playIfStillDesired.
    if (!_isCurrentLoad(player, loadGeneration, sessionId)) return;
    _sourceReady = true;
    await _playIfStillDesired(player, loadGeneration);
  }

  // ── BaseAudioHandler overrides ─────────────────────────────────────────
  @override
  Future<void> play() {
    _wantsToPlay = true;
    if (_interruptionActive) _resumeAfterInterruption = true;
    return _playIfStillDesired(_player, _loadGeneration);
  }

  @override
  Future<void> pause() {
    // A deliberate pause (lock screen, in-app, etc.) always wins — clear the
    // flag so a subsequent interruption-end event can't resume playback
    // behind the user's back.
    _wantsToPlay = false;
    _resumeAfterInterruption = false;
    return _player.pause();
  }

  @override
  Future<void> skipToNext() => onSkipToNext?.call() ?? Future.value();

  @override
  Future<void> skipToPrevious() => onSkipToPrevious?.call() ?? Future.value();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) {
    _speed = speed;
    return _player.setSpeed(speed);
  }

  @override
  Future<void> stop() async {
    // Invalidate an in-flight setAudioSource before stopping. Otherwise it can
    // complete after this await and resurrect playback on the retired engine.
    _loadGeneration++;
    _sourceReady = false;
    _wantsToPlay = false;
    _resumeAfterInterruption = false;
    await _player.stop();
    return super.stop();
  }

  bool _isCurrentLoad(AudioEngine player, int generation, int sessionId) =>
      identical(player, _player) &&
      generation == _loadGeneration &&
      sessionId == _activeSessionId;

  Future<void> _playIfStillDesired(
    AudioEngine player,
    int generation,
  ) async {
    if (!identical(player, _player) ||
        generation != _loadGeneration ||
        !_sourceReady ||
        !_wantsToPlay ||
        _interruptionActive) {
      return;
    }
    await player.play();
    // A pause/stop can arrive while a platform play call is outstanding.
    if (!identical(player, _player) ||
        generation != _loadGeneration ||
        !_wantsToPlay ||
        _interruptionActive) {
      await player.pause();
    }
  }

  Future<void> _retireEngine(AudioEngine engine) async {
    try {
      await engine.stop();
    } catch (_) {
      // A source that is already being disposed can reject stop. It is no
      // longer active and its callbacks remain tagged with its old session.
    }
    try {
      await engine.dispose();
    } catch (_) {
      // The replacement engine is already active; disposal failure must not
      // turn into an unhandled background error.
    }
  }

  // ── Map just_audio state to audio_service PlaybackState ───────────────
  PlaybackState _stateFromEvent(AudioEngine player, PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
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
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    );
  }
}
