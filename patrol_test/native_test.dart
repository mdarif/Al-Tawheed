import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/widgets/lecture_tile.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/support/app_flow.dart';
import 'support/patrol_flow.dart';

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
        expect($('Offline'), findsOneWidget);
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
    'lock-screen next/previous controls advance the queue on Android',
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
  );

  patrolTest(
    'shows download progress in the notification shade on Android',
    ($) async {
      if (!Platform.isAndroid) return;

      await PatrolFlow.bootstrapToLectures($);
      await AppFlow.openFirstLecture($.tester);
      if ($.tester.any(find.text('Saved for offline'))) {
        await AppFlow.removeDownloadFromPlayer($.tester);
      }
      await AppFlow.dismissPlayer($.tester);

      await AppFlow.startDownloadFromListTile($.tester);
      await AppFlow.openFirstLecture($.tester);
      await AppFlow.waitForDownloadProgressOrComplete($.tester);

      if (!$.tester.any(find.textContaining('Downloading'))) {
        return;
      }

      await $.platform.mobile.openNotifications();
      await AppFlow.pumpFrames($.tester, count: 5);

      final notifications = await $.platform.mobile.getNotifications();
      expect(notifications, isNotEmpty);

      await $.platform.mobile.closeNotifications();
      await AppFlow.cancelDownloadFromPlayer($.tester);
      await AppFlow.dismissPlayer($.tester);
    },
    timeout: patrolTimeout,
  );
}
