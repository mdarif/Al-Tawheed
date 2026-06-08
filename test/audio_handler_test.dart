import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/audio/audio_handler.dart';

// Lock-screen / notification media controls reach the handler through
// BaseAudioHandler.skipToNext/skipToPrevious. BaseAudioHandler's default
// implementations are no-ops, so TawheedAudioHandler must forward those
// calls to the onSkipToNext/onSkipToPrevious hooks that PlayerNotifier
// wires up post-construction — otherwise the taps silently do nothing,
// which was the regression reported on 2026-06-08 ("lock screen next/prev
// button aren't doing anything").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
