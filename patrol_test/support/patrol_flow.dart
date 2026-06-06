import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../integration_test/support/app_flow.dart';

/// Helpers for Patrol tests — wraps [AppFlow] and native automator utilities.
class PatrolFlow {
  PatrolFlow._();

  static Future<void> grantNotificationsIfPrompted(PatrolIntegrationTester $) async {
    if (await $.platform.mobile.isPermissionDialogVisible(
      timeout: const Duration(seconds: 8),
    )) {
      await $.platform.mobile.grantPermissionWhenInUse();
      await AppFlow.pumpFrames($.tester, count: 5);
    }
  }

  static Future<void> bootstrapToLectures(PatrolIntegrationTester $) async {
    await AppFlow.launchApp($.tester);
    await grantNotificationsIfPrompted($);
    await AppFlow.goToLectureList($.tester);
  }

  static Future<void> withAirplaneMode(
    PatrolIntegrationTester $,
    Future<void> Function() body,
  ) async {
    try {
      await $.platform.mobile.enableAirplaneMode();
      await AppFlow.pumpFrames($.tester, count: 10);
      await body();
    } finally {
      await $.platform.mobile.disableAirplaneMode();
      await AppFlow.pumpFrames($.tester, count: 10);
    }
  }
}

const patrolTimeout = Timeout(Duration(minutes: 10));
