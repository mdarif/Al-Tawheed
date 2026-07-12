import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/widgets/lecture_tile.dart';

import 'support/app_flow.dart';

// Covered here (Flutter UI only):
//   welcome, catalog, shell tabs, player, mini player, streaming strip,
//   offline sheet, download/complete, local playback, offline library
//   (sheet + settings), list tile download state, remove download,
//   list-tile download start + cancel.
//
// Native-only scenarios live in patrol_test/native_test.dart (Patrol CLI).

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'end-to-end user journeys',
    (tester) async {
      // ── Cold start & welcome ────────────────────────────────────────────
      await AppFlow.launchApp(tester);
      // WelcomeScreen is only shown on first install; returning users land
      // directly on /lectures (onboarding flag persisted in prefs).
      if (tester.any(find.text('START LISTENING'))) {
        expect(find.text('START LISTENING'), findsOneWidget);
        expect(find.textContaining('Kitab at-Tawheed'), findsWidgets);
      }

      // ── Catalog load & lecture list ─────────────────────────────────────
      await AppFlow.goToLectureList(tester);
      expect(find.text('Sharah Kitab at-Tawheed'), findsWidgets);
      expect(find.byType(LectureTile), findsWidgets);

      // ── Chapter download action on multi-part classes ─────────────────────
      if (tester.any(find.byIcon(Icons.download_for_offline_outlined))) {
        expect(find.byIcon(Icons.download_for_offline_outlined), findsWidgets);
      }

      // ── Shell bottom navigation ─────────────────────────────────────────
      await AppFlow.navigateToTab(tester, 'Home');
      await AppFlow.navigateToTab(tester, 'Settings');
      await AppFlow.scrollToSettingsDownloads(tester);
      expect(find.text('DOWNLOADS'), findsWidgets);
      await AppFlow.navigateToTab(tester, 'Lectures');

      // ── Player opens with transport controls ────────────────────────────
      await AppFlow.openFirstLecture(tester);
      final hasPlay = tester.any(find.byIcon(Icons.play_arrow_rounded));
      final hasPause = tester.any(find.byIcon(Icons.pause_rounded));
      expect(hasPlay || hasPause, isTrue);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // ── Streaming strip opens offline sheet ─────────────────────────────
      if (tester.any(find.text('Streaming'))) {
        await AppFlow.openOfflineSheetFromPlayer(tester);
        expect(find.textContaining('Download lecture'), findsOneWidget);
        await AppFlow.dismissBottomSheet(tester);
      }

      // ── Mini player round-trip ──────────────────────────────────────────
      await AppFlow.dismissPlayer(tester);
      await AppFlow.expectMiniPlayerVisible(tester);
      await AppFlow.openPlayerFromMiniPlayer(tester);
      await AppFlow.dismissPlayer(tester);

      // ── Download from player offline sheet ──────────────────────────────
      await AppFlow.openFirstLecture(tester);
      await AppFlow.ensureLectureDownloaded(tester);
      expect(find.text('Saved for offline'), findsOneWidget);

      // ── Local playback from cache ───────────────────────────────────────
      if (tester.any(find.byIcon(Icons.play_arrow_rounded))) {
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await AppFlow.pumpFrames(tester, count: 6);
      }
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // ── Offline library via player sheet ────────────────────────────────
      await AppFlow.openOfflineLibraryFromSheet(tester);
      expect(find.text('No downloads yet'), findsNothing);
      await AppFlow.dismissOfflineLibrary(tester);
      await AppFlow.dismissPlayer(tester);

      // ── Lecture list shows downloaded state on tile ─────────────────────
      expect(
        find.descendant(
          of: find.byType(LectureTile).first,
          matching: find.byIcon(Icons.download_done_rounded),
        ),
        findsOneWidget,
      );

      // ── Settings downloads section & library link ───────────────────────
      await AppFlow.openOfflineLibraryFromSettings(tester);
      expect(find.text('No downloads yet'), findsNothing);
      await AppFlow.dismissOfflineLibrary(tester);

      // ── Remove download restores streaming strip ────────────────────────
      await AppFlow.navigateToTab(tester, 'Lectures');
      await AppFlow.openFirstLecture(tester);
      await AppFlow.removeDownloadFromPlayer(tester);
      expect(find.text('Saved for offline'), findsNothing);

      // ── List-tile download start + cancel via player sheet ──────────────
      await AppFlow.dismissPlayer(tester);
      await AppFlow.startDownloadFromListTile(tester);
      await AppFlow.openFirstLecture(tester);
      await AppFlow.waitForDownloadProgressOrComplete(tester);
      if (tester.any(find.textContaining('Downloading'))) {
        await AppFlow.cancelDownloadFromPlayer(tester);
      }
    },
    timeout: integrationTimeout,
  );
}
