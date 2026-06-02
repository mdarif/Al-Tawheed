import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/progress_provider.dart';

/// Fraction at or above which a lecture part counts as complete.
const double kStudyPartCompleteThreshold = 0.99;

enum ChapterStudyStatus { notStarted, inProgress, studied }

/// Per-chapter study state derived from lecture progress and sticky studied IDs.
class ChapterStudyInfo {
  final Chapter chapter;
  final ChapterStudyStatus status;
  final int completedParts;
  final int totalParts;
  final bool isRecommended;

  const ChapterStudyInfo({
    required this.chapter,
    required this.status,
    required this.completedParts,
    required this.totalParts,
    required this.isRecommended,
  });

  double get fraction =>
      totalParts == 0 ? 0.0 : completedParts / totalParts;
}

/// Pure study-progress helpers — no persistence or side effects.
class StudyProgress {
  StudyProgress._();

  static bool isPartComplete(ProgressProvider progress, Lecture lecture) =>
      progress.getFraction(lecture.id, lecture.durationSeconds) >=
      kStudyPartCompleteThreshold;

  static bool isChapterLiveComplete(
    ProgressProvider progress,
    Catalog catalog,
    String chapterId,
  ) {
    final parts = catalog.lecturesForChapter(chapterId);
    return parts.isNotEmpty &&
        parts.every((l) => isPartComplete(progress, l));
  }

  static ChapterStudyStatus statusFor(
    String chapterId,
    Set<String> studiedChapterIds,
    ProgressProvider progress,
    Catalog catalog,
  ) {
    if (studiedChapterIds.contains(chapterId)) {
      return ChapterStudyStatus.studied;
    }
    final parts = catalog.lecturesForChapter(chapterId);
    if (parts.isEmpty) return ChapterStudyStatus.notStarted;

    final anyProgress = parts.any((l) => progress.hasProgress(l.id));
    final anyComplete = parts.any((l) => isPartComplete(progress, l));
    if (anyProgress || anyComplete) return ChapterStudyStatus.inProgress;
    return ChapterStudyStatus.notStarted;
  }

  static int completedPartsCount(
    ProgressProvider progress,
    Catalog catalog,
    String chapterId,
  ) =>
      catalog
          .lecturesForChapter(chapterId)
          .where((l) => isPartComplete(progress, l))
          .length;

  /// First chapter (in catalog order) not yet in the sticky studied set.
  static Chapter? recommendedChapter(
    Catalog catalog,
    Set<String> studiedChapterIds,
  ) {
    for (final chapter in catalog.chapters) {
      if (!studiedChapterIds.contains(chapter.id)) return chapter;
    }
    return null;
  }

  static List<ChapterStudyInfo> chapterInfos(
    Catalog catalog,
    Set<String> studiedChapterIds,
    ProgressProvider progress,
  ) {
    final recommended = recommendedChapter(catalog, studiedChapterIds);
    return catalog.chapters.map((chapter) {
      final parts = catalog.lecturesForChapter(chapter.id);
      return ChapterStudyInfo(
        chapter: chapter,
        status: statusFor(
          chapter.id,
          studiedChapterIds,
          progress,
          catalog,
        ),
        completedParts: completedPartsCount(progress, catalog, chapter.id),
        totalParts: parts.length,
        isRecommended: recommended?.id == chapter.id,
      );
    }).toList();
  }

  /// Lecture to play when starting or resuming a class session.
  ///
  /// [restartStudied] — when true and the class is already studied, returns
  /// the first part (re-study from the beginning).
  static Lecture? sessionStartLecture(
    Catalog catalog,
    Set<String> studiedChapterIds,
    ProgressProvider progress,
    String chapterId, {
    bool restartStudied = false,
  }) {
    final parts = catalog.lecturesForChapter(chapterId);
    if (parts.isEmpty) return null;

    final status = statusFor(chapterId, studiedChapterIds, progress, catalog);
    if (status == ChapterStudyStatus.studied && restartStudied) {
      return parts.first;
    }

    for (final part in parts) {
      if (!isPartComplete(progress, part)) return part;
    }
    return parts.first;
  }

  /// Chapter IDs that are live-complete but not yet in the sticky studied set.
  static Set<String> newlyStudiedChapterIds(
    Catalog catalog,
    Set<String> studiedChapterIds,
    ProgressProvider progress,
  ) {
    final added = <String>{};
    for (final chapter in catalog.chapters) {
      if (studiedChapterIds.contains(chapter.id)) continue;
      if (isChapterLiveComplete(progress, catalog, chapter.id)) {
        added.add(chapter.id);
      }
    }
    return added;
  }
}
