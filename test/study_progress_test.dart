import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';
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
    "lectureCount": 5,
    "coverImageUrl": "",
    "language": "Urdu"
  },
  "chapters": [
    {"id": "class-01", "number": 1, "title": "Class 01", "lectureCount": 2},
    {"id": "class-02", "number": 2, "title": "Class 02", "lectureCount": 2},
    {"id": "class-03", "number": 3, "title": "Class 03", "lectureCount": 1}
  ],
  "lectures": [
    {"id": "lec-001", "number": 1, "chapterId": "class-01", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-002", "number": 2, "chapterId": "class-01", "title": "P2", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-003", "number": 3, "chapterId": "class-02", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-004", "number": 4, "chapterId": "class-02", "title": "P2", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1},
    {"id": "lec-005", "number": 5, "chapterId": "class-03", "title": "P1", "audioUrl": "", "durationSeconds": 100, "fileSizeBytes": 1}
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.instance.resetForTest();
    await PreferencesService.instance.init();
    catalog = _testCatalog();
    progress = ProgressProvider()..load();
  });

  group('StudyProgress', () {
    test('part complete at 99% threshold', () async {
      await progress.saveProgress('lec-001', 98);
      expect(
        StudyProgress.isPartComplete(progress, catalog.lectures.first),
        isFalse,
      );

      await progress.saveProgress('lec-001', 99);
      expect(
        StudyProgress.isPartComplete(progress, catalog.lectures.first),
        isTrue,
      );
    });

    test('chapter live complete requires every part', () async {
      await progress.saveProgress('lec-001', 100);
      expect(
        StudyProgress.isChapterLiveComplete(progress, catalog, 'class-01'),
        isFalse,
      );

      await progress.saveProgress('lec-002', 100);
      expect(
        StudyProgress.isChapterLiveComplete(progress, catalog, 'class-01'),
        isTrue,
      );
    });

    test('recommended chapter skips sticky studied IDs', () {
      final recommended = StudyProgress.recommendedChapter(
        catalog,
        {'class-01'},
      );
      expect(recommended?.id, 'class-02');
    });

    test('session start returns first incomplete part', () async {
      await progress.saveProgress('lec-001', 100);

      final lecture = StudyProgress.sessionStartLecture(
        catalog,
        const {},
        progress,
        'class-01',
      );
      expect(lecture?.id, 'lec-002');
    });

    test('session start with restartStudied returns first part', () async {
      await progress.saveProgress('lec-001', 100);
      await progress.saveProgress('lec-002', 100);

      final lecture = StudyProgress.sessionStartLecture(
        catalog,
        {'class-01'},
        progress,
        'class-01',
        restartStudied: true,
      );
      expect(lecture?.id, 'lec-001');
    });

    test('chapter status uses sticky studied over live progress', () async {
      await progress.saveProgress('lec-001', 10);

      final status = StudyProgress.statusFor(
        'class-01',
        {'class-01'},
        progress,
        catalog,
      );
      expect(status, ChapterStudyStatus.studied);
    });
  });

  group('StudyProgressProvider', () {
    late CatalogProvider catalogProvider;
    late StudyProgressProvider study;

    setUp(() {
      catalogProvider = CatalogProvider();
      catalogProvider.setCatalogForTest(catalog);
      study = StudyProgressProvider(progress, catalogProvider)..load();
    });

    test('syncStudiedChapters persists sticky studied count', () async {
      expect(study.studiedCount, 0);

      await progress.saveProgress('lec-001', 100);
      await progress.saveProgress('lec-002', 100);
      await study.syncStudiedChapters();

      expect(study.studiedCount, 1);
      expect(study.isChapterStudied('class-01'), isTrue);
      expect(
        PreferencesService.instance.loadStudiedChapterIds(),
        {'class-01'},
      );
    });

    test('re-study does not reduce studied count', () async {
      await progress.saveProgress('lec-001', 100);
      await progress.saveProgress('lec-002', 100);
      await study.syncStudiedChapters();
      expect(study.studiedCount, 1);

      await progress.saveProgress('lec-001', 0);
      await study.syncStudiedChapters();

      expect(study.studiedCount, 1);
      expect(study.chapterStatus('class-01'), ChapterStudyStatus.studied);
    });

    test('chapterInfos marks recommended next incomplete class', () async {
      await progress.saveProgress('lec-001', 100);
      await progress.saveProgress('lec-002', 100);
      await study.syncStudiedChapters();

      final infos = study.chapterInfos();
      expect(infos[0].status, ChapterStudyStatus.studied);
      expect(infos[1].isRecommended, isTrue);
      expect(infos[1].chapter.id, 'class-02');
    });

    test('markChapterStudied marks the chapter studied even if parts are incomplete',
        () async {
      // Simulates jumping to the last part of a chapter and finishing it
      // without playing the earlier parts — only lec-004 (class-02's last
      // part) is complete, lec-003 never played.
      await progress.saveProgress('lec-004', 100);
      expect(
        StudyProgress.isChapterLiveComplete(progress, catalog, 'class-02'),
        isFalse,
      );

      await study.markChapterStudied('class-02');

      expect(study.isChapterStudied('class-02'), isTrue);
      expect(study.studiedCount, 1);
      expect(study.chapterStatus('class-02'), ChapterStudyStatus.studied);
      expect(
        PreferencesService.instance.loadStudiedChapterIds(),
        {'class-02'},
      );
    });

    test('markChapterStudied advances the recommended next chapter', () async {
      await study.markChapterStudied('class-01');

      expect(study.studiedCount, 1);
      expect(study.recommendedChapter?.id, 'class-02');

      final infos = study.chapterInfos();
      expect(infos[0].status, ChapterStudyStatus.studied);
      expect(infos[0].isRecommended, isFalse);
      expect(infos[1].isRecommended, isTrue);
      expect(infos[1].chapter.id, 'class-02');
    });

    test('markChapterStudied is idempotent', () async {
      await study.markChapterStudied('class-01');
      await study.markChapterStudied('class-01');

      expect(study.studiedCount, 1);
    });
  });
}
