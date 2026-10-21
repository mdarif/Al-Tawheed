import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/screens/study_class_complete_screen.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/widgets/lecture_tile.dart';
import 'package:myapp/widgets/study/class_progress_card.dart';
import 'package:provider/provider.dart';

import 'support/app_flow.dart';

// Covered here (Flutter UI only):
//   welcome, catalog, shell tabs (with scroll-state retention across the
//   real production router), player, mini player, streaming strip,
//   offline sheet, download/complete, local playback, offline library
//   (the player sheet's legacy route + the Settings hint, both landing on
//   Library > Downloads), list tile download state, remove download,
//   list-tile download start + cancel, and the 2.4.2 journeys:
//     * Library tabs: Downloads -> play -> Back, and bookmark from Player ->
//       Bookmarks -> play -> Back;
//     * Search/jump: "12" -> results -> play -> Back keeps the query, and the
//       idle class grid -> Class 15 -> Lectures scrolled to its header;
//     * Study complete -> "Back to Study Mode" lands on Read > Study.
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
      if (tester.any(find.byKey(WidgetKeys.welcomeStartListening))) {
        expect(find.byKey(WidgetKeys.welcomeStartListening), findsOneWidget);
        expect(find.textContaining('Kitab at-Tawheed'), findsWidgets);
      }

      // ── Catalog load & lecture list ─────────────────────────────────────
      await AppFlow.goToLectureList(tester);
      expect(find.text('Sharah Kitab at-Tawheed'), findsWidgets);
      expect(find.byType(LectureTile), findsWidgets);
      final firstLectureTitle = tester
          .widget<LectureTile>(find.byType(LectureTile).first)
          .lecture
          .title['en'] as String;

      // ── Chapter download action on multi-part classes ─────────────────────
      if (tester.any(find.byIcon(Icons.download_for_offline_outlined))) {
        expect(find.byIcon(Icons.download_for_offline_outlined), findsWidgets);
      }

      // ── Shell bottom navigation ─────────────────────────────────────────
      // Tabs are lectures · read · library · settings (Book/Study merged
      // into Read; Library is a stable destination for every edition since
      // A1) — the Home tab was retired (f793a78). Exercise Read (this
      // release's headline surface), Library, and Settings, then return to
      // Lectures.
      //
      // Scroll the Lectures list before switching away, so the round trip
      // also proves StatefulShellRoute.indexedStack retains branch state on
      // the real production router — shell_screen_test.dart proves the same
      // thing against a substitute router, not createAppRouter.
      final lecturesScrollable = find.byType(Scrollable).first;
      await tester.drag(lecturesScrollable, const Offset(0, -400));
      await AppFlow.pumpFrames(tester, count: 3);
      final scrollBefore =
          tester.state<ScrollableState>(lecturesScrollable).position.pixels;
      expect(scrollBefore, greaterThan(0));

      if (tester.any(find.byKey(WidgetKeys.shellReadTab))) {
        await AppFlow.navigateToTab(tester, AppTab.read);
      }
      await AppFlow.navigateToTab(tester, AppTab.library);
      expect(find.text('Library'), findsWidgets);
      await AppFlow.navigateToTab(tester, AppTab.settings);
      await AppFlow.scrollToSettingsDownloads(tester);
      expect(find.text('Downloads'), findsWidgets);
      await AppFlow.navigateToTab(tester, AppTab.lectures);
      final scrollAfter = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(scrollAfter, scrollBefore);

      // Scroll back to the top — later steps assume the first tile is
      // on-screen.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await AppFlow.pumpFrames(tester, count: 3);

      // ── Player opens with transport controls ────────────────────────────
      await AppFlow.openFirstLecture(tester);
      final hasPlay = tester.any(find.byIcon(Icons.play_arrow_rounded));
      final hasPause = tester.any(find.byIcon(Icons.pause_rounded));
      expect(hasPlay || hasPause, isTrue);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // ── Streaming strip opens offline sheet ─────────────────────────────
      if (tester.any(find.byKey(WidgetKeys.playerOfflineStatus))) {
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

      // ── Settings downloads hint → Library › Downloads ───────────────────
      // Settings keeps only the Wi-Fi switch; its hint links to Library.
      await AppFlow.openDownloadsFromSettingsHint(tester);
      expect(find.text('No downloads yet'), findsNothing);

      // ── Library: Downloads → play → Back ────────────────────────────────
      // The first lecture is on disk from the steps above. Tapping its row
      // plays it from the local file and pushes the Player; Back must return
      // to Library with the Downloads tab still selected.
      // (Downloads rows are their own ListTiles, not LectureTile.)
      final downloadedRow = find.widgetWithText(ListTile, firstLectureTitle);
      expect(downloadedRow, findsOneWidget);
      await tester.tap(downloadedRow);
      await AppFlow.waitForPlayerReady(tester);
      expect(find.text('Saved for offline'), findsOneWidget);
      await AppFlow.closePlayerTo(
        tester,
        find.byKey(WidgetKeys.libraryTabDownloads),
      );
      AppFlow.expectLibraryTab(tester, 1);
      expect(downloadedRow, findsOneWidget);

      // ── Library: bookmark from Player → Bookmarks → play → Back ─────────
      await AppFlow.navigateToTab(tester, AppTab.lectures);
      await AppFlow.openFirstLecture(tester);
      if (tester.any(find.byIcon(Icons.bookmark_rounded))) {
        // Left over from an earlier run: start from "not bookmarked".
        await tester.tap(find.byKey(WidgetKeys.playerBookmark));
        await AppFlow.pumpFrames(tester, count: 3);
      }
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
      await tester.tap(find.byKey(WidgetKeys.playerBookmark));
      await AppFlow.pumpFrames(tester, count: 3);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      await AppFlow.dismissPlayer(tester);

      await AppFlow.openLibraryTab(tester, 0);
      expect(find.byType(LectureTile), findsOneWidget);
      await tester.tap(find.byType(LectureTile).first);
      await AppFlow.waitForPlayerReady(tester);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      await AppFlow.closePlayerTo(
        tester,
        find.byKey(WidgetKeys.libraryTabBookmarks),
      );
      AppFlow.expectLibraryTab(tester, 0);
      expect(find.byType(LectureTile), findsOneWidget);

      // Remove the bookmark again so the row leaves no state behind.
      await tester.tap(find.byType(LectureTile).first);
      await AppFlow.waitForPlayerReady(tester);
      await tester.tap(find.byKey(WidgetKeys.playerBookmark));
      await AppFlow.pumpFrames(tester, count: 3);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
      await AppFlow.closePlayerTo(
        tester,
        find.byKey(WidgetKeys.libraryTabBookmarks),
      );
      expect(find.byType(LectureTile), findsNothing);

      // ── Remove download restores streaming strip ────────────────────────
      await AppFlow.navigateToTab(tester, AppTab.lectures);
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

      // ── Search: "12" → results → play → Back keeps the query ────────────
      // In the Urdu edition "12" is Class 12, its five parts, AND lecture 12
      // (Class 05 — Part 01): a bare number also matches the global lecture
      // number on the badge.
      await AppFlow.openSearch(tester);
      await AppFlow.typeSearchQuery(tester, '12');
      await AppFlow.waitFor(
        tester,
        find.byKey(WidgetKeys.searchResults),
        timeout: const Duration(seconds: 15),
        reason: 'search results for "12"',
      );
      expect(find.byKey(WidgetKeys.searchSectionClasses), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchSectionLectures), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchClassRow('class-12')), findsOneWidget);
      final lecture12 = find.byKey(WidgetKeys.searchLectureRow('lec-012'));
      expect(lecture12, findsOneWidget);
      await tester.ensureVisible(lecture12);
      await AppFlow.pumpFrames(tester, count: 2);
      await tester.tap(lecture12);
      await AppFlow.waitForPlayerReady(tester);
      await AppFlow.closePlayerTo(
        tester,
        find.byKey(WidgetKeys.searchResults),
      );
      expect(AppFlow.searchFieldText(tester), '12');
      expect(
        find.byKey(WidgetKeys.searchLectureRow('lec-012')),
        findsOneWidget,
      );

      // ── Search: idle class grid → Class 15 → Lectures scrolled there ────
      await tester.tap(find.byKey(WidgetKeys.searchClear));
      await AppFlow.pumpFrames(tester, count: 3);
      expect(find.byKey(WidgetKeys.searchIdle), findsOneWidget);
      expect(find.byKey(WidgetKeys.searchClassGrid), findsOneWidget);
      final class15 = find.byKey(WidgetKeys.searchClassCell('class-15'));
      await tester.ensureVisible(class15);
      await AppFlow.pumpFrames(tester, count: 2);
      await tester.tap(class15);
      await AppFlow.waitFor(
        tester,
        find.byKey(WidgetKeys.lecturesChapterHeader('class-15')),
        timeout: const Duration(seconds: 15),
        reason: 'Class 15 header after "Go to class"',
      );
      // The jump animates and then corrects its estimate a few times.
      await AppFlow.pumpFrames(tester, count: 12);
      final class15Header = find.byKey(
        WidgetKeys.lecturesChapterHeader('class-15'),
      );
      expect(find.byKey(WidgetKeys.searchField), findsNothing);
      expect(class15Header, findsOneWidget);
      final headerRect = tester.getRect(class15Header);
      final navTop = tester.getRect(find.byType(NavigationBar)).top;
      expect(headerRect.top, greaterThan(0));
      expect(headerRect.bottom, lessThanOrEqualTo(navTop));
      // It really scrolled: Class 01 is far off-screen.
      expect(
        find.byKey(WidgetKeys.lecturesChapterHeader('class-01')),
        findsNothing,
      );
      await AppFlow.scrollLecturesToTop(tester);

      // ── Study complete → "Back to Study Mode" → Read › Study ────────────
      // Narrowest legitimate path: start a REAL study session for Class 01 (a
      // short class: 2 parts) from Read > Study, then seek each part to within
      // seconds of its end so the real audio engine reports completion and the
      // Player's own completion listener routes to /study/complete. Only the
      // "listen to the whole class" wait is skipped.
      expect(await AppFlow.navigateToReadTab(tester), isTrue);
      await tester.tap(find.byKey(WidgetKeys.readTabStudy));
      await AppFlow.pumpFrames(tester, count: 5);
      expect(AppFlow.readTabIndex(tester), 1);
      // Class 01 (2 parts) rather than Class 15: with the mini-player up, the
      // last Study card sits under the mini-player and navigation bar (the
      // list's explicit 24 dp bottom padding overrides the Scaffold's
      // extendBody inset), so it cannot be tapped. The first card is clear.
      final class01Card = find.widgetWithText(ClassProgressCard, 'Class 01');
      expect(class01Card, findsOneWidget);
      await tester.tap(class01Card);
      await AppFlow.pumpFrames(tester, count: 3);
      final restartConfirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      if (tester.any(restartConfirm)) {
        // Class 01 was already completed by an earlier run: restart it.
        await tester.tap(restartConfirm);
        await AppFlow.pumpFrames(tester, count: 3);
      }
      await AppFlow.waitForPlayerReady(tester);
      final player = Provider.of<PlayerNotifier>(
        tester.element(find.byKey(WidgetKeys.playerClose)),
        listen: false,
      );
      final backToStudy = find.text('Back to Study Mode');
      final studyDeadline = DateTime.now().add(const Duration(minutes: 5));
      String? seekedLectureId;
      final completeScreen = find.byType(StudyClassCompleteScreen);
      while (!tester.any(completeScreen) &&
          DateTime.now().isBefore(studyDeadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        final current = player.current?.id;
        if (current != null &&
            current != seekedLectureId &&
            !player.isLoading &&
            player.isPlaying &&
            player.duration > const Duration(seconds: 30)) {
          seekedLectureId = current;
          await player.seek(player.duration - const Duration(seconds: 4));
        }
      }
      expect(
        completeScreen,
        findsOneWidget,
        reason: 'Study completion screen after finishing Class 01',
      );
      // The button is below the celebration card and progress summary.
      await tester.scrollUntilVisible(
        backToStudy,
        300,
        scrollable: find
            .descendant(of: completeScreen, matching: find.byType(Scrollable))
            .first,
      );
      await AppFlow.pumpFrames(tester, count: 2);
      await tester.tap(backToStudy);
      await AppFlow.waitFor(
        tester,
        find.byKey(WidgetKeys.readHeader),
        timeout: const Duration(seconds: 15),
        reason: 'Read after "Back to Study Mode"',
      );
      await AppFlow.pumpFrames(tester, count: 5);
      expect(find.byType(StudyClassCompleteScreen), findsNothing);
      expect(AppFlow.readTabIndex(tester), 1, reason: 'Read > Study selected');
      expect(find.byType(StudyBody), findsOneWidget);
    },
    timeout: integrationTimeout,
  );
}
