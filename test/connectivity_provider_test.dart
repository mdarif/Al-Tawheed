import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/connectivity_provider.dart';

// ConnectivityProvider drives the app's offline-first guarantees — every
// "are we online / on wifi / on mobile data" decision flows through it. The
// real constructor talks to platform connectivity channels, so these tests
// exercise the @visibleForTesting factories instead: they're the seam the
// rest of the test suite (e.g. player_notifier_skip_test.dart) already
// depends on to simulate connectivity states, so it's worth confirming they
// actually produce the states their names promise.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('testOnline', () {
    test('reports online over wifi', () {
      final provider = ConnectivityProvider.testOnline();
      addTearDown(provider.dispose);

      expect(provider.isOnline, isTrue);
      expect(provider.isOffline, isFalse);
      expect(provider.isWifi, isTrue);
      expect(provider.isMobile, isFalse);
    });
  });

  group('testOffline', () {
    test('reports offline with no active connection', () {
      final provider = ConnectivityProvider.testOffline();
      addTearDown(provider.dispose);

      expect(provider.isOnline, isFalse);
      expect(provider.isOffline, isTrue);
      expect(provider.isWifi, isFalse);
      expect(provider.isMobile, isFalse);
    });
  });

  group('testOnlineMobile', () {
    test('reports online over mobile data, not wifi', () {
      final provider = ConnectivityProvider.testOnlineMobile();
      addTearDown(provider.dispose);

      expect(provider.isOnline, isTrue);
      expect(provider.isOffline, isFalse);
      expect(provider.isWifi, isFalse);
      expect(provider.isMobile, isTrue);
    });
  });

  test('dispose can be called without having started listening', () {
    final provider = ConnectivityProvider.testOnline();

    expect(provider.dispose, returnsNormally);
  });
}
