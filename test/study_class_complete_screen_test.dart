import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/screens/study_class_complete_screen.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Catalog _testCatalog() {
  const json = '''
{
  "version": 1,
  "book": {
    "id": "book",
    "title": "Test",
    "titleArabic": "",
    "speaker": "Speaker",
    "totalDurationSeconds": 600,
    "lectureCount": 6,
    "coverImageUrl": "",
    "language": "Urdu"
  },
  "chapters": [
    {"id": "class-01", "number": 1, "title": "Class 01", "lectureCount": 1},
    {"id": "class-02", "number": 2, "title": "Class 02", "lectureCount": 1},
    {"id": "class-03", "number": 3, "title": "Class 03", "lectureCount": 1},
    {"id": "class-04", "number": 4, "title": "Class 04", "lectureCount": 3},
    {"id": "class-05", "number": 5, "title": "Class 05", "lectureCount": 1}
  ],
  "lectures": [
    {"id": "lec-01", "number": 1, "chapterId": "class-01", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-02", "number": 1, "chapterId": "class-02", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-03", "number": 1, "chapterId": "class-03", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-04-1", "number": 1, "chapterId": "class-04", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-04-2", "number": 2, "chapterId": "class-04", "title": "P2", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-04-3", "number": 3, "chapterId": "class-04", "title": "P3", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-05", "number": 1, "chapterId": "class-05", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1}
  ],
  "dailyBenefits": []
}
''';
  return Catalog.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  late ProgressProvider progress;
  late CatalogProvider catalogProvider;
  late StudyProgressProvider study;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();

    catalog = _testCatalog();
    progress = ProgressProvider()..load();
    catalogProvider = CatalogProvider();
    catalogProvider.setCatalogForTest(catalog);
    study = StudyProgressProvider(progress, catalogProvider)..load();
  });

  Widget wrap(String chapterId) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalogProvider),
        ChangeNotifierProvider.value(value: progress),
        ChangeNotifierProvider.value(value: study),
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
                  StudyClassCompleteScreen(chapterId: chapterId),
            ),
            GoRoute(
              path: '/study',
              builder: (_, __) => const Scaffold(
                body: Center(child: Text('Study Hub')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  group('StudyClassCompleteScreen', () {
    testWidgets(
        'recommends the chapter after the one just marked studied, '
        'and reflects the incremented progress', (tester) async {
      // Tall surface so the "Next Up" card renders within the
      // ListView's build/cache extent alongside the celebration card.
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // class-01..03 were already studied in earlier sessions.
      await study.markChapterStudied('class-01');
      await study.markChapterStudied('class-02');
      await study.markChapterStudied('class-03');

      // Simulates jumping straight to the last part of class-04 and
      // finishing it without playing parts 1-2 — only the queue position
      // (not every part's progress) crossed the live-complete threshold.
      await progress.saveProgress('lec-04-3', 100);
      expect(
        StudyProgress.isChapterLiveComplete(progress, catalog, 'class-04'),
        isFalse,
      );

      // This is what _StudyCompletionListener now does before navigating to
      // /study/complete?chapterId=class-04.
      await study.markChapterStudied('class-04');

      await tester.pumpWidget(wrap('class-04'));
      await tester.pumpAndSettle();

      // Celebration card reflects the chapter that was just finished.
      expect(find.text('Class 04 Completed'), findsOneWidget);

      // Studied count and overall progress include class-04.
      expect(find.text('4 of 5 classes studied'), findsOneWidget);
      expect(find.text('80%'), findsNWidgets(2));

      // "Next Up" recommends class-05, not the just-completed class-04.
      expect(find.text('Next Up'), findsOneWidget);
      expect(find.text('Class 05'), findsOneWidget);
      expect(find.text('RECOMMENDED NEXT'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('1 part'), findsOneWidget);
      expect(find.text('Continue to Class 05'), findsOneWidget);

      // Old buggy state — class-04 recommending itself as "in progress" —
      // must not be present.
      expect(find.text('Class 04'), findsNothing);
      expect(find.text('In progress'), findsNothing);
      expect(find.text('1 of 3 parts complete'), findsNothing);

      expect(find.text('Back to Study Mode'), findsOneWidget);
    });

    testWidgets('shows a single "Back to Study Mode" button once every class is studied',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final chapter in catalog.chapters) {
        await study.markChapterStudied(chapter.id);
      }

      await tester.pumpWidget(wrap('class-05'));
      await tester.pumpAndSettle();

      // Series-complete variant: richer headline and message, no "Next Up".
      expect(find.text('Series Completed!'), findsOneWidget);
      expect(
          find.text('You have studied every class in the series.'
              ' May Allah make it a source of lasting benefit for you.'),
          findsOneWidget);
      expect(find.text('5 of 5 classes studied'), findsOneWidget);
      expect(find.text('100%'), findsNWidgets(2));
      expect(find.text('You have completed the full series.'), findsOneWidget);

      expect(find.text('Next Up'), findsNothing);
      expect(find.text('Continue to Class 05'), findsNothing);
      expect(find.text('Back to Study Mode'), findsOneWidget);
    });
  });
}
