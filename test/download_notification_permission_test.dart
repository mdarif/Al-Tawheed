import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/utils/download_notification_permission.dart'
    as permission_flow;

Widget _wrap(WidgetTester tester, Future<void> Function(BuildContext) run) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => run(context),
          child: const Text('trigger'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    permission_flow.isAndroidForTest = null;
  });

  tearDown(() {
    permission_flow.isAndroidForTest = null;
  });

  testWidgets('is a no-op off Android — no dialog, flag not set',
      (tester) async {
    permission_flow.isAndroidForTest = false;

    await tester.pumpWidget(
      _wrap(
        tester,
        permission_flow.maybeRequestDownloadNotificationPermission,
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      PreferencesService.instance.hasAskedDownloadNotificationPermission,
      isFalse,
    );
  });

  testWidgets(
      'shows the rationale on the first Android download action and marks '
      'it asked regardless of the answer', (tester) async {
    permission_flow.isAndroidForTest = true;

    await tester.pumpWidget(
      _wrap(
        tester,
        permission_flow.maybeRequestDownloadNotificationPermission,
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Get notified about your downloads?'), findsOneWidget);
    expect(
      find.text(
        "We'll let you know when a download finishes or fails — you can "
        'turn this off anytime in your device settings.',
      ),
      findsOneWidget,
    );

    // Decline — the rationale must still count as "asked" so it never
    // reappears on a later download.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      PreferencesService.instance.hasAskedDownloadNotificationPermission,
      isTrue,
    );
  });

  testWidgets('does not show the rationale again after the first time',
      (tester) async {
    permission_flow.isAndroidForTest = true;
    await PreferencesService.instance
        .saveHasAskedDownloadNotificationPermission();

    await tester.pumpWidget(
      _wrap(
        tester,
        permission_flow.maybeRequestDownloadNotificationPermission,
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('tapping Allow proceeds past the rationale without throwing',
      (tester) async {
    permission_flow.isAndroidForTest = true;

    await tester.pumpWidget(
      _wrap(
        tester,
        permission_flow.maybeRequestDownloadNotificationPermission,
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      PreferencesService.instance.hasAskedDownloadNotificationPermission,
      isTrue,
    );
  });
}
