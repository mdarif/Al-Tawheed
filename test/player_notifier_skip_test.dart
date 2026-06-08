import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/audio/playback_source.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Covers the 2026-06-08 regression: lock-screen / notification "Next" and
// "Previous" controls landed in TawheedAudioHandler.skipToNext/Previous,
// which BaseAudioHandler implements as no-ops, so the taps did nothing.
// The fix wires those overrides to PlayerNotifier.playNext/playPrevious via
// onSkipToNext/onSkipToPrevious callback hooks (see audio_handler_test.dart
// for the handler-side half of the contract).
//
// `loadAndPlay` only reaches the real `just_audio` player on the "online or
// downloaded" path — the offline-and-not-downloaded path returns early with
// `_current`/`_queue` already updated and `playbackSource = blocked`. That
// early-return path is what these tests exercise: it lets us drive the real
// queue-navigation logic end-to-end (through the actual BaseAudioHandler
// entry points a lock-screen tap uses) without a platform-backed player.

Lecture _lec(String id, {String chapterId = 'ch-01'}) => Lecture(
      id: id,
      number: 1,
      chapterId: chapterId,
      title: {'en': 'Lecture $id'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Lecture> queue;
  late TawheedAudioHandler handler;
  late PlayerNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();

    queue = [_lec('a'), _lec('b'), _lec('c')];
    handler = TawheedAudioHandler();
    notifier = PlayerNotifier(
      handler,
      ProgressProvider(),
      DownloadsProvider(),
      ConnectivityProvider.testOffline(),
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('constructor wiring', () {
    test('wires handler skip hooks to playNext/playPrevious', () {
      expect(handler.onSkipToNext, equals(notifier.playNext));
      expect(handler.onSkipToPrevious, equals(notifier.playPrevious));
    });
  });

  group('lock-screen "Previous" (handler.skipToPrevious)', () {
    test('moves to the previous track in the queue', () async {
      await notifier.loadAndPlay(queue[1], queue);
      expect(notifier.current?.id, 'b');

      await handler.skipToPrevious();

      expect(notifier.current?.id, 'a');
      expect(notifier.playbackSource, PlaybackSource.blocked);
    });

    test('is a no-op at the start of the queue', () async {
      await notifier.loadAndPlay(queue[0], queue);
      expect(notifier.current?.id, 'a');

      await handler.skipToPrevious();

      expect(notifier.current?.id, 'a');
    });
  });

  group('lock-screen "Next" (handler.skipToNext)', () {
    test('blocks and reports the pending lecture when offline and undownloaded',
        () async {
      await notifier.loadAndPlay(queue[0], queue);
      expect(notifier.current?.id, 'a');

      await handler.skipToNext();

      // Offline + next not downloaded → queue does not advance; instead the
      // "not available offline" prompt state is surfaced for the UI to show.
      expect(notifier.current?.id, 'a');
      expect(notifier.pendingNextBlocked, isTrue);
      expect(notifier.pendingNextBlockedLecture?.id, 'b');
    });

    test('is a no-op at the end of the queue', () async {
      await notifier.loadAndPlay(queue[2], queue);
      expect(notifier.current?.id, 'c');

      await handler.skipToNext();

      expect(notifier.current?.id, 'c');
      expect(notifier.pendingNextBlocked, isFalse);
    });
  });

  test('repeated lock-screen taps walk the queue back and forth', () async {
    await notifier.loadAndPlay(queue[1], queue);
    expect(notifier.current?.id, 'b');

    await handler.skipToPrevious();
    expect(notifier.current?.id, 'a');

    // 'a' -> 'b' is downloaded-state-free (offline, undownloaded) so it
    // blocks rather than advancing — confirms skipToNext routes through the
    // same offline guard as the in-app control, not a bypass.
    await handler.skipToNext();
    expect(notifier.current?.id, 'a');
    expect(notifier.pendingNextBlocked, isTrue);
  });
}
