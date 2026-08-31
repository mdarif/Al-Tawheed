import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/models/catalog.dart';

// Lock-screen / notification media controls reach the handler through
// BaseAudioHandler.skipToNext/skipToPrevious. BaseAudioHandler's default
// implementations are no-ops, so TawheedAudioHandler must forward those
// calls to the onSkipToNext/onSkipToPrevious hooks that PlayerNotifier
// wires up post-construction — otherwise the taps silently do nothing,
// which was the regression reported on 2026-06-08 ("lock screen next/prev
// button aren't doing anything").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('is the production implementation of the notifier audio seam', () {
    final handler = TawheedAudioHandler();

    expect(handler, isA<AudioPlayback>());
  });

  group('skipToNext', () {
    test('invokes onSkipToNext when set', () async {
      final handler = TawheedAudioHandler();
      var calls = 0;
      handler.onSkipToNext = () async => calls++;

      await handler.skipToNext();

      expect(calls, 1);
    });

    test('completes without throwing when unset', () async {
      final handler = TawheedAudioHandler();

      await expectLater(handler.skipToNext(), completes);
    });
  });

  group('skipToPrevious', () {
    test('invokes onSkipToPrevious when set', () async {
      final handler = TawheedAudioHandler();
      var calls = 0;
      handler.onSkipToPrevious = () async => calls++;

      await handler.skipToPrevious();

      expect(calls, 1);
    });

    test('completes without throwing when unset', () async {
      final handler = TawheedAudioHandler();

      await expectLater(handler.skipToPrevious(), completes);
    });
  });

  test('skipToNext and skipToPrevious hooks fire independently', () async {
    final handler = TawheedAudioHandler();
    var nextCalls = 0;
    var previousCalls = 0;
    handler.onSkipToNext = () async => nextCalls++;
    handler.onSkipToPrevious = () async => previousCalls++;

    await handler.skipToNext();
    expect(nextCalls, 1);
    expect(previousCalls, 0);

    await handler.skipToPrevious();
    expect(nextCalls, 1);
    expect(previousCalls, 1);
  });

  test('overlapping production loads preserve each engine callback provenance',
      () async {
    final initial = _FakeAudioEngine();
    final old = _FakeAudioEngine(pendingSource: Completer<void>());
    final current = _FakeAudioEngine();
    final engines = [initial, old, current];
    var nextEngine = 0;
    final handler = TawheedAudioHandler(
      engineFactory: () => engines[nextEngine++],
      configureAudioSession: false,
    );
    final durations = <AudioPlaybackEvent<Duration?>>[];
    final processing = <AudioPlaybackEvent<ProcessingState>>[];
    final errors = <AudioPlaybackEvent<Object>>[];
    final rawErrors = <Object>[];
    final subscriptions = [
      handler.durationEvents.listen(durations.add),
      handler.processingEvents.listen(processing.add),
      handler.errorEvents.listen(errors.add),
      handler.rawPlaybackState.listen(
        (_) {},
        onError: (Object error, StackTrace _) => rawErrors.add(error),
      ),
    ];

    final oldLoad = handler.loadLecture(_lecture('a'), sessionId: 41);
    final currentLoad = handler.loadLecture(_lecture('b'), sessionId: 42);
    await currentLoad;

    // These callbacks are emitted by the retired A engine, after B is live.
    // No manual session tag is available to the fake engine: the production
    // handler's listener closure is what must associate them with A.
    old.emitDuration(const Duration(seconds: 111));
    old.emitProcessing(ProcessingState.completed);
    old.emitPlaybackError(StateError('A failed after B started'));
    await Future<void>.delayed(Duration.zero);

    expect(durations.single.sessionId, 41);
    expect(processing.single.sessionId, 41);
    expect(errors.single.sessionId, 41);
    // Stale backend errors are observable as typed, source-labelled events,
    // but never forwarded into the active audio_service state stream as B.
    expect(rawErrors, isEmpty);

    old.completeSourceLoad();
    await oldLoad;
    expect(old.playCalls, 0);
    expect(current.playCalls, 1);

    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  });
}

Lecture _lecture(String id) => Lecture(
      id: id,
      number: 1,
      chapterId: 'chapter',
      title: {'en': 'Lecture $id'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1,
    );

/// A backend engine that deliberately keeps its streams open after dispose.
/// This models a native callback already queued when an overlapping load
/// retires the engine; [TawheedAudioHandler] must retain its original source
/// provenance without any test-supplied session identifier.
class _FakeAudioEngine implements AudioEngine {
  _FakeAudioEngine({this.pendingSource});

  final Completer<void>? pendingSource;
  final _events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _durations = StreamController<Duration?>.broadcast(sync: true);
  final _processing = StreamController<ProcessingState>.broadcast(sync: true);
  bool _playing = false;
  ProcessingState _processingState = ProcessingState.ready;
  Duration _position = Duration.zero;
  final Duration _bufferedPosition = Duration.zero;
  double _speed = 1;
  double _volume = 1;
  int playCalls = 0;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _events.stream;
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<Duration?> get durationStream => _durations.stream;
  @override
  Stream<ProcessingState> get processingStateStream => _processing.stream;
  @override
  bool get playing => _playing;
  @override
  ProcessingState get processingState => _processingState;
  @override
  Duration get position => _position;
  @override
  Duration get bufferedPosition => _bufferedPosition;
  @override
  double get speed => _speed;
  @override
  double get volume => _volume;

  @override
  Future<void> setAudioSource(
    AudioSource source, {
    Duration? initialPosition,
  }) =>
      pendingSource?.future ?? Future.value();

  @override
  Future<void> play() async {
    _playing = true;
    playCalls++;
  }

  @override
  Future<void> pause() async => _playing = false;
  @override
  Future<void> seek(Duration position) async => _position = position;
  @override
  Future<void> setSpeed(double speed) async => _speed = speed;
  @override
  Future<void> setVolume(double volume) async => _volume = volume;
  @override
  Future<void> stop() async => _playing = false;
  @override
  Future<void> dispose() async {}

  void emitDuration(Duration duration) => _durations.add(duration);
  void emitProcessing(ProcessingState state) {
    _processingState = state;
    _processing.add(state);
  }

  void emitPlaybackError(Object error) => _events.addError(error);
  void completeSourceLoad() => pendingSource!.complete();
}
