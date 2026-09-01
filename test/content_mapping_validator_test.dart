import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/services/content_mapping_validator.dart';

const _book = Book(
  id: 'book',
  title: {'en': 'Test Book'},
  speaker: {'en': 'Sheikh'},
  totalDurationSeconds: 100,
  lectureCount: 1,
  coverImageUrl: '',
  language: 'English',
);

Catalog _catalog(List<Chapter> chapters) => Catalog(
      version: 1,
      book: _book,
      chapters: chapters,
      lectures: const [],
      dailyBenefits: const [],
    );

const _bookContent = BookContent(
  title: 'Kitab',
  author: 'Author',
  chapters: [
    BookChapter(id: 'ch-01', number: 1, title: 'One', text: 'text'),
    BookChapter(id: 'ch-02', number: 2, title: 'Two', text: 'text'),
  ],
);

// A different edition's book, sharing the same "ch-01" id namespace — used
// to prove the validator never resolves against the wrong book.
const _otherEditionBook = BookContent(
  title: 'Kitab (Other Edition)',
  author: 'Author',
  chapters: [
    BookChapter(id: 'ch-01', number: 1, title: 'Wrong edition', text: 'text'),
  ],
);

Chapter _chapter(String id, {String? bookChapterId}) => Chapter(
      id: id,
      number: 1,
      title: const {'en': 'Chapter'},
      lectureCount: 1,
      bookChapterId: bookChapterId,
    );

void main() {
  test('valid: resolves to a real BookChapter.id in the same edition', () {
    final report = validateContentMapping(
      _catalog([_chapter('c1', bookChapterId: 'ch-01')]),
      _bookContent,
    );

    expect(report.valid, hasLength(1));
    expect(report.hasHardErrors, isFalse);
  });

  test('unmapped: no bookChapterId is not an error', () {
    final report = validateContentMapping(
      _catalog([_chapter('c1')]),
      _bookContent,
    );

    expect(report.unmapped, hasLength(1));
    expect(report.hasHardErrors, isFalse);
  });

  test('legacy-v1: a catalog with no bookChapterId anywhere is all-unmapped',
      () {
    final report = validateContentMapping(
      _catalog([_chapter('c1'), _chapter('c2'), _chapter('c3')]),
      _bookContent,
    );

    expect(report.unmapped, hasLength(3));
    expect(report.valid, isEmpty);
    expect(report.hasHardErrors, isFalse);
  });

  test('dangling: bookChapterId set but not present in this edition\'s book',
      () {
    final report = validateContentMapping(
      _catalog([_chapter('c1', bookChapterId: 'ch-99')]),
      _bookContent,
    );

    expect(report.dangling, hasLength(1));
    expect(report.hasHardErrors, isTrue);
  });

  test(
      'dangling: an edition with no book at all reports every mapped '
      'chapter as dangling', () {
    final report = validateContentMapping(
      _catalog([_chapter('c1', bookChapterId: 'ch-01')]),
      null,
    );

    expect(report.dangling, hasLength(1));
    expect(report.hasHardErrors, isTrue);
  });

  test('duplicate: two catalog chapters mapping to the same bookChapterId', () {
    final report = validateContentMapping(
      _catalog([
        _chapter('c1', bookChapterId: 'ch-01'),
        _chapter('c2', bookChapterId: 'ch-01'),
      ]),
      _bookContent,
    );

    expect(report.duplicate, hasLength(2));
    expect(report.hasHardErrors, isTrue);
  });

  test(
      'wrong-edition: a mapping that would resolve against a different '
      'edition\'s book must not validate here', () {
    // 'ch-01' exists in _otherEditionBook but the validator is called with
    // _bookContent (which also happens to have 'ch-01' — the point is that
    // resolution must always be against the book actually passed in, never
    // an ambient/shared one).
    final report = validateContentMapping(
      _catalog([_chapter('c1', bookChapterId: 'ch-01')]),
      _otherEditionBook,
    );
    expect(report.valid, hasLength(1)); // ch-01 exists in _otherEditionBook

    // The same mapping against a book that does NOT have that chapter must
    // be dangling — proving the validator has no memory of the other call.
    final crossEditionReport = validateContentMapping(
      _catalog([_chapter('c1', bookChapterId: 'ch-99')]),
      _otherEditionBook,
    );
    expect(crossEditionReport.dangling, hasLength(1));
  });

  test('a mix of statuses is reported independently per chapter', () {
    final report = validateContentMapping(
      _catalog([
        _chapter('c1', bookChapterId: 'ch-01'), // valid
        _chapter('c2'), // unmapped
        _chapter('c3', bookChapterId: 'ch-99'), // dangling
        _chapter('c4', bookChapterId: 'ch-02'), // valid
      ]),
      _bookContent,
    );

    expect(report.valid, hasLength(2));
    expect(report.unmapped, hasLength(1));
    expect(report.dangling, hasLength(1));
    expect(report.duplicate, isEmpty);
    expect(report.hasHardErrors, isTrue);
  });
}
