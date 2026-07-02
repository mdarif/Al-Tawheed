import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_flow.dart';

// Minimal, robust GENUINE tablet capture — renders at the tablet's real
// resolution. Urdu series only (no Arabic switching / multiSeries dependency,
// which is flaky on emulators), so it runs reliably on a tablet emulator.
//
//   SCREENSHOT_RAW_DIR=docs/play-store/v3/raw-tablet-7 flutter drive \
//     --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_tablet_test.dart -d <tablet>

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    await AppFlow.pumpFrames(
      tester,
      count: 5,
      duration: const Duration(milliseconds: 400),
    );
    await binding.takeScreenshot(name);
  }

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

  testWidgets(
    'capture genuine tablet screenshots (Urdu series)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      unawaited(app.main());

      // Welcome.
      await AppFlow.waitFor(
        tester,
        find.byIcon(Icons.headphones_rounded),
        timeout: const Duration(seconds: 40),
        reason: 'welcome',
      );
      await shot(tester, 't-01-welcome');

      // START LISTENING → choose-series (pick Urdu) if it appears, else lectures.
      await tester.tap(find.byIcon(Icons.headphones_rounded).first);
      await AppFlow.pumpFrames(tester, count: 8);
      if (tester.any(find.text('Select a series to begin learning'))) {
        await tester.tap(
          find
              .ancestor(
                of: find.textContaining('Rahmani'),
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
        if (tester.any(find.byIcon(Icons.headphones_rounded))) {
          await tester.tap(find.byIcon(Icons.headphones_rounded).first);
          await AppFlow.pumpFrames(tester, count: 5);
        }
      }
      await AppFlow.waitForCatalog(tester);
      await shot(tester, 't-02-lectures');

      // Study Mode.
      if (await tapTab(tester, ['Study'])) {
        await AppFlow.pumpFrames(tester, count: 6);
        await shot(tester, 't-03-study');
      }

      // Player.
      await tapTab(tester, ['Lectures']);
      await AppFlow.openFirstLecture(tester);
      await shot(tester, 't-04-player');
      await AppFlow.dismissPlayer(tester);

      // Settings.
      await tapTab(tester, ['Settings']);
      await AppFlow.pumpFrames(tester, count: 4);
      await shot(tester, 't-05-settings');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
