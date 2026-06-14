import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ConnectivityProvider drives the app's offline-first guarantees — every
// "are we online / on wifi / on mobile data" decision flows through it. The
// real constructor talks to platform connectivity channels, so the first
// group of tests below exercises the @visibleForTesting factories: they're
// the seam the rest of the test suite (e.g. player_notifier_skip_test.dart)
// already depends on to simulate connectivity states, so it's worth
// confirming they actually produce the states their names promise.
//
// The second group drives the *real* constructor against a fake
// ConnectivityPlatform, to cover the wifi-to-mobile handoff / app-resume
// re-sync fix in connectivity_provider.dart.

/// Fake platform implementation that lets tests control both
/// [checkConnectivity]'s return value and emit [onConnectivityChanged]
/// stream events on demand.
class _FakeConnectivityPlatform extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  _FakeConnectivityPlatform(this.checkResult);

  List<ConnectivityResult> checkResult;
  int checkConnectivityCallCount = 0;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkConnectivityCallCount++;
    return checkResult;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void emit(List<ConnectivityResult> results) => _controller.add(results);

  void close() => _controller.close();
}

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

  // ── Real constructor against a fake ConnectivityPlatform ────────────────

  group('ConnectivityProvider() — initial state', () {
    testWidgets('reflects an initial online-over-mobile platform result',
        (tester) async {
      final fake = _FakeConnectivityPlatform([ConnectivityResult.mobile]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final provider = ConnectivityProvider();
      addTearDown(provider.dispose);
      await tester.pump();

      expect(provider.isOnline, isTrue);
      expect(provider.isMobile, isTrue);
      expect(provider.isWifi, isFalse);
    });

    testWidgets('reflects an initial offline (none) platform result',
        (tester) async {
      final fake = _FakeConnectivityPlatform([ConnectivityResult.none]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final provider = ConnectivityProvider();
      addTearDown(provider.dispose);
      await tester.pump();

      expect(provider.isOnline, isFalse);
      expect(provider.isOffline, isTrue);
    });
  });

  group('ConnectivityProvider() — wifi-to-mobile handoff', () {
    testWidgets(
        're-queries checkConnectivity after the debounce instead of '
        'trusting a stale "none" from onConnectivityChanged',
        (tester) async {
      final fake = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final provider = ConnectivityProvider();
      addTearDown(provider.dispose);
      await tester.pump();
      expect(provider.isOnline, isTrue);
      expect(provider.isWifi, isTrue);

      // The wifi "lost" callback delivers a transient `none`, but by the
      // time we re-check, the OS has already settled on mobile data.
      fake.checkResult = [ConnectivityResult.mobile];
      fake.emit([ConnectivityResult.none]);

      await tester.pump(const Duration(milliseconds: 600));

      expect(provider.isOnline, isTrue);
      expect(provider.isMobile, isTrue);
      expect(provider.isWifi, isFalse);
    });

    testWidgets('rapid connectivity-changed events are debounced to one refresh',
        (tester) async {
      final fake = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final provider = ConnectivityProvider();
      addTearDown(provider.dispose);
      await tester.pump();
      final callsAfterInit = fake.checkConnectivityCallCount;

      fake.checkResult = [ConnectivityResult.mobile];
      fake.emit([ConnectivityResult.none]);
      await tester.pump(const Duration(milliseconds: 100));
      fake.emit([ConnectivityResult.mobile]);
      await tester.pump(const Duration(milliseconds: 100));
      fake.emit([ConnectivityResult.wifi]);

      await tester.pump(const Duration(milliseconds: 600));

      expect(fake.checkConnectivityCallCount, callsAfterInit + 1);
    });
  });

  group('ConnectivityProvider() — app resume', () {
    testWidgets('didChangeAppLifecycleState(resumed) re-syncs connectivity',
        (tester) async {
      final fake = _FakeConnectivityPlatform([ConnectivityResult.none]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final provider = ConnectivityProvider();
      addTearDown(provider.dispose);
      await tester.pump();
      expect(provider.isOffline, isTrue);

      // User returns home to wifi, but no stream event arrives (e.g. it was
      // delivered while the app was suspended in the background).
      fake.checkResult = [ConnectivityResult.wifi];
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await tester.pump(const Duration(milliseconds: 600));

      expect(provider.isOnline, isTrue);
      expect(provider.isWifi, isTrue);
    });

    testWidgets('does not notify listeners when a refresh finds no change',
        (tester) async {
      final fake = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final provider = ConnectivityProvider();
      addTearDown(provider.dispose);
      await tester.pump();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 600));

      expect(notifyCount, 0);
      expect(provider.isOnline, isTrue);
      expect(provider.isWifi, isTrue);
    });
  });

  group('ConnectivityProvider() — dispose', () {
    testWidgets('cancels a pending debounced refresh without error',
        (tester) async {
      final fake = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      ConnectivityPlatform.instance = fake;
      addTearDown(fake.close);

      final provider = ConnectivityProvider();
      await tester.pump();

      // Schedule a debounced refresh, then dispose before it fires.
      fake.checkResult = [ConnectivityResult.none];
      fake.emit([ConnectivityResult.none]);
      provider.dispose();

      // Would throw "used after being disposed" if the pending Timer still
      // called notifyListeners() after dispose.
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
