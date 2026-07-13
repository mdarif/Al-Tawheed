import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/announcement_model.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/announcements_bell.dart';

const _announcement = Announcement(
  id: 'a1',
  type: 'info',
  title: {'en': 'Test Announcement'},
  body: {'en': 'Announcement body text'},
  platforms: ['android', 'ios'],
);

Widget _wrap({
  AnnouncementsProvider? announcements,
  FeatureFlagsProvider? featureFlags,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(
          value: announcements ?? AnnouncementsProvider(),),
      ChangeNotifierProvider.value(
          value: featureFlags ?? FeatureFlagsProvider(),),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(actions: const [AnnouncementsBell()]),
        body: const SizedBox(),
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
  });

  testWidgets('no bell — no space taken — when there are no announcements',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });

  testWidgets('no bell when the announcements feature flag is off',
      (tester) async {
    final announcements = AnnouncementsProvider()
      ..setAnnouncementsForTest(const [_announcement]);

    await tester.pumpWidget(_wrap(
      announcements: announcements,
      featureFlags: FeatureFlagsProvider()
        ..setFeaturesJsonForTest({'announcements': false}),
    ),);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });

  testWidgets('bell with a badge appears when there is an announcement',
      (tester) async {
    final announcements = AnnouncementsProvider()
      ..setAnnouncementsForTest(const [_announcement]);

    await tester.pumpWidget(_wrap(announcements: announcements));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('tapping opens a sheet of cards; dismissing clears the bell',
      (tester) async {
    final announcements = AnnouncementsProvider()
      ..setAnnouncementsForTest(const [_announcement]);

    await tester.pumpWidget(_wrap(announcements: announcements));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Test Announcement'), findsOneWidget);
    expect(find.text('Announcement body text'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Sheet auto-closes once the last one is dismissed, and the bell clears.
    expect(find.text('Test Announcement'), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });
}
