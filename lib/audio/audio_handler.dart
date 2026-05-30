import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:myapp/models/catalog.dart';

class TawheedAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  TawheedAudioHandler() {
    _init();
    // Pipe just_audio playback events into audio_service's playbackState stream
    _player.playbackEventStream.map(_stateFromEvent).pipe(playbackState);
  }

  AudioPlayer get player => _player;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  /// Load and immediately begin playing a lecture.
  Future<void> loadLecture(Lecture lecture) async {
    mediaItem.add(MediaItem(
      id: lecture.audioUrl,
      title: lecture.title,
      artist: 'Shaikh Abdullah Nasir Rahmani',
      duration: Duration(seconds: lecture.durationSeconds),
    ));
    await _player.setUrl(lecture.audioUrl);
    await play();
  }

  // ── BaseAudioHandler overrides ─────────────────────────────────────────
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

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
