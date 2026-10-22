import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/black_hole_http.dart';

// A fresh install has no cached feature flags and no cached series manifest,
// so the Welcome screen waits on the network before it will show anything
// (SeriesProvider.isSeriesReady). Offline that is instant — the fetch fails
// fast. The hang is the other kind of bad network: connections that never
// complete (captive portal, dead uplink, DNS that never answers). Each fetch
// then burns 3 attempts x 10 s = 30 s before it gives up, and the user stares
// at a blank dark Welcome screen. The harness saw exactly that as
// "Timed out after 30s waiting for welcome screen" on a cold emulator.
//
// Startup must give up on the network in bounded time instead. These tests run
// the real providers against connections that never answer and assert the
// user-visible outcome, with no knowledge of how the bound is implemented.

/// One startup-gating fetch (flags, or the manifest) may take at most this
/// long before the app proceeds with its bundled defaults. It is well below the
/// 30 s a stalled fetch takes today, and two of them in sequence (flags, then
/// the manifest) still fit inside the 30 s the harness allows a cold start.
const _perFetchBudget = Duration(seconds: 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpOverrides? previousOverrides;

  setUp(() async {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = BlackHoleHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  tearDown(() {
    HttpOverrides.global = previousOverrides;
  });

  testWidgets(
    'feature flags settle (defaults) within the startup budget when the CDN '
    'never answers',
    (tester) async {
      final flags = FeatureFlagsProvider();
      unawaited(flags.load());

      await tester.pump(_perFetchBudget);

      expect(flags.hasLoaded, isTrue);
      expect(flags.multiSeriesEnabled, isFalse);

      // Drain whatever the abandoned fetch still has pending so the test
      // framework's pending-timer check sees a quiet clock.
      await tester.pump(const Duration(minutes: 2));
    },
  );

  testWidgets(
    'a fresh multi-series install is ready (bundled Urdu) within the startup '
    'budget when the manifest fetch never answers',
    (tester) async {
      // Flags are cached and say multiSeries is on; only series.json hangs.
      await PreferencesService.instance.saveRemoteJson(
        'feature_flags',
        jsonEncode({
          'version': 1,
          'experimental': {'multiSeries': true},
        }),
      );
      final series = SeriesProvider()..load(true, definitive: true);
      expect(
        series.isSeriesReady,
        isFalse,
        reason: 'fresh install: waiting on the manifest',
      );

      unawaited(series.loadManifest());
      await tester.pump(_perFetchBudget);

      expect(series.isSeriesReady, isTrue);

      await tester.pump(const Duration(minutes: 2));
    },
  );

  testWidgets(
    'Welcome shows START LISTENING within the startup budget when the CDN '
    'never answers (app.dart wiring)',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => FeatureFlagsProvider()..load(),
              lazy: false,
            ),
            // Mirrors the SeriesProvider ProxyProvider in lib/app.dart. If
            // that wiring changes, change this with it.
            ChangeNotifierProxyProvider<FeatureFlagsProvider, SeriesProvider>(
              create: (_) => SeriesProvider()..load(false),
              update: (_, flags, series) {
                series ??= SeriesProvider();
                series.load(
                  flags.multiSeriesEnabled,
                  definitive: flags.hasLoaded,
                );
                if (flags.multiSeriesEnabled) {
                  unawaited(series.loadManifest());
                }
                return series;
              },
              lazy: false,
            ),
          ],
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      );

      expect(find.byKey(WidgetKeys.welcomeStartListening), findsNothing);

      await tester.pump(_perFetchBudget);
      await tester.pump(const Duration(milliseconds: 400)); // reveal fade

      expect(find.byKey(WidgetKeys.welcomeStartListening), findsOneWidget);

      await tester.pump(const Duration(minutes: 2));
    },
  );
}
