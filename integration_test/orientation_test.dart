import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/widgets/lecture_tile.dart';

import 'support/app_flow.dart';

// Simulates portrait/landscape flips by swapping tester.view.physicalSize.
// This forces a real Flutter relayout — catching overflow, clipped widgets,
// scroll-state loss, and SafeArea regressions — without requiring Patrol's
// native OS rotation (which is non-deterministic on some devices).
//
// All scenarios run inside a single testWidgets call because AudioService
// is a singleton that can only be initialised once per process.
//
// Run on device:
//   flutter test integration_test/orientation_test.dart -d <device_id> --timeout 15m

// Swaps width/height to produce a landscape Size from the device's portrait size.
Size _landscape(Size portrait) => Size(portrait.height, portrait.width);

// Flip to landscape and let Flutter reflow.
Future<void> _toL(WidgetTester tester, Size landscape) async {
  tester.view.physicalSize = landscape;
  await AppFlow.pumpFrames(tester, count: 6);
}

// Flip back to portrait and let Flutter reflow.
Future<void> _toP(WidgetTester tester, Size portrait) async {
  tester.view.physicalSize = portrait;
  await AppFlow.pumpFrames(tester, count: 6);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'orientation — all screens survive portrait/landscape flip',
    (tester) async {
      await AppFlow.launchApp(tester);
      await AppFlow.goToLectureList(tester);

      // Capture the device's real portrait size once the app is running.
      final portrait = tester.view.physicalSize;
      final landscape = _landscape(portrait);

      // ── 1. Lecture list ───────────────────────────────────────────────────
      expect(
        find.byType(LectureTile),
        findsWidgets,
        reason: 'lecture tiles visible in portrait',
      );
      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'nav bar visible in portrait',
      );

      await _toL(tester, landscape);
      expect(
        find.byType(LectureTile),
        findsWidgets,
        reason: 'lecture tiles visible in landscape',
      );
      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'nav bar visible in landscape',
      );
      // RenderFlex overflows surface as test errors automatically.

      await _toP(tester, portrait);
      expect(
        find.byType(LectureTile),
        findsWidgets,
        reason: 'lecture tiles visible after returning to portrait',
      );

      // ── 2. Player screen ──────────────────────────────────────────────────
      await AppFlow.openFirstLecture(tester);

      final hasTransport = tester.any(find.byIcon(Icons.play_arrow_rounded)) ||
          tester.any(find.byIcon(Icons.pause_rounded));
      expect(
        hasTransport,
        isTrue,
        reason: 'transport control visible in portrait',
      );
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      await _toL(tester, landscape);

      final hasTransportL = tester.any(find.byIcon(Icons.play_arrow_rounded)) ||
          tester.any(find.byIcon(Icons.pause_rounded));
      expect(
        hasTransportL,
        isTrue,
        reason: 'transport control visible in landscape',
      );
      expect(
        find.byIcon(Icons.skip_next_rounded),
        findsOneWidget,
        reason: 'skip next visible in landscape',
      );
      expect(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
        findsOneWidget,
        reason: 'player close chevron visible in landscape',
      );

      await _toP(tester, portrait);

      final hasTransportP = tester.any(find.byIcon(Icons.play_arrow_rounded)) ||
          tester.any(find.byIcon(Icons.pause_rounded));
      expect(
        hasTransportP,
        isTrue,
        reason: 'transport control visible after returning to portrait',
      );

      // ── 3. Home screen ───────────────────────────────────────────────────
      // Dismiss player first so the nav bar is accessible.
      await AppFlow.dismissPlayer(tester);

      // Navigate to Home — try English label first, then Arabic for the
      // Arabic series (mirrors the pattern in navigateToLecturesTab).
      for (final label in ['Home', 'الرئيسية']) {
        final tab = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );
        if (tester.any(tab)) {
          await tester.tap(tab);
          await AppFlow.pumpFrames(tester, count: 5);
          break;
        }
      }

      // The Home tab has a SliverAppBar — it's always present regardless of
      // content load state (no catalog needed for the Home chrome).
      expect(
        find.byType(SliverAppBar),
        findsOneWidget,
        reason: 'Home screen SliverAppBar visible in portrait',
      );

      await _toL(tester, landscape);
      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'nav bar visible on Home in landscape',
      );
      expect(
        find.byType(SliverAppBar),
        findsOneWidget,
        reason: 'Home SliverAppBar visible in landscape',
      );
      // Scroll down slightly to catch overflow in the card content area.
      if (tester.any(find.byType(CustomScrollView))) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -200),
        );
        await AppFlow.pumpFrames(tester, count: 3);
        // Scroll back up.
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, 200),
        );
        await AppFlow.pumpFrames(tester, count: 3);
      }

      await _toP(tester, portrait);
      expect(
        find.byType(SliverAppBar),
        findsOneWidget,
        reason: 'Home SliverAppBar visible after returning to portrait',
      );

      // Return to Lectures before mini player and settings checks.
      await AppFlow.navigateToLecturesTab(tester);
      await AppFlow.openFirstLecture(tester);

      // ── 4. Mini player ────────────────────────────────────────────────────
      await AppFlow.dismissPlayer(tester);
      await AppFlow.expectMiniPlayerVisible(tester);

      await _toL(tester, landscape);
      await AppFlow.expectMiniPlayerVisible(tester);
      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'nav bar visible in landscape with mini player',
      );

      await _toP(tester, portrait);
      await AppFlow.expectMiniPlayerVisible(tester);

      // ── 5. Settings screen ────────────────────────────────────────────────
      await AppFlow.navigateToSettingsTab(tester);
      await AppFlow.pumpFrames(tester, count: 3);

      await _toL(tester, landscape);
      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'nav bar visible on settings in landscape',
      );

      // Settings list should still scroll without crashing.
      if (tester.any(find.byType(ListView))) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -200));
        await AppFlow.pumpFrames(tester, count: 3);
      }

      await _toP(tester, portrait);
      await AppFlow.navigateToLecturesTab(tester);
    },
    timeout: integrationTimeout,
  );
}
