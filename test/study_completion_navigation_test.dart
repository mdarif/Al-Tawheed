import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/screens/study_class_complete_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Covers the "Class N Completed" -> "Next Up" regression: finishing a
// chapter (even by jumping straight to its last part) must mark that
// chapter studied *before* the completion screen is shown, so "Next Up"
// recommends the following chapter rather than the one just finished.

Catalog _testCatalog() {
  const json = '''
{
  "version": 1,
  "book": {
    "id": "book",
    "title": "Test",
    "titleArabic": "",
    "speaker": "Speaker",
    "totalDurationSeconds": 1200,
    "lectureCount": 2,
    "coverImageUrl": "",
    "language": "Urdu"
  },
  "chapters": [
    {"id": "class-01", "number": 1, "title": "Class 01", "lectureCount": 1},
    {"id": "class-02", "number": 2, "title": "Class 02", "lectureCount": 1}
  ],
  "lectures": [
    {"id": "lec-01", "number": 1, "chapterId": "class-01", "title": "P1", "audioUrl": "", "durationSeconds": 600, "fileSizeBytes": 1},
    {"id": "lec-02", "number": 1, "chapterId": "class-02", "title": "P1", "audioUrl": "", "durationSeconds": 600, "fileSizeBytes": 1}
  ],
  "dailyBenefits": []
}
''';
  return Catalog.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
  });

  testWidgets(
      'finishing a study chapter marks it studied and recommends the next '
      'one on the completion screen', (tester) async {
    // Tall surface so the completion screen's "Next Up" card renders
    // within the ListView's build/cache extent.
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalog = _testCatalog();
    final progress = ProgressProvider()..load();
    final catalogProvider = CatalogProvider()..setCatalogForTest(catalog);
    final study = StudyProgressProvider(progress, catalogProvider)..load();
    final player = PlayerNotifier(
      TawheedAudioHandler(),
      progress,
      DownloadsProvider(),
      ConnectivityProvider.testOffline(),
    );
    addTearDown(player.dispose);

    final chapter1 = catalog.chapterById('class-01');
    await player.startStudySession(
      lecture: catalog.lecturesForChapter('class-01').first,
      queue: catalog.lecturesForChapter('class-01'),
      chapter: chapter1,
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: progress),
        ChangeNotifierProvider.value(value: catalogProvider),
        ChangeNotifierProvider.value(value: study),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider.testOffline()),
        ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('Home'))),
            ),
            GoRoute(
              path: '/player',
              pageBuilder: (context, state) => const MaterialPage(
                fullscreenDialog: true,
                child: PlayerScreen(),
              ),
            ),
            GoRoute(
              path: '/study/complete',
              builder: (context, state) => StudyClassCompleteScreen(
                chapterId: state.uri.queryParameters['chapterId']!,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.text('Home'))).push('/player');
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);

    // The last lecture in the study queue just finished.
    player.setPendingStudyCompleteForTest('class-01');
    await tester.pumpAndSettle();

    // Navigated to the completion screen for class-01.
    expect(find.byType(StudyClassCompleteScreen), findsOneWidget);
    expect(find.text('Class 01 Completed'), findsOneWidget);

    // class-01 is now sticky-studied, so "Next Up" advances to class-02.
    expect(study.isChapterStudied('class-01'), isTrue);
    expect(study.recommendedChapter?.id, 'class-02');
    expect(find.text('Next Up'), findsOneWidget);
    expect(find.text('Class 02'), findsOneWidget);
    expect(find.text('Continue to Class 02'), findsOneWidget);

    // The just-completed chapter is no longer recommended to itself.
    expect(find.text('Class 01'), findsNothing);
  });
}
