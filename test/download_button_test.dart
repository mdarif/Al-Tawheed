import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/download_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A lecture whose URL can never be fetched, so a real download attempt lands
/// in [DownloadStatus.failed] without touching the network.
const _lecture = Lecture(
  id: 'failing',
  number: 1,
  chapterId: 'ch-01',
  title: {'en': 'Failing lecture'},
  audioUrl: 'not a URL',
  durationSeconds: 60,
  fileSizeBytes: 1000,
);

Widget _wrap(DownloadsProvider downloads) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: downloads),
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider.testOnline(),
        ),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(child: DownloadButton(lecture: _lecture)),
        ),
      ),
    );

/// Drives a real attempt to failure. The attempt does real I/O, so it runs
/// outside the fake-async zone.
Future<void> _failDownload(WidgetTester tester, DownloadsProvider d) async {
  await tester.runAsync(() async {
    d.downloadNowOrQueue(lecture: _lecture, isOnline: true, isWifi: true);
    for (var i = 0; i < 100; i++) {
      if (d.statusFor(_lecture.id) == DownloadStatus.failed) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  expect(d.statusFor(_lecture.id), DownloadStatus.failed);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('download_button_test_');
    DownloadService.resetForTest(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('DownloadButton failed state', () {
    testWidgets('offers both Retry and Remove, like the Library row',
        (tester) async {
      final downloads = DownloadsProvider();
      await tester.pumpWidget(_wrap(downloads));
      await _failDownload(tester, downloads);
      await tester.pump();

      expect(find.byTooltip('Retry download'), findsOneWidget);
      expect(find.byTooltip('Remove download'), findsOneWidget);
    });

    testWidgets('Remove discards the durable queue entry and resets the row',
        (tester) async {
      final downloads = DownloadsProvider();
      await tester.pumpWidget(_wrap(downloads));
      await _failDownload(tester, downloads);
      await tester.pump();
      // The failed attempt still owns its durable queue intent.
      expect(downloads.queuedDownloadCount, 1);

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Remove download'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(downloads.statusFor(_lecture.id), DownloadStatus.notDownloaded);
      expect(downloads.queuedDownloadCount, 0);
      expect(downloads.failureFor(_lecture.id), isNull);
      // Durable: a restarted provider must not resurrect the discarded intent.
      final restored = DownloadsProvider();
      await tester.runAsync(restored.load);
      expect(restored.queuedDownloadCount, 0);
      expect(find.byTooltip('Download for offline'), findsOneWidget);
      expect(find.byTooltip('Remove download'), findsNothing);
    });

    testWidgets('Retry still restarts the download', (tester) async {
      final downloads = DownloadsProvider();
      await tester.pumpWidget(_wrap(downloads));
      await _failDownload(tester, downloads);
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Retry download'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Same unreachable URL: it fails again, but through a fresh attempt.
      expect(downloads.statusFor(_lecture.id), DownloadStatus.failed);
      expect(find.byTooltip('Remove download'), findsOneWidget);
    });
  });
}
