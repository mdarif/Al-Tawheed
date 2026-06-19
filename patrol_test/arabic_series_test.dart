import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/lecture_tile.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/support/app_flow.dart';
import 'support/patrol_flow.dart';

// End-to-end scenarios for the Arabic duroos (الدروس) series.
//
// Each test bootstraps the app, switches to Arabic via the Settings series
// picker, runs its scenario, then restores Urdu so tests are independent of
// execution order. If the seriesSwitcher feature flag is disabled in this
// environment every test exits via early return.
//
//   patrol test -t patrol_test/arabic_series_test.dart

void main() {
  patrolTest(
    'Arabic series: nav bar shows Arabic labels with Book tab and no Study tab',
    ($) async {
      if (!await PatrolFlow.bootstrapToArabicLectures($)) return;

      expect(find.text('الدروس'), findsOneWidget);     // Lectures
      expect(find.text('الكتاب'), findsOneWidget);     // Book — Arabic-only
      expect(find.text('الرئيسية'), findsOneWidget);   // Home
      expect(find.text('الإعدادات'), findsOneWidget);  // Settings
      // Study tab must be absent — Arabic series has no study mode
      expect(find.text('Study'), findsNothing);

      await PatrolFlow.restoreToUrduSeries($);
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'Arabic series: lecture list loads and lecture tiles are visible',
    ($) async {
      if (!await PatrolFlow.bootstrapToArabicLectures($)) return;

      await AppFlow.waitFor(
        $.tester,
        find.byType(LectureTile),
        timeout: const Duration(seconds: 30),
        reason: 'Arabic lecture list',
      );
      expect(find.byType(LectureTile), findsWidgets);

      await PatrolFlow.restoreToUrduSeries($);
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'Arabic series: player chrome shows Arabic "Now Playing" header and streaming label',
    ($) async {
      if (!await PatrolFlow.bootstrapToArabicLectures($)) return;

      await AppFlow.openFirstLecture($.tester);

      expect(find.text('يتم التشغيل الآن'), findsOneWidget);

      // Online path: streaming strip uses Arabic label
      if ($.tester.any(find.text('بث مباشر'))) {
        expect(find.text('بث مباشر'), findsOneWidget);
      }

      // Bookmark tooltip is in Arabic
      expect(
        find.byTooltip('إضافة إشارة مرجعية'),
        findsOneWidget,
      );

      await AppFlow.dismissPlayer($.tester);
      await PatrolFlow.restoreToUrduSeries($);
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'Arabic series: Book tab opens the chapter list',
    ($) async {
      if (!await PatrolFlow.bootstrapToArabicLectures($)) return;

      final navigated = await AppFlow.navigateToBookTab($.tester);
      expect(navigated, isTrue, reason: 'Book tab must exist for Arabic series');

      // Chapter list loads — wait for either the list or a loading spinner
      await AppFlow.waitFor(
        $.tester,
        find.byType(ListView),
        timeout: const Duration(seconds: 30),
        reason: 'book chapter list',
      );
      expect(find.byType(ListView), findsWidgets);

      await AppFlow.navigateToLecturesTab($.tester);
      await PatrolFlow.restoreToUrduSeries($);
    },
    timeout: patrolTimeout,
  );

  patrolTest(
    'Arabic series: offline banner and blocked-lecture snackbar show in Arabic',
    ($) async {
      if (!await PatrolFlow.bootstrapToArabicLectures($)) return;

      await PatrolFlow.withAirplaneMode($, () async {
        // Offline status banner shows Arabic badge
        expect($('بلا إنترنت'), findsOneWidget);

        // Tapping an undownloaded lecture shows the Arabic snackbar
        final tiles = find.byType(LectureTile);
        expect(tiles, findsWidgets);

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
        expect($('نزّل هذا الدرس للاستماع بلا إنترنت.'), findsOneWidget);
      });

      await PatrolFlow.restoreToUrduSeries($);
    },
    timeout: patrolTimeout,
  );
}
