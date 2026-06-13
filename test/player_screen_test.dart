import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/playback_source.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/download_button.dart';

Lecture _lec(String id, int num) => Lecture(
      id: id,
      number: num,
      chapterId: 'ch-1',
      title: {'en': 'Lecture $num'},
      audioUrl: 'https://example.com/$id.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1048576,
    );

final _lectures = List.generate(5, (i) => _lec('l${i + 1}', i + 1));

/// Builds a [PlayerNotifier] with offline-safe defaults and pumps
/// [PlayerScreen] wired to it. Optionally loads [lecture] via the
/// offline + undownloaded `loadAndPlay` early-return path, which never
/// touches the real `just_audio`/`audio_service` platform channels.
Future<PlayerNotifier> _pumpPlayer(
  WidgetTester tester, {
  Lecture? lecture,
  ConnectivityProvider? connectivity,
  DownloadsProvider? downloads,
  FeatureFlagsProvider? featureFlags,
  void Function(DownloadsProvider)? seedAfterLoad,
  void Function(PlayerNotifier)? configurePlayer,
}) async {
  final progress = ProgressProvider()..load();
  final downloadsProvider = downloads ?? DownloadsProvider();
  final connectivityProvider = connectivity ?? ConnectivityProvider.testOffline();
  final player = PlayerNotifier(
    TawheedAudioHandler(),
    progress,
    downloadsProvider,
    connectivityProvider,
  );

  if (lecture != null) {
    await player.loadAndPlay(lecture, _lectures);
  }
  // Seeded after loadAndPlay — `seedDownloadedForTest` would otherwise make
  // loadAndPlay's `localPathIfDownloaded` call into DownloadService, which
  // requires platform-channel init unavailable in widget tests.
  seedAfterLoad?.call(downloadsProvider);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: player),
      ChangeNotifierProvider.value(value: progress),
      ChangeNotifierProvider.value(value: downloadsProvider),
      ChangeNotifierProvider.value(value: connectivityProvider),
      ChangeNotifierProvider.value(value: featureFlags ?? FeatureFlagsProvider()),
      ChangeNotifierProvider.value(value: CatalogProvider()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const PlayerScreen()),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();

  // Configured after the initial pump — the audio handler's playbackState
  // stream emits its initial (idle) value asynchronously, which would
  // otherwise reset isStuckBuffering back to false before this runs.
  if (configurePlayer != null) {
    configurePlayer(player);
    await tester.pumpAndSettle();
  }

  return player;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  group('PlayerScreen — no lecture loaded', () {
    testWidgets('hides bookmark button and offline strip, disables skip controls',
        (tester) async {
      await _pumpPlayer(tester);

      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
      expect(find.byType(DownloadButton), findsNothing);

      final skipPrev = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
      );
      final skipNext = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
      );
      expect(skipPrev.onPressed, isNull);
      expect(skipNext.onPressed, isNull);
    });
  });

  group('PlayerScreen — offline status strip', () {
    testWidgets('shows "Not available offline" when streaming lecture is blocked',
        (tester) async {
      await _pumpPlayer(tester, lecture: _lectures[0]);

      expect(find.text('Not available offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('shows download progress when the lecture is downloading',
        (tester) async {
      await _pumpPlayer(
        tester,
        lecture: _lectures[0],
        seedAfterLoad: (d) => d.seedDownloadingForTest('l1'),
      );

      expect(find.text('Downloading… 50%'), findsOneWidget);
      // One in the offline strip, one in the app bar download button.
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    });

    testWidgets('shows "Saved for offline" when the lecture is downloaded',
        (tester) async {
      await _pumpPlayer(
        tester,
        lecture: _lectures[0],
        seedAfterLoad: (d) => d.seedDownloadedForTest('l1'),
      );

      expect(find.text('Saved for offline'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('shows "Streaming" when playing online and not downloaded',
        (tester) async {
      await _pumpPlayer(
        tester,
        connectivity: ConnectivityProvider.testOnline(),
        configurePlayer: (p) =>
            p.setPlaybackStateForTest(_lectures[0], source: PlaybackSource.stream),
      );

      expect(find.text('Streaming'), findsOneWidget);
      expect(find.byIcon(Icons.podcasts_rounded), findsOneWidget);
    });

    testWidgets('shows "Connection lost" when stuck buffering', (tester) async {
      await _pumpPlayer(
        tester,
        connectivity: ConnectivityProvider.testOnline(),
        configurePlayer: (p) => p.setPlaybackStateForTest(
          _lectures[0],
          source: PlaybackSource.stream,
          isStuckBuffering: true,
        ),
      );

      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('shows "No connection" when offline mid-stream (not blocked)',
        (tester) async {
      await _pumpPlayer(
        tester,
        connectivity: ConnectivityProvider.testOffline(),
        configurePlayer: (p) =>
            p.setPlaybackStateForTest(_lectures[0], source: PlaybackSource.stream),
      );

      expect(find.text('No connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });

  group('PlayerScreen — bookmark button', () {
    testWidgets('toggles between outline and filled icon on tap', (tester) async {
      await _pumpPlayer(tester, lecture: _lectures[0]);

      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
    });
  });

  group('PlayerScreen — download button', () {
    testWidgets('shown when downloads feature flag is on (default)', (tester) async {
      await _pumpPlayer(tester, lecture: _lectures[0]);

      expect(find.byType(DownloadButton), findsOneWidget);
    });

    testWidgets('hidden when downloads feature flag is off', (tester) async {
      await _pumpPlayer(
        tester,
        lecture: _lectures[0],
        featureFlags: FeatureFlagsProvider()..setFeaturesJsonForTest({'downloads': false}),
      );

      expect(find.byType(DownloadButton), findsNothing);
    });
  });

  group('PlayerScreen — transport controls', () {
    testWidgets('skip-previous disabled and skip-next enabled for the first lecture',
        (tester) async {
      await _pumpPlayer(tester, lecture: _lectures[0]);

      final skipPrev = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
      );
      final skipNext = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
      );
      expect(skipPrev.onPressed, isNull);
      expect(skipNext.onPressed, isNotNull);
    });

    testWidgets('skip-previous enabled for a non-first lecture', (tester) async {
      await _pumpPlayer(tester, lecture: _lectures[1]);

      final skipPrev = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
      );
      expect(skipPrev.onPressed, isNotNull);
    });

    testWidgets('playing next while offline and undownloaded shows the blocked dialog',
        (tester) async {
      final player = await _pumpPlayer(tester, lecture: _lectures[0]);

      await player.playNext();
      await tester.pumpAndSettle();

      expect(
        find.text("'Lecture 2' isn't saved. Download it when you're back online."),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text("'Lecture 2' isn't saved. Download it when you're back online."),
        findsNothing,
      );
    });
  });
}
