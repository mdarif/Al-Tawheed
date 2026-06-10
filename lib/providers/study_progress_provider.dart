import 'package:flutter/foundation.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/services/preferences_service.dart';

/// Study-mode progress: chapter status, sticky studied count, session helpers.
class StudyProgressProvider extends ChangeNotifier {
  StudyProgressProvider(this._progress, this._catalog)
      : _prefs = PreferencesService.instance;

  final ProgressProvider _progress;
  final CatalogProvider _catalog;
  final PreferencesService _prefs;

  Set<String> _studiedChapterIds = {};

  void load() {
    _studiedChapterIds = _prefs.loadStudiedChapterIds();
    _progress.addListener(_onProgressChanged);
    _catalog.addListener(_onCatalogChanged);
    notifyListeners();
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  Set<String> get studiedChapterIds => Set.unmodifiable(_studiedChapterIds);

  int get studiedCount => _studiedChapterIds.length;

  int get totalChapterCount => _catalog.catalog?.chapters.length ?? 15;

  bool isChapterStudied(String chapterId) =>
      _studiedChapterIds.contains(chapterId);

  ChapterStudyStatus chapterStatus(String chapterId) {
    final catalog = _catalog.catalog;
    if (catalog == null) return ChapterStudyStatus.notStarted;
    return StudyProgress.statusFor(
      chapterId,
      _studiedChapterIds,
      _progress,
      catalog,
    );
  }

  List<ChapterStudyInfo> chapterInfos() {
    final catalog = _catalog.catalog;
    if (catalog == null) return const [];
    return StudyProgress.chapterInfos(
      catalog,
      _studiedChapterIds,
      _progress,
    );
  }

  StudyStats get stats {
    final catalog = _catalog.catalog;
    if (catalog == null) {
      return const StudyStats(
        completedLectures: 0,
        totalLectures: 0,
        completedSeconds: 0,
        totalSeconds: 0,
      );
    }
    return StudyProgress.stats(catalog, _studiedChapterIds, _progress);
  }

  Chapter? get recommendedChapter {
    final catalog = _catalog.catalog;
    if (catalog == null) return null;
    return StudyProgress.recommendedChapter(catalog, _studiedChapterIds);
  }

  /// First incomplete part, or first part when re-studying a completed class.
  Lecture? sessionStartLecture(String chapterId, {bool restartStudied = false}) {
    final catalog = _catalog.catalog;
    if (catalog == null) return null;
    return StudyProgress.sessionStartLecture(
      catalog,
      _studiedChapterIds,
      _progress,
      chapterId,
      restartStudied: restartStudied,
    );
  }

  List<Lecture> chapterQueue(String chapterId) {
    final catalog = _catalog.catalog;
    if (catalog == null) return const [];
    return catalog.lecturesForChapter(chapterId);
  }

  // ── Commands ─────────────────────────────────────────────────────────────

  /// Call when a class session finishes to persist sticky studied state.
  Future<void> markChapterStudied(String chapterId) async {
    if (_studiedChapterIds.contains(chapterId)) return;
    _studiedChapterIds = {..._studiedChapterIds, chapterId};
    notifyListeners();
    await _prefs.saveStudiedChapterIds(_studiedChapterIds);
  }

  /// After progress updates, promote live-complete chapters to studied.
  Future<void> syncStudiedChapters() async {
    final catalog = _catalog.catalog;
    if (catalog == null) return;

    final added = StudyProgress.newlyStudiedChapterIds(
      catalog,
      _studiedChapterIds,
      _progress,
    );
    if (added.isEmpty) return;

    _studiedChapterIds = {..._studiedChapterIds, ...added};
    notifyListeners();
    await _prefs.saveStudiedChapterIds(_studiedChapterIds);
  }

  void _onProgressChanged() {
    syncStudiedChapters();
    notifyListeners();
  }

  void _onCatalogChanged() {
    syncStudiedChapters();
    notifyListeners();
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    _catalog.removeListener(_onCatalogChanged);
    super.dispose();
  }
}
