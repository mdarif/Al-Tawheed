// Validates the Release C content-identity mapping between a catalog's
// chapters and one edition's bundled Book (see ADR-0003). Pure — no I/O —
// so both the app and tool/validate_content_mapping.dart can share it.

import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/catalog.dart';

enum ContentMappingStatus {
  /// Resolves to a real BookChapter.id in the given book.
  valid,

  /// No bookChapterId set — expected, not a problem.
  unmapped,

  /// Set, but no such chapter exists in the given book (typo, removed
  /// chapter, or the edition has no book at all).
  dangling,

  /// Two or more catalog chapters map to the same bookChapterId — breaks
  /// the reverse (Book -> audio) lookup.
  duplicate,
}

class ChapterMappingResult {
  final Chapter chapter;
  final ContentMappingStatus status;

  const ChapterMappingResult(this.chapter, this.status);

  bool get isHardError =>
      status == ContentMappingStatus.dangling ||
      status == ContentMappingStatus.duplicate;
}

class ContentMappingReport {
  final List<ChapterMappingResult> results;

  const ContentMappingReport(this.results);

  List<ChapterMappingResult> get valid =>
      results.where((r) => r.status == ContentMappingStatus.valid).toList();
  List<ChapterMappingResult> get unmapped =>
      results.where((r) => r.status == ContentMappingStatus.unmapped).toList();
  List<ChapterMappingResult> get dangling =>
      results.where((r) => r.status == ContentMappingStatus.dangling).toList();
  List<ChapterMappingResult> get duplicate =>
      results.where((r) => r.status == ContentMappingStatus.duplicate).toList();

  bool get hasHardErrors => results.any((r) => r.isHardError);
}

/// Validates [catalog]'s chapters against [book] — always the *same
/// edition's* book. `BookChapter.id` values (e.g. "ch-01") are reused
/// across editions, so passing a different edition's [book] would produce
/// meaningless results by construction; callers must never do that. Passing
/// null for [book] (an edition with no book at all) reports every mapped
/// chapter as dangling and every unmapped chapter as unmapped, same as any
/// other edition where nothing resolves.
ContentMappingReport validateContentMapping(
  Catalog catalog,
  BookContent? book,
) {
  final bookChapterIds = book?.chapters.map((c) => c.id).toSet() ?? const {};

  // First pass: which bookChapterId values are claimed by more than one
  // catalog chapter.
  final claimCounts = <String, int>{};
  for (final chapter in catalog.chapters) {
    final target = chapter.bookChapterId;
    if (target == null) continue;
    claimCounts[target] = (claimCounts[target] ?? 0) + 1;
  }

  final results = catalog.chapters.map((chapter) {
    final target = chapter.bookChapterId;
    if (target == null) {
      return ChapterMappingResult(chapter, ContentMappingStatus.unmapped);
    }
    if ((claimCounts[target] ?? 0) > 1) {
      return ChapterMappingResult(chapter, ContentMappingStatus.duplicate);
    }
    if (!bookChapterIds.contains(target)) {
      return ChapterMappingResult(chapter, ContentMappingStatus.dangling);
    }
    return ChapterMappingResult(chapter, ContentMappingStatus.valid);
  }).toList();

  return ContentMappingReport(results);
}
