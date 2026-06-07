import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
