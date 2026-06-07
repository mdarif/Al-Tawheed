import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../integration_test/support/app_flow.dart';

/// Helpers for Patrol tests — wraps [AppFlow] and native automator utilities.
class PatrolFlow {
  PatrolFlow._();

  /// Substring of the error Patrol's iOS automator returns when Control
  /// Center — and thus airplane-mode toggling — is unavailable. Real
  /// hardware has no real radios, but Apple doesn't expose Control Center's
  /// network toggles on the Simulator at all; real iOS devices and Android
  /// support the toggle normally.
  static const _controlCenterUnavailable =
      'Control Center is not available on Simulator';

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
    } on PatrolActionException catch (e) {
      if (e.message.contains(_controlCenterUnavailable)) {
        // Running on iOS Simulator — there's no Control Center to toggle
        // airplane mode with, so this scenario can't be exercised here.
        // It still runs on Android and on real iOS devices.
        return;
      }
      rethrow;
    }

    try {
      await AppFlow.pumpFrames($.tester, count: 10);
      await body();
    } finally {
      try {
        await $.platform.mobile.disableAirplaneMode();
      } on PatrolActionException catch (e) {
        if (!e.message.contains(_controlCenterUnavailable)) rethrow;
      }
      await AppFlow.pumpFrames($.tester, count: 10);
    }
  }
}

const patrolTimeout = Timeout(Duration(minutes: 10));
