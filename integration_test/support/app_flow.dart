import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart' as app;
import 'package:myapp/models/series.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/utils/startup_metrics.dart';
import 'package:myapp/widgets/lecture_tile.dart';

/// Shared helpers for integration tests — real device/emulator, network required.
///
/// Scenarios that need native OS control live in patrol_test/ (Patrol CLI).
enum AppTab { lectures, book, study, settings }

extension on AppTab {
  Key get key => switch (this) {
        AppTab.lectures => WidgetKeys.shellLecturesTab,
        AppTab.book => WidgetKeys.shellBookTab,
        AppTab.study => WidgetKeys.shellStudyTab,
        AppTab.settings => WidgetKeys.shellSettingsTab,
      };
}

class AppFlow {
  AppFlow._();

  static Future<void> launchApp(WidgetTester tester) async {
    unawaited(app.main());
    // First install: WelcomeScreen shows. Returning user (onboarding persisted):
    // app routes straight to /lectures — either is a valid cold-start state.
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 500));
      if (tester.any(find.byKey(WidgetKeys.welcomeStartListening))) return;
      if (tester.any(find.byType(LectureTile))) return;
    }
    fail(
      'Timed out after 30s waiting for welcome screen or lecture list after cold start',
    );
  }

  /// Waits for the startup marker while continuing to advance Flutter frames.
  /// WelcomeScreen intentionally mounts its marker beneath a 300 ms reveal;
  /// checking the key alone can therefore return while it is still hidden.
  static Future<StartupMeasurement> waitForStartupInteractive(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (StartupMetrics.measurement == null && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final measurement = StartupMetrics.measurement;
    if (measurement == null) {
      fail(
        'Timed out after ${timeout.inSeconds}s waiting for the startup '
        'interactive marker while pumping frames',
      );
    }
    return measurement;
  }

  /// Cold start through welcome (if shown) to a loaded lecture list.
  static Future<void> goToLectureList(WidgetTester tester) async {
    await dismissOverlays(tester);

    final start = find.byKey(WidgetKeys.welcomeStartListening);
    if (tester.any(start)) {
      // The button lives inside IgnorePointer(ignoring: !isReady) and is
      // present in the tree at opacity 0 before SeriesProvider.isSeriesReady
      // becomes true. Retry until the tap lands and navigation occurs (the
      // widget disappears from the tree).
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (tester.any(start) && DateTime.now().isBefore(deadline)) {
        await tester.tap(start, warnIfMissed: false);
        await pumpFrames(tester, count: 5);
      }
      if (tester.any(start)) {
        fail(
          'START LISTENING button still blocked by IgnorePointer after 15s — '
          'SeriesProvider.isSeriesReady never became true',
        );
      }
    }

    // On first install with multiple series, START LISTENING pushes to
    // /choose-series instead of /lectures. Tap the first series card, then
    // confirm the dialog if one appears.
    final seriesCard =
        find.byKey(WidgetKeys.chooseSeriesCard(SeriesConfig.legacyId));
    if (tester.any(seriesCard)) {
      await tester.tap(seriesCard.first);
      await pumpFrames(tester, count: 5);
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      if (tester.any(confirmBtn)) {
        await tester.tap(confirmBtn);
        await pumpFrames(tester, count: 5);
      }
    }

    await waitForCatalog(tester);
  }

  static Future<void> waitForCatalog(WidgetTester tester) async {
    final end = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 500));
      if (tester.any(find.byType(LectureTile))) return;
      if (tester.any(find.text('Connect to load lectures'))) {
        fail(
          'Catalog needs network on first launch. Connect the device and retry.',
        );
      }
      if (tester.any(find.text('Could not load lectures'))) {
        fail('Catalog fetch failed. Check network and CDN availability.');
      }
    }
    fail('Timed out after 90s waiting for catalog load');
  }

  static Future<void> scrollToSettingsDownloads(WidgetTester tester) async {
    final wifiToggle = find.byKey(WidgetKeys.settingsDownloadOnWifiOnly);
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      if (tester.any(wifiToggle)) return;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await pumpFrames(tester, count: 2);
    }
    fail(
      'Downloads section not visible — is the downloads feature flag enabled?',
    );
  }

  static Future<void> navigateToTab(WidgetTester tester, AppTab tab) async {
    await dismissOverlays(tester);
    final destination = find.byKey(tab.key);
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    await pumpFrames(tester, count: 5);
  }

  static Future<void> dismissOverlays(WidgetTester tester) async {
    await dismissBottomSheet(tester);
    await dismissOfflineLibrary(tester);
    await dismissPlayer(tester);
  }

  static Future<void> dismissPlayer(WidgetTester tester) async {
    final isOpen = tester.any(find.byKey(WidgetKeys.playerClose));
    if (!isOpen) return;
    await tester.tap(find.byKey(WidgetKeys.playerClose));
    await pumpFrames(tester, count: 5);
    await waitFor(
      tester,
      find.byType(LectureTile),
      timeout: const Duration(seconds: 15),
      reason: 'lecture list after closing player',
    );
  }

  static Future<void> dismissOfflineLibrary(WidgetTester tester) async {
    if (!tester.any(find.widgetWithText(AppBar, 'Downloads'))) return;
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester, count: 3);
  }

  static Future<void> dismissBottomSheet(WidgetTester tester) async {
    if (!tester.any(find.byKey(WidgetKeys.offlineManageDownloads))) return;
    // Tap above the sheet — avoids ambiguous ModalBarrier matches on iOS.
    await tester.tapAt(const Offset(20, 80));
    await pumpFrames(tester, count: 3);
    if (tester.any(find.byKey(WidgetKeys.offlineManageDownloads))) {
      await tester.tapAt(const Offset(20, 80));
      await pumpFrames(tester, count: 3);
    }
  }

  static Future<void> openFirstLecture(WidgetTester tester) async {
    await dismissOverlays(tester);
    await waitFor(
      tester,
      find.byType(LectureTile),
      timeout: const Duration(seconds: 15),
      reason: 'lecture list before opening player',
    );
    await tester.tap(find.byType(LectureTile).first);
    await waitForPlayerReady(tester);
  }

  static Future<void> waitForPlayerReady(WidgetTester tester) async {
    await waitFor(
      tester,
      find.byKey(WidgetKeys.playerClose),
      timeout: const Duration(seconds: 30),
      reason: 'player screen',
    );
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.play_arrow_rounded ||
                w.icon == Icons.pause_rounded),
      ),
      timeout: const Duration(seconds: 60),
      reason: 'player transport controls',
    );
  }

  static Future<void> expectMiniPlayerVisible(WidgetTester tester) async {
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) => w is LinearProgressIndicator && w.minHeight == 2,
      ),
      timeout: const Duration(seconds: 10),
      reason: 'mini player progress bar',
    );
  }

  static Future<void> openPlayerFromMiniPlayer(WidgetTester tester) async {
    final miniBar = find.ancestor(
      of: find.byWidgetPredicate(
        (w) => w is LinearProgressIndicator && w.minHeight == 2,
      ),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(miniBar);
    await waitForPlayerReady(tester);
  }

  static Future<void> openOfflineSheetFromPlayer(WidgetTester tester) async {
    final status = find.byKey(WidgetKeys.playerOfflineStatus);
    if (tester.any(status)) {
      await tester.tap(status);
      await pumpFrames(tester, count: 5);
      expect(find.byKey(WidgetKeys.offlineManageDownloads), findsOneWidget);
      return;
    }

    await tester.tap(find.byKey(WidgetKeys.playerDownload));
    await pumpFrames(tester, count: 5);
    expect(find.byKey(WidgetKeys.offlineManageDownloads), findsOneWidget);
  }

  static Future<void> ensureLectureDownloaded(WidgetTester tester) async {
    if (tester.any(find.text('Saved for offline'))) return;

    await openOfflineSheetFromPlayer(tester);

    final downloadRow = find.byKey(WidgetKeys.offlineDownloadLecture);
    if (tester.any(downloadRow)) {
      await tester.tap(downloadRow);
      await pumpFrames(tester, count: 3);
      await waitForDownloadComplete(tester);
      return;
    }

    // Already on disk from a previous run — sheet shows remove, not download.
    await dismissBottomSheet(tester);
    await waitFor(
      tester,
      find.text('Saved for offline'),
      timeout: const Duration(seconds: 15),
      reason: 'saved-for-offline strip',
    );
  }

  static Future<void> removeDownloadFromPlayer(WidgetTester tester) async {
    await openOfflineSheetFromPlayer(tester);
    final remove = find.byKey(WidgetKeys.offlineRemoveDownload);
    expect(remove, findsOneWidget);
    await tester.tap(remove);
    await pumpFrames(tester, count: 3);

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Remove download'),
    );
    await waitFor(
      tester,
      confirm,
      timeout: const Duration(seconds: 5),
      reason: 'remove-download confirm dialog',
    );
    await tester.tap(confirm);
    await pumpFrames(tester, count: 5);

    await waitFor(
      tester,
      find.text('Streaming'),
      timeout: const Duration(seconds: 30),
      reason: 'streaming strip after remove',
    );
  }

  static Future<void> openOfflineLibraryFromSheet(WidgetTester tester) async {
    await openOfflineSheetFromPlayer(tester);
    await tester.tap(find.byKey(WidgetKeys.offlineManageDownloads));
    await waitFor(
      tester,
      find.widgetWithText(AppBar, 'Downloads'),
      timeout: const Duration(seconds: 15),
      reason: 'offline library screen',
    );
  }

  static Future<void> openOfflineLibraryFromSettings(
    WidgetTester tester,
  ) async {
    await navigateToTab(tester, AppTab.settings);
    await scrollToSettingsDownloads(tester);
    final storageRow = find.byKey(WidgetKeys.settingsOfflineLibrary);
    expect(storageRow, findsOneWidget);

    // scrollToSettingsDownloads only checks the element tree, not the
    // viewport — on small screens the row can exist via ListView's
    // cacheExtent without being scrolled into view yet, so a tap on its
    // (off-screen) center lands on the route overlay instead. Scroll it
    // fully into view before tapping.
    await tester.ensureVisible(storageRow);
    await pumpFrames(tester, count: 3);

    final appBar = find.widgetWithText(AppBar, 'Downloads');
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      if (tester.any(appBar)) return;
      if (tester.any(storageRow)) {
        await tester.tap(storageRow, warnIfMissed: false);
      }
      await pumpFrames(tester, count: 2);
    }
    if (tester.any(appBar)) return;
    fail('Timed out after 15s waiting for offline library from settings');
  }

  static Future<void> startDownloadFromListTile(WidgetTester tester) async {
    await dismissOverlays(tester);
    final button = find.descendant(
      of: find.byType(LectureTile).first,
      matching: find.byTooltip('Download for offline'),
    );
    await tester.tap(button);
    await pumpFrames(tester, count: 3);
  }

  static Future<void> cancelDownloadFromPlayer(WidgetTester tester) async {
    await openOfflineSheetFromPlayer(tester);
    final cancel = find.byKey(WidgetKeys.offlineCancelDownload);
    if (!tester.any(cancel)) {
      await dismissBottomSheet(tester);
      return;
    }
    await tester.tap(cancel);
    await pumpFrames(tester, count: 5);
    await waitFor(
      tester,
      find.text('Streaming'),
      timeout: const Duration(seconds: 30),
      reason: 'streaming strip after cancel',
    );
  }

  /// Waits for an active download indicator, or skips if it already finished.
  static Future<void> waitForDownloadProgressOrComplete(
    WidgetTester tester,
  ) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 500));
      if (tester.any(find.textContaining('Downloading'))) return;
      if (tester.any(find.text('Saved for offline'))) return;
    }
    fail('Timed out waiting for download progress or completion');
  }

  static Future<void> waitForDownloadComplete(WidgetTester tester) async {
    await waitFor(
      tester,
      find.text('Saved for offline'),
      timeout: const Duration(minutes: 4),
      reason: 'download completion',
    );
  }

  static Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 3,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(duration);
    }
  }

  static Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    required Duration timeout,
    required String reason,
    Duration step = const Duration(milliseconds: 500),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(step);
      if (tester.any(finder)) return;
    }
    fail('Timed out after ${timeout.inSeconds}s waiting for $reason');
  }

  // ── Arabic / multi-series helpers ──────────────────────────────────────────

  /// Navigates to the Settings tab using both English and Arabic label fallback
  /// so it works regardless of which series is currently active.
  static Future<void> navigateToSettingsTab(WidgetTester tester) async {
    await dismissOverlays(tester);
    final tab = find.byKey(WidgetKeys.shellSettingsTab);
    if (tester.any(tab)) {
      await tester.tap(tab);
      await pumpFrames(tester, count: 5);
      return;
    }
    fail('Settings tab is not available');
  }

  /// Navigates to the Lectures tab regardless of current series language.
  static Future<void> navigateToLecturesTab(WidgetTester tester) async {
    await dismissOverlays(tester);
    final tab = find.byKey(WidgetKeys.shellLecturesTab);
    if (tester.any(tab)) {
      await tester.tap(tab);
      await pumpFrames(tester, count: 5);
      return;
    }
    fail('Lectures tab is not available');
  }

  /// Taps the Book tab. Returns false if the tab is absent (Urdu series has no
  /// Book tab).
  static Future<bool> navigateToBookTab(WidgetTester tester) async {
    await dismissOverlays(tester);
    final tab = find.byKey(WidgetKeys.shellBookTab);
    if (tester.any(tab)) {
      await tester.tap(tab);
      await pumpFrames(tester, count: 5);
      return true;
    }
    return false;
  }

  /// Switches to [seriesId] via the Settings series picker.
  ///
  /// Returns false without switching if the seriesSwitcher flag is disabled
  /// in this environment (the series row will simply not be present).
  static Future<bool> switchToSeries(
    WidgetTester tester,
    String seriesId,
  ) async {
    await navigateToSettingsTab(tester);

    final seriesOption = find.byKey(WidgetKeys.settingsSeriesOption(seriesId));
    final scrollEnd = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(scrollEnd)) {
      if (tester.any(seriesOption)) break;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await pumpFrames(tester, count: 2);
    }
    if (!tester.any(seriesOption)) return false;

    await tester.ensureVisible(seriesOption);
    await pumpFrames(tester, count: 2);
    await tester.tap(seriesOption);
    await pumpFrames(tester, count: 3);

    // Confirm dialog — target the FilledButton regardless of its label locale.
    final confirmBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    await waitFor(
      tester,
      confirmBtn,
      timeout: const Duration(seconds: 5),
      reason: 'series change confirm dialog',
    );
    await tester.tap(confirmBtn);
    await pumpFrames(tester, count: 5);

    await waitFor(
      tester,
      find.byType(LectureTile),
      timeout: const Duration(seconds: 30),
      reason: 'lecture list after switching to "$seriesId"',
    );
    return true;
  }
}

/// Long enough for catalog load, download, and cleanup on device.
const integrationTimeout = Timeout(Duration(minutes: 15));
