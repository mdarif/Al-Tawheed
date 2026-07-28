import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/lecture_tile.dart';

Lecture _lec() => const Lecture(
      id: 'lec-003',
      number: 3,
      chapterId: 'class-01',
      title: {'en': 'Class 01 — Part 03'},
      audioUrl: 'https://pub.example.r2.dev/lec-003.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1000,
    );

FeatureFlagsProvider _flags({required bool downloads, required bool share}) =>
    FeatureFlagsProvider()
      ..setFeaturesJsonForTest({
        'downloads': downloads,
        'shareLectureRow': share,
      });

Widget _wrap(
  FeatureFlagsProvider flags, {
  ConnectivityProvider? connectivity,
  DownloadsProvider? downloads,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: flags),
      ChangeNotifierProvider.value(
        value: connectivity ?? ConnectivityProvider.testOnline(),
      ),
      ChangeNotifierProvider.value(value: downloads ?? DownloadsProvider()),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => SeriesProvider()..load(false)),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => AppConfigProvider()),
      ChangeNotifierProvider(
        create: (ctx) => PlayerNotifier(
          TawheedAudioHandler(),
          ctx.read<ProgressProvider>(),
          ctx.read<DownloadsProvider>(),
          ctx.read<ConnectivityProvider>(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: LectureTile(lecture: _lec())),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets('a lecture row offers a share button when the flag is on',
      (tester) async {
    await tester.pumpWidget(_wrap(_flags(downloads: false, share: true)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share lecture'), findsOneWidget);
  });

  testWidgets('no share button when the shareButton flag is off',
      (tester) async {
    await tester.pumpWidget(_wrap(_flags(downloads: false, share: false)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share lecture'), findsNothing);
  });

  testWidgets('tapping share sends the title + a link to the lecture web page',
      (tester) async {
    final sharePlatform = _FakeSharePlatform();
    SharePlatform.instance = sharePlatform;

    await tester.pumpWidget(_wrap(_flags(downloads: false, share: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share lecture'));
    await tester.pumpAndSettle();

    expect(
      sharePlatform.lastParams?.text,
      'Class 01 — Part 03\n\n'
      'https://kitabattawheed.com/lectures/class-01/part-03/',
    );
  });

  testWidgets('offline unavailable rows stay readable and show an offline cue',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _flags(downloads: true, share: false),
        connectivity: ConnectivityProvider.testOffline(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('downloaded rows do not show the offline-unavailable cue offline',
      (tester) async {
    final downloads = DownloadsProvider()..seedDownloadedForTest(_lec().id);

    await tester.pumpWidget(
      _wrap(
        _flags(downloads: true, share: false),
        connectivity: ConnectivityProvider.testOffline(),
        downloads: downloads,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('lecture rows show a pressed surface tint on touch',
      (tester) async {
    await tester.pumpWidget(_wrap(_flags(downloads: false, share: false)));
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(InkWell)));
    await tester.pump();

    final pressedSurfaces = tester.widgetList<AnimatedContainer>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color != null,
      ),
    );
    expect(pressedSurfaces, isNotEmpty);

    await gesture.cancel();
  });

  testWidgets('current lecture shows animated now-playing bars while playing',
      (tester) async {
    await tester.pumpWidget(_wrap(_flags(downloads: false, share: false)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LectureTile));
    context.read<PlayerNotifier>().setPlaybackStateForTest(
          _lec(),
          isPlaying: true,
        );
    await tester.pump();

    expect(find.byType(NowPlayingBars), findsOneWidget);
    expect(
      tester.widget<NowPlayingBars>(find.byType(NowPlayingBars)).playing,
      isTrue,
    );
    expect(find.byIcon(Icons.equalizer_rounded), findsNothing);
    expect(find.text('Now Playing'), findsOneWidget);
  });

  testWidgets('current lecture keeps now-playing bars static while paused',
      (tester) async {
    await tester.pumpWidget(_wrap(_flags(downloads: false, share: false)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LectureTile));
    context.read<PlayerNotifier>().setPlaybackStateForTest(
          _lec(),
          isPlaying: false,
        );
    await tester.pump();

    expect(find.byType(NowPlayingBars), findsOneWidget);
    expect(
      tester.widget<NowPlayingBars>(find.byType(NowPlayingBars)).playing,
      isFalse,
    );
    expect(find.text('Now Playing'), findsOneWidget);
  });

  testWidgets('trailing actions fit on a narrow phone row', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PreferencesService.instance.saveBookmarks({_lec().id});

    await tester.pumpWidget(_wrap(_flags(downloads: true, share: true)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byTooltip('Download for offline'), findsOneWidget);
    expect(find.byTooltip('Share lecture'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return ShareResult('', ShareResultStatus.success);
  }
}
