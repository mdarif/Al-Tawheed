import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
import 'package:myapp/testing/widget_keys.dart';
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
    'Arabic series: nav bar shows Arabic labels, Read tab with no Study '
    'toggle (Arabic has no study mode)',
    ($) async {
      if (!await PatrolFlow.bootstrapToArabicLectures($)) return;

      expect(find.text('الدروس'), findsOneWidget); // Lectures
      expect(find.text('القراءة'), findsOneWidget); // Read (Book+Study merge)
      expect(find.text('المكتبة'), findsOneWidget); // Library
      expect(find.text('الإعدادات'), findsOneWidget); // Settings
      // Home was retired; there is no separate Book tab or Study tab/toggle
      // for the Arabic edition (no hasStudyMode).
      expect(find.text('الرئيسية'), findsNothing);
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

      // ARB `nowPlaying` (ar) — the canonical wording.
      expect(find.text('يُشغَّل الآن'), findsOneWidget);

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
    'Arabic series: Read tab opens the chapter list',
    ($) async {
      if (!await PatrolFlow.bootstrapToArabicLectures($)) return;

      final navigated = await AppFlow.navigateToReadTab($.tester);
      expect(
        navigated,
        isTrue,
        reason: 'Read tab must exist for Arabic series',
      );

      // The chapter list is a CustomScrollView whose SliverList only exists
      // once the book has loaded (a spinner until then). The Arabic edition
      // has a Book and no Study, so Read shows it directly under the title,
      // with no Book/Study tab bar.
      await AppFlow.waitFor(
        $.tester,
        find.descendant(
          of: find.byType(BookChapterListBody),
          matching: find.byType(SliverList),
        ),
        timeout: const Duration(seconds: 30),
        reason: 'book chapter list',
      );
      expect(find.byKey(WidgetKeys.readTabStudy), findsNothing);
      expect(find.byKey(WidgetKeys.readTabBook), findsNothing);

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
        // The shell's offline banner shows the Arabic badge. The same word also
        // labels undownloaded lecture rows, so scope the check to the banner.
        expect(
          find.descendant(
            of: find.byKey(WidgetKeys.offlineStatusBanner),
            matching: find.text('بلا إنترنت'),
          ),
          findsOneWidget,
        );

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
