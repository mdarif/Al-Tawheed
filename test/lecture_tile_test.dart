import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/lecture_tile.dart';

Lecture _lec() => const Lecture(
      id: 'lec-003',
      number: 3,
      chapterId: 'class-01',
      title: {'en': 'Class 01 — Part 03'},
      audioUrl: 'https://pub.example.r2.dev/lec-003.mp3',
      durationSeconds: 600,
      fileSizeBytes: 1000,
    );

// Downloads off keeps the trailing area simple (no DownloadButton), so these
// tests only need to wire the providers the share path touches. The row share
// is gated by shareLectureRow (not shareButton — that's player + app share).
FeatureFlagsProvider _flags({required bool share}) => FeatureFlagsProvider()
  ..setFeaturesJsonForTest({'downloads': false, 'shareLectureRow': share});

Widget _wrap(FeatureFlagsProvider flags) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: flags),
      ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
      ChangeNotifierProvider(create: (_) => SeriesProvider()..load(false)),
      ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ChangeNotifierProvider(create: (_) => AppConfigProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: LectureTile(lecture: _lec())),
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

  testWidgets('a lecture row offers a share button when the flag is on',
      (tester) async {
    await tester.pumpWidget(_wrap(_flags(share: true)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share lecture'), findsOneWidget);
  });

  testWidgets('no share button when the shareButton flag is off',
      (tester) async {
    await tester.pumpWidget(_wrap(_flags(share: false)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share lecture'), findsNothing);
  });

  testWidgets('tapping share sends the title + a link to the lecture web page',
      (tester) async {
    final sharePlatform = _FakeSharePlatform();
    SharePlatform.instance = sharePlatform;

    await tester.pumpWidget(_wrap(_flags(share: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share lecture'));
    await tester.pumpAndSettle();

    expect(
      sharePlatform.lastParams?.text,
      'Class 01 — Part 03\n\n'
          'https://kitabattawheed.com/lectures/class-01/part-03/',
    );
  });
}

class _FakeSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return ShareResult('', ShareResultStatus.success);
  }
}
