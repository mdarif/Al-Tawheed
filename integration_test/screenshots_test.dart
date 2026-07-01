import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/main.dart' as app;
import 'package:myapp/widgets/lecture_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_flow.dart';

// Captures the Play Store screenshot set (v3) in one pass from a fresh install,
// covering BOTH experiences:
//   • Arabic series  — Arabic chrome (يُشغَّل الآن، الدروس) + the Arabic Book tab.
//   • Urdu series    — English chrome (Now Playing, Study Mode, Settings) + the
//                      Urdu-only Study Mode.
// It picks Arabic first (to get the Arabic welcome + Book), then switches to the
// Urdu series via Settings to capture the English-chrome screens.
//
//   flutter drive \
//     --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart \
//     -d DEVICE_ID
//
// Prod remote config has multiSeries + seriesSwitcher enabled. Prefs are cleared
// so onboarding renders. One testWidgets — AudioService is a process singleton
// (docs/gotchas.md).

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    // Bounded pump (pumpAndSettle can hang on the player's progress animation).
    await AppFlow.pumpFrames(
      tester,
      count: 5,
      duration: const Duration(milliseconds: 400),
    );
    await binding.takeScreenshot(name);
  }

  // Taps a bottom-nav tab by trying each label (series chrome differs).
  Future<bool> tapTab(WidgetTester tester, List<String> labels) async {
    await AppFlow.dismissOverlays(tester);
    for (final label in labels) {
      final tab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      if (tester.any(tab)) {
        await tester.tap(tab);
        await AppFlow.pumpFrames(tester, count: 5);
        return true;
      }
    }
    return false;
  }

  // Switches the content series via Settings → language row (اردو / العربية),
  // confirms, and lands on the new series' lectures (tapping through its welcome
  // if this is the first time that series is opened).
  Future<void> switchSeries(WidgetTester tester, String endonym) async {
    await tapTab(tester, ['Settings', 'الإعدادات']);
    await AppFlow.pumpFrames(tester, count: 4);
    final row = find.text(endonym);
    await tester.ensureVisible(row.first);
    await AppFlow.pumpFrames(tester, count: 2);
    await tester.tap(row.first);
    await AppFlow.pumpFrames(tester, count: 3);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    await AppFlow.waitFor(
      tester,
      confirm,
      timeout: const Duration(seconds: 6),
      reason: 'series-switch confirm dialog',
    );
    await tester.tap(confirm);
    await AppFlow.pumpFrames(tester, count: 6);
    // Switching may route to the new series' welcome (first encounter).
    if (tester.any(find.byIcon(Icons.headphones_rounded))) {
      await tester.tap(find.byIcon(Icons.headphones_rounded).first);
      await AppFlow.pumpFrames(tester, count: 5);
    }
    await AppFlow.waitForCatalog(tester);
  }

  testWidgets(
    'capture Play Store screenshots (v3, both series)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      unawaited(app.main());

      // ── Urdu welcome (first-run, English "START LISTENING") ──────────────────
      await AppFlow.waitFor(
        tester,
        find.byIcon(Icons.headphones_rounded),
        timeout: const Duration(seconds: 30),
        reason: 'Urdu welcome screen',
      );
      await shot(tester, '04-welcome-ur');

      // Let flags + manifest load so START LISTENING routes to /choose-series.
      await AppFlow.pumpFrames(
        tester,
        count: 12,
        duration: const Duration(milliseconds: 500),
      );

      // ── Choose-Series picker (Arabic + Urdu) ─────────────────────────────────
      await tester.tap(find.byIcon(Icons.headphones_rounded).first);
      await AppFlow.waitFor(
        tester,
        find.text('Select a series to begin learning'),
        timeout: const Duration(seconds: 20),
        reason: 'Choose-Series picker (needs multiSeries flag loaded)',
      );
      await shot(tester, '03-choose-series');

      // ── Pick Arabic → Arabic welcome (al-Fawzan) ─────────────────────────────
      await tester.tap(
        find
            .ancestor(
              of: find.textContaining('Fawzan'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await AppFlow.pumpFrames(tester, count: 5);
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      if (tester.any(confirm)) {
        await tester.tap(confirm);
        await AppFlow.pumpFrames(tester, count: 5);
      }
      await _waitForEither(
        tester,
        find.byIcon(Icons.headphones_rounded),
        find.byType(LectureTile),
        const Duration(seconds: 20),
      );
      if (tester.any(find.byIcon(Icons.headphones_rounded))) {
        await shot(tester, '01-welcome-ar');
        await tester.tap(find.byIcon(Icons.headphones_rounded).first);
      }

      // ── Arabic series: lectures الدروس, Book الكتاب, player يُشغَّل الآن ─────────
      await AppFlow.waitForCatalog(tester);
      await shot(tester, '09-lectures-ar');

      if (await AppFlow.navigateToBookTab(tester)) {
        await AppFlow.pumpFrames(tester, count: 6);
        await shot(tester, '02-book-ar');
      }

      await tapTab(tester, ['Lectures', 'الدروس']);
      await AppFlow.openFirstLecture(tester);
      await shot(tester, '08-player-ar');
      await AppFlow.dismissPlayer(tester);

      // ── Switch to the Urdu series (English chrome) ───────────────────────────
      await switchSeries(tester, 'اردو');

      // Urdu lectures — English "Class 01 — Part 01", Study tab visible.
      await tapTab(tester, ['Lectures']);
      await AppFlow.waitForCatalog(tester);
      await shot(tester, '05-lectures-ur');

      // Study Mode — Urdu-only feature (not present in Arabic).
      if (await tapTab(tester, ['Study'])) {
        await AppFlow.pumpFrames(tester, count: 6);
        await shot(tester, '06-study-ur');
      }

      // Now Playing — English player chrome.
      await tapTab(tester, ['Lectures']);
      await AppFlow.openFirstLecture(tester);
      await shot(tester, '07-player-ur');
      await AppFlow.dismissPlayer(tester);

      // Settings — English chrome (Appearance, Language, Playback, Downloads).
      await tapTab(tester, ['Settings']);
      await AppFlow.pumpFrames(tester, count: 4);
      await shot(tester, '10-settings-ur');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Waits until either [a] or [b] is present; returns true if either appeared.
Future<bool> _waitForEither(
  WidgetTester tester,
  Finder a,
  Finder b,
  Duration timeout,
) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (tester.any(a) || tester.any(b)) return true;
  }
  return false;
}
