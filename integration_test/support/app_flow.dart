import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart' as app;
import 'package:myapp/widgets/lecture_tile.dart';

/// Shared helpers for integration tests — real device/emulator, network required.
///
/// Scenarios that need native OS control live in patrol_test/ (Patrol CLI).
class AppFlow {
  AppFlow._();

  static Future<void> launchApp(WidgetTester tester) async {
    unawaited(app.main());
    // First install: WelcomeScreen shows. Returning user (onboarding persisted):
    // app routes straight to /lectures — either is a valid cold-start state.
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 500));
      if (tester.any(find.text('START LISTENING'))) return;
      if (tester.any(find.byType(LectureTile))) return;
    }
    fail('Timed out after 30s waiting for welcome screen or lecture list after cold start');
  }

  /// Cold start through welcome (if shown) to a loaded lecture list.
  static Future<void> goToLectureList(WidgetTester tester) async {
    await dismissOverlays(tester);

    final start = find.text('START LISTENING');
    if (tester.any(start)) {
      await tester.tap(start);
      await pumpFrames(tester, count: 5);
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
    final wifiToggle = find.text('Download on Wi-Fi only');
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

  static Future<void> navigateToTab(WidgetTester tester, String label) async {
    await dismissOverlays(tester);
    final tab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
    expect(tab, findsOneWidget);
    await tester.tap(tab);
    await pumpFrames(tester, count: 5);
  }

  static Future<void> dismissOverlays(WidgetTester tester) async {
    await dismissBottomSheet(tester);
    await dismissOfflineLibrary(tester);
    await dismissPlayer(tester);
  }

  static Future<void> dismissPlayer(WidgetTester tester) async {
    // Arabic series shows 'يتم التشغيل الآن' instead of 'Now Playing'.
    final isOpen = tester.any(find.text('Now Playing')) ||
        tester.any(find.text('يتم التشغيل الآن'));
    if (!isOpen) return;
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
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
    if (!tester.any(find.text('Manage downloads'))) return;
    // Tap above the sheet — avoids ambiguous ModalBarrier matches on iOS.
    await tester.tapAt(const Offset(20, 80));
    await pumpFrames(tester, count: 3);
    if (tester.any(find.text('Manage downloads'))) {
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
    // Arabic series shows 'يتم التشغيل الآن' instead of 'Now Playing'.
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == 'Now Playing' || w.data == 'يتم التشغيل الآن'),
      ),
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
    final downloading = find.textContaining('Downloading');
    if (tester.any(downloading)) {
      await tester.tap(downloading);
      await pumpFrames(tester, count: 5);
      expect(find.text('Manage downloads'), findsOneWidget);
      return;
    }

    for (final label in ['Streaming', 'Saved for offline']) {
      final strip = find.text(label);
      if (tester.any(strip)) {
        await tester.tap(strip);
        await pumpFrames(tester, count: 5);
        expect(find.text('Manage downloads'), findsOneWidget);
        return;
      }
    }

    await tester.tap(find.byTooltip('Download for offline'));
    await pumpFrames(tester, count: 5);
    expect(find.text('Manage downloads'), findsOneWidget);
  }

  static Future<void> ensureLectureDownloaded(WidgetTester tester) async {
    if (tester.any(find.text('Saved for offline'))) return;

    await openOfflineSheetFromPlayer(tester);

    final downloadRow = find.textContaining('Download lecture');
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
    final remove = find.text('Remove download');
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
    await tester.tap(find.text('Manage downloads'));
    await waitFor(
      tester,
      find.widgetWithText(AppBar, 'Downloads'),
      timeout: const Duration(seconds: 15),
      reason: 'offline library screen',
    );
  }

  static Future<void> openOfflineLibraryFromSettings(WidgetTester tester) async {
    await navigateToTab(tester, 'Settings');
    await scrollToSettingsDownloads(tester);
    final storageRow = find.byIcon(Icons.storage_rounded);
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
    final cancel = find.text('Cancel download');
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
    for (final label in ['Settings', 'الإعدادات']) {
      final tab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      if (tester.any(tab)) {
        await tester.tap(tab);
        await pumpFrames(tester, count: 5);
        return;
      }
    }
  }

  /// Navigates to the Lectures tab regardless of current series language.
  static Future<void> navigateToLecturesTab(WidgetTester tester) async {
    await dismissOverlays(tester);
    for (final label in ['Lectures', 'الدروس']) {
      final tab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      if (tester.any(tab)) {
        await tester.tap(tab);
        await pumpFrames(tester, count: 5);
        return;
      }
    }
  }

  /// Taps the Book tab. Returns false if the tab is absent (Urdu series has no
  /// Book tab).
  static Future<bool> navigateToBookTab(WidgetTester tester) async {
    await dismissOverlays(tester);
    for (final label in ['Book', 'الكتاب']) {
      final tab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      if (tester.any(tab)) {
        await tester.tap(tab);
        await pumpFrames(tester, count: 5);
        return true;
      }
    }
    return false;
  }

  /// Switches to [displayName] (canonical English name, e.g.
  /// `'Kitab at-Tawheed (Arabic)'`) via the Settings series picker.
  ///
  /// Returns false without switching if the seriesSwitcher flag is disabled
  /// in this environment (the series row will simply not be present).
  static Future<bool> switchToSeries(
    WidgetTester tester,
    String displayName,
  ) async {
    await navigateToSettingsTab(tester);

    // Scroll until the series row (library_books icon) is visible.
    final seriesRow = find.byIcon(Icons.library_books_rounded);
    final scrollEnd = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(scrollEnd)) {
      if (tester.any(seriesRow)) break;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await pumpFrames(tester, count: 2);
    }
    if (!tester.any(seriesRow)) return false;

    await tester.ensureVisible(seriesRow);
    await pumpFrames(tester, count: 2);
    await tester.tap(seriesRow);
    await pumpFrames(tester, count: 3);

    // Picker sheet — canonical English names are always shown regardless of
    // the current UI language, so find.text works unconditionally.
    final seriesOption = find.text(displayName);
    await waitFor(
      tester,
      seriesOption,
      timeout: const Duration(seconds: 5),
      reason: 'series option "$displayName" in picker sheet',
    );
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
      reason: 'lecture list after switching to "$displayName"',
    );
    return true;
  }
}

/// Long enough for catalog load, download, and cleanup on device.
const integrationTimeout = Timeout(Duration(minutes: 15));
