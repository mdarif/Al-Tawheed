import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/audio/playback_source.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_audio_playback.dart';

Lecture _lecture(String id, {int duration = 600}) => Lecture(
      id: id,
      number: int.parse(id),
      chapterId: 'chapter-1',
      title: {'en': 'Lecture $id'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: duration,
      fileSizeBytes: 100,
    );

final _queue = [_lecture('1'), _lecture('2'), _lecture('3')];

Catalog _catalog(List<Lecture> lectures) => Catalog(
      version: 1,
      book: const Book(
        id: 'book',
        title: {'en': 'Book'},
        speaker: {'en': 'Speaker'},
        totalDurationSeconds: 1800,
        lectureCount: 3,
        coverImageUrl: '',
        language: 'ur',
      ),
      chapters: const [],
      lectures: lectures,
      dailyBenefits: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioPlayback audio;
  late ProgressProvider progress;
  late DownloadsProvider downloads;
  late ConnectivityProvider connectivity;
  late PlayerNotifier player;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    audio = FakeAudioPlayback();
    progress = ProgressProvider()..load();
    downloads = DownloadsProvider();
    connectivity = ConnectivityProvider.testOnline();
    player = PlayerNotifier.forTesting(
      audio,
      progress,
      downloads,
      connectivity,
      stuckBufferingDelay: const Duration(milliseconds: 1),
      saveInterval: const Duration(milliseconds: 1),
    );
  });

  tearDown(() async {
    player.dispose();
    await audio.dispose();
  });

  group('load and source policy', () {
    test('resumes only positions safely inside the lecture boundaries',
        () async {
      await progress.saveProgress('1', 30);
      await player.loadAndPlay(_queue[0], _queue);
      expect(audio.loads.single.startFrom, Duration.zero);

      await progress.saveProgress('1', 31);
      await player.loadAndPlay(_queue[0], _queue);
      expect(audio.loads.last.startFrom, const Duration(seconds: 31));

      await progress.saveProgress('1', 570);
      await player.loadAndPlay(_queue[0], _queue);
      expect(audio.loads.last.startFrom, Duration.zero);
    });

    test('chooses stream, local file, or blocked source through one load path',
        () async {
      await player.loadAndPlay(_queue[0], _queue);
      expect(player.playbackSource, PlaybackSource.stream);
      expect(audio.loads.single.localFilePath, isNull);

      final directory = await Directory.systemTemp.createTemp('tawheed-player');
      addTearDown(() => directory.delete(recursive: true));
      DownloadService.resetForTest(directory.path);
      downloads.seedDownloadedForTest('2');
      final local = DownloadService.localPath('2');
      await File(local).create(recursive: true);
      await player.loadAndPlay(_queue[1], _queue);
      expect(player.playbackSource, PlaybackSource.local);
      expect(audio.loads.last.localFilePath, local);

      connectivity.setOnlineForTest(false);
      await player.loadAndPlay(_queue[2], _queue);
      expect(player.playbackSource, PlaybackSource.blocked);
      expect(audio.loads, hasLength(2));
    });
  });

  test('buffering becomes stuck on injected timing and clears when ready',
      () async {
    await player.loadAndPlay(_queue[0], _queue);
    audio.emitPlaybackState(
      processingState: AudioProcessingState.buffering,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(player.isLoading, isTrue);
    expect(player.isStuckBuffering, isTrue);

    audio.emitPlaybackState(
      playing: true,
      processingState: AudioProcessingState.ready,
    );
    expect(player.isLoading, isFalse);
    expect(player.isStuckBuffering, isFalse);
  });

  test('backend errors surface retry and retry uses the production load path',
      () async {
    await player.loadAndPlay(_queue[0], _queue);
    audio.emitPosition(const Duration(seconds: 42));
    audio.emitError(StateError('stream disconnected'));

    expect(player.hasPlaybackError, isTrue);
    expect(progress.getPositionSeconds('1'), 42);

    await player.retryPlayback();
    expect(player.hasPlaybackError, isFalse);
    expect(audio.loads, hasLength(2));
    expect(audio.loads.last.startFrom, const Duration(seconds: 42));
  });

  test('a failed load can be retried without exposing an async exception',
      () async {
    audio.failNextLoad = StateError('bad source');
    await player.loadAndPlay(_queue[0], _queue);
    expect(player.hasPlaybackError, isTrue);
    expect(audio.loads, hasLength(1));

    await player.retryPlayback();
    expect(player.hasPlaybackError, isFalse);
    expect(audio.loads, hasLength(2));
  });

  test('reconnect reloads a stuck stream but only unlocks a blocked request',
      () async {
    await player.loadAndPlay(_queue[0], _queue);
    audio.emitPlaybackState(processingState: AudioProcessingState.buffering);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    connectivity.setOnlineForTest(false);
    connectivity.setOnlineForTest(true);
    expect(audio.loads, hasLength(2));

    connectivity.setOnlineForTest(false);
    await player.loadAndPlay(_queue[2], _queue);
    expect(player.playbackSource, PlaybackSource.blocked);
    connectivity.setOnlineForTest(true);
    expect(player.playbackSource, PlaybackSource.stream);
    expect(
      audio.loads,
      hasLength(2),
      reason: 'blocked playback does not autoplay',
    );
  });

  test('deleting the active local file pauses and falls back to streaming',
      () async {
    final directory = await Directory.systemTemp.createTemp('tawheed-player');
    addTearDown(() => directory.delete(recursive: true));
    DownloadService.resetForTest(directory.path);
    downloads.seedDownloadedForTest('1');
    await File(DownloadService.localPath('1')).create(recursive: true);
    await player.loadAndPlay(_queue[0], _queue);
    expect(player.playbackSource, PlaybackSource.local);

    await downloads.delete('1');
    expect(player.playbackSource, PlaybackSource.stream);
    expect(audio.pauseCalls, 1);

    connectivity.setOnlineForTest(false);
    downloads.seedDownloadedForTest('1');
    await File(DownloadService.localPath('1')).create(recursive: true);
    await player.loadAndPlay(_queue[0], _queue);
    await downloads.delete('1');
    expect(player.playbackSource, PlaybackSource.blocked);
  });

  test('in-app and lock-screen queue controls share boundaries and guards',
      () async {
    await player.loadAndPlay(_queue[0], _queue);
    await player.playNext();
    expect(player.current?.id, '2');

    await audio.triggerPrevious();
    expect(player.current?.id, '1');

    connectivity.setOnlineForTest(false);
    await audio.triggerNext();
    expect(player.current?.id, '1');
    expect(player.pendingNextBlockedLecture?.id, '2');

    await player.loadAndPlay(_queue.last, _queue);
    await audio.triggerNext();
    expect(player.current?.id, '3');
  });

  test('completion persists, auto-advances, and ends a study chapter',
      () async {
    await player.loadAndPlay(_queue[0], _queue);
    audio.emitCompleted();
    expect(progress.getPositionSeconds('1'), 600);
    expect(player.current?.id, '2');

    const chapter = Chapter(
      id: 'chapter-1',
      number: 1,
      title: {'en': 'Chapter'},
      lectureCount: 1,
    );
    await player.startStudySession(
      lecture: _queue.last,
      queue: [_queue.last],
      chapter: chapter,
    );
    audio.emitCompleted();
    expect(player.pendingStudyChapterCompleteId, 'chapter-1');
  });

  test('last completion notifies when the whole catalog is complete', () async {
    final catalog = CatalogProvider()..setCatalogForTest(_catalog(_queue));
    final completePlayer = PlayerNotifier.forTesting(
      audio,
      progress,
      downloads,
      connectivity,
      catalog: catalog,
    );
    addTearDown(completePlayer.dispose);
    await progress.saveProgress('1', 600);
    await progress.saveProgress('2', 600);
    await completePlayer.loadAndPlay(_queue.last, _queue);
    audio.emitCompleted();
    expect(completePlayer.pendingAllLecturesComplete, isTrue);
  });

  test('speed and position persist through the backend command path', () async {
    await player.loadAndPlay(_queue[0], _queue);
    await player.setSpeed(1.5);
    expect(audio.speeds, contains(1.5));
    expect(PreferencesService.instance.playbackSpeed, 1.5);

    audio.emitPlaybackState(playing: true);
    audio.emitPosition(const Duration(seconds: 17));
    await player.playPause();
    expect(progress.getPositionSeconds('1'), 17);
    expect(audio.pauseCalls, 1);
  });

  test('dispose ignores pending loads and backend events', () async {
    final pending = Completer<void>();
    audio.pendingLoad = pending;
    final load = player.loadAndPlay(_queue[0], _queue);
    player.dispose();
    pending.complete();
    await load;
    audio.emitPlaybackState(
      playing: true,
      processingState: AudioProcessingState.buffering,
    );
    audio.emitCompleted();
    expect(audio.loads, hasLength(1));
    expect(progress.getPositionSeconds('1'), 0);
  });
}
