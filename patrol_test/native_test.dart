import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/widgets/lecture_tile.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart' show ReadContext;

import '../integration_test/support/app_flow.dart';
import 'support/patrol_flow.dart';
import 'support/slow_audio_downloads.dart';

// Native scenarios that integration_test cannot cover (OS dialogs, airplane mode,
// notification shade). Requires Patrol CLI + device/emulator.
//
//   flutter pub global activate patrol_cli
//   patrol test -t patrol_test/native_test.dart
//
// Per-test timeout is set in code via `timeout: patrolTimeout` (see
// support/patrol_flow.dart) — `patrol test` has no --timeout CLI flag.

void main() {
  patrolTest(
    'shows offline banner when airplane mode is enabled',
    ($) async {
      await PatrolFlow.bootstrapToLectures($);
      await PatrolFlow.withAirplaneMode($, () async {
        expect(find.byKey(WidgetKeys.offlineStatusBanner), findsOneWidget);

        // The banner's link goes to Library › Downloads (the one home for
        // downloads — Settings only hints at it), which works offline.
        await $.tester.tap(find.byKey(WidgetKeys.offlineStatusBanner));
        await AppFlow.waitFor(
          $.tester,
          find.byKey(WidgetKeys.libraryTabDownloads),
          timeout: const Duration(seconds: 15),
          reason: 'Library after tapping the offline banner',
        );
        AppFlow.expectLibraryTab($.tester, 1);
      });
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'shows snackbar when tapping undownloaded lecture offline',
    ($) async {
      await PatrolFlow.bootstrapToLectures($);
      await PatrolFlow.withAirplaneMode($, () async {
        final tiles = find.byType(LectureTile);
        expect(tiles, findsWidgets);

        // Prefer a tile without a completed download icon.
        Finder target = tiles.first;
        if (tiles.evaluate().length > 1 &&
            find
                .descendant(
                  of: tiles.first,
                  matching: find.byIcon(Icons.download_done_rounded),
                )
                .evaluate()
                .isNotEmpty) {
          target = tiles.at(1);
        }

        await $.tester.tap(target);
        await AppFlow.pumpFrames($.tester, count: 8);
        expect(
          $('Download this lecture to listen offline.'),
          findsOneWidget,
        );
      });
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'blocks skip-next offline with dialog when next part is not downloaded',
    ($) async {
      await PatrolFlow.bootstrapToLectures($);
      await AppFlow.openFirstLecture($.tester);

      await PatrolFlow.withAirplaneMode($, () async {
        final skipNext = find.byIcon(Icons.skip_next_rounded);
        if (!$.tester.any(skipNext)) {
          // Last lecture in catalog — skip this scenario.
          return;
        }
        await $.tester.tap(skipNext);
        await AppFlow.pumpFrames($.tester, count: 8);
        expect($('Not available offline'), findsOneWidget);
        await $.tester.tap(find.text('Cancel'));
        await AppFlow.pumpFrames($.tester, count: 3);
      });

      await AppFlow.dismissPlayer($.tester);
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'lock-screen pause keeps playback paused on Android',
    ($) async {
      if (!Platform.isAndroid) return;

      await PatrolFlow.bootstrapToLectures($);
      await AppFlow.openFirstLecture($.tester);

      final pauseIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.pause_rounded,
      );
      final playIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.play_arrow_rounded,
      );
      await AppFlow.waitFor(
        $.tester,
        pauseIcon,
        timeout: const Duration(seconds: 30),
        reason: 'lecture to start playing',
      );

      // Tap "Pause" on the media notification — the same path a lock-screen
      // control uses (MediaSession -> AudioHandler.pause).
      await $.platform.mobile.openNotifications();
      await AppFlow.pumpFrames($.tester, count: 3);
      await $.platform.mobile.tapOnNotificationBySelector(
        Selector(contentDescription: 'Pause'),
        timeout: const Duration(seconds: 10),
      );
      await $.platform.mobile.closeNotifications();

      // It must stay paused — not bounce back to playing a moment later
      // (regression: just_audio's interruption handling could auto-resume
      // a deliberate pause).
      await AppFlow.waitFor(
        $.tester,
        playIcon,
        timeout: const Duration(seconds: 10),
        reason: 'player to show paused state',
      );
      await AppFlow.pumpFrames($.tester, count: 15);
      expect(playIcon, findsOneWidget);
      expect(pauseIcon, findsNothing);

      await AppFlow.dismissPlayer($.tester);
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'lock-screen next and previous controls advance the queue on Android',
    ($) async {
      if (!Platform.isAndroid) return;

      await PatrolFlow.bootstrapToLectures($);

      final tiles = find.byType(LectureTile);
      await AppFlow.waitFor(
        $.tester,
        tiles,
        timeout: const Duration(seconds: 15),
        reason: 'lecture list before reading titles',
      );
      if (tiles.evaluate().length < 2) {
        // Catalog has only one lecture — nothing to skip to.
        return;
      }

      final firstTitle =
          $.tester.widget<LectureTile>(tiles.at(0)).lecture.title.en;
      final secondTitle =
          $.tester.widget<LectureTile>(tiles.at(1)).lecture.title.en;

      await AppFlow.openFirstLecture($.tester);

      final nextButton = find.ancestor(
        of: find.byIcon(Icons.skip_next_rounded),
        matching: find.byType(IconButton),
      );
      if ($.tester.widget<IconButton>(nextButton).onPressed == null) {
        // First lecture in its queue has no next track — nothing to skip to.
        await AppFlow.dismissPlayer($.tester);
        return;
      }

      await AppFlow.waitFor(
        $.tester,
        find.text(firstTitle),
        timeout: const Duration(seconds: 15),
        reason: 'first lecture title on player screen',
      );

      // Tap "Next" on the media notification — the same path a lock-screen
      // control uses (MediaSession -> AudioHandler.skipToNext ->
      // PlayerNotifier.playNext). Regression: BaseAudioHandler's default
      // skipToNext/skipToPrevious are no-ops, so without the fix this tap
      // would do nothing and the title below would never change.
      await $.platform.mobile.openNotifications();
      await AppFlow.pumpFrames($.tester, count: 3);
      await $.platform.mobile.tapOnNotificationBySelector(
        Selector(contentDescription: 'Next'),
        timeout: const Duration(seconds: 10),
      );
      await $.platform.mobile.closeNotifications();

      await AppFlow.waitFor(
        $.tester,
        find.text(secondTitle),
        timeout: const Duration(seconds: 30),
        reason: 'queue to advance to the next lecture after lock-screen Next',
      );
      expect(find.text(firstTitle), findsNothing);

      // Now "Previous" should bring the queue back to the first lecture.
      await $.platform.mobile.openNotifications();
      await AppFlow.pumpFrames($.tester, count: 3);
      await $.platform.mobile.tapOnNotificationBySelector(
        Selector(contentDescription: 'Previous'),
        timeout: const Duration(seconds: 10),
      );
      await $.platform.mobile.closeNotifications();

      await AppFlow.waitFor(
        $.tester,
        find.text(firstTitle),
        timeout: const Duration(seconds: 30),
        reason:
            'queue to return to the previous lecture after lock-screen Previous',
      );
      expect(find.text(secondTitle), findsNothing);

      await AppFlow.dismissPlayer($.tester);
    },
    timeout: patrolTimeout,
    // TODO: On Android 13+ (hit on API 36), the system renders the media
    // notification's transport-control slots with its own accessibility
    // labels, not the app's MediaControl labels ("Next"/"Previous") — so
    // tapOnNotificationBySelector(contentDescription: 'Next'/'Previous')
    // finds nothing (404). Re-enable once the selector is updated to match
    // the actual system label (e.g. contentDescriptionContains).
    skip: true,
  );

  patrolTest(
    'shows download progress in the notification shade on Android',
    ($) async {
      if (!Platform.isAndroid) return;

      await PatrolFlow.bootstrapToLectures($);
      final tiles = find.byType(LectureTile);
      await AppFlow.waitFor(
        $.tester,
        tiles,
        timeout: const Duration(seconds: 15),
        reason: 'lecture list before reading notification title',
      );
      // DownloadsProvider posts the lecture title resolved for the current
      // chrome language + edition — `LanguageProvider.resolveForSeries`, the
      // same call LectureTile renders its title with — so derive the expected
      // shade title the same way rather than assuming English.
      final tileContext = $.tester.element(tiles.first);
      final lectureTitle =
          tileContext.read<LanguageProvider>().resolveForSeries(
                $.tester.widget<LectureTile>(tiles.first).lecture.title,
                tileContext.read<SeriesProvider>().currentSeries,
              );

      // Work from the list tile only: opening the player would start playback
      // and post a second (media) notification, and Android 14 then folds both
      // into one collapsed group whose header shows the media title, hiding the
      // download row from the shade.
      final firstTile = tiles.first;
      final alreadySaved = find.descendant(
        of: firstTile,
        matching: find.byIcon(Icons.download_done_rounded),
      );
      if ($.tester.any(alreadySaved)) {
        await $.tester.tap(alreadySaved);
        await AppFlow.pumpFrames($.tester, count: 3);
        await $.tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await AppFlow.pumpFrames($.tester, count: 5);
      }

      final startDownload = find.descendant(
        of: firstTile,
        matching: find.byTooltip('Download for offline'),
      );
      final cancelDownload = find.descendant(
        of: firstTile,
        matching: find.byTooltip('Cancel download'),
      );

      // A lecture is ~8 MB: left alone it finishes before the shade is open and
      // there is nothing in progress to observe. Throttle it so the test always
      // sees the download mid-flight, and fails if it does not.
      await withSlowAudioDownloads(() async {
        var shadeOpened = false;
        try {
          await $.tester.tap(startDownload);
          await AppFlow.pumpFrames($.tester, count: 3);

          // The first download action asks for notification permission
          // contextually: an in-app rationale, then the system dialog. Without
          // the grant the OS silently drops every notification the app posts,
          // so the shade never shows one.
          await AppFlow.dismissNotificationRationaleIfShown($.tester);
          await PatrolFlow.grantNotificationsIfPrompted($);

          await AppFlow.waitFor(
            $.tester,
            cancelDownload,
            timeout: const Duration(seconds: 20),
            reason: 'tile to show the download in progress',
          );

          await $.platform.mobile.openNotifications();
          shadeOpened = true;
          // Title row of the download notification (android:id/title) ...
          await $.platform.mobile.waitUntilVisible(
            Selector(text: lectureTitle),
            timeout: const Duration(seconds: 15),
          );
          // ... and its progress bar, which only the in-progress notification
          // has (the completed one swaps it for "Download complete").
          await $.platform.mobile.waitUntilVisible(
            Selector(resourceId: 'android:id/progress'),
            timeout: const Duration(seconds: 15),
          );
        } finally {
          if (shadeOpened) {
            await $.platform.mobile.closeNotifications();
          }
          if ($.tester.any(cancelDownload)) {
            await $.tester.tap(cancelDownload);
            await AppFlow.pumpFrames($.tester, count: 5);
          }
        }
      });
    },
    timeout: patrolTimeout,
  );
}
