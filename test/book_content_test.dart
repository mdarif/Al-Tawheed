import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/book_content.dart';

// The book is a bundled asset, but a single malformed chapter must never blank
// the whole reader. These tests pin the lenient parsing in BookContent.fromJson
// / BookChapter.fromJson (id + text required per chapter; everything else
// defaults; bad entries are skipped).
void main() {
  test('parses a well-formed book', () {
    final book = BookContent.fromJson({
      'book': {'title': 'T', 'author': 'A'},
      'chapters': [
        {'id': 'ch-00', 'number': 0, 'title': 'Intro', 'text': 'hello'},
      ],
    });

    expect(book.title, 'T');
    expect(book.author, 'A');
    expect(book.chapters, hasLength(1));
    expect(book.chapters.single.id, 'ch-00');
  });

  test('skips a chapter missing its text but keeps the rest', () {
    final book = BookContent.fromJson({
      'book': {'title': 'T', 'author': 'A'},
      'chapters': [
        {'id': 'ch-00', 'number': 0, 'title': 'ok', 'text': 'hello'},
        {'id': 'ch-01', 'number': 1, 'title': 'bad'}, // no text → dropped
        {'id': 'ch-02', 'text': 'world'}, // missing number/title → defaulted
      ],
    });

    expect(book.chapters.map((c) => c.id), ['ch-00', 'ch-02']);
    expect(book.chapters.last.number, 0); // defaulted
    expect(book.chapters.last.title, ''); // defaulted
  });

  test('drops a chapter with no id', () {
    final book = BookContent.fromJson({
      'chapters': [
        {'number': 1, 'title': 't', 'text': 'x'}, // no id → dropped
        {'id': 'ch-01', 'text': 'y'},
      ],
    });

    expect(book.chapters, hasLength(1));
    expect(book.chapters.single.id, 'ch-01');
  });

  test('defaults missing book metadata to empty strings', () {
    final book = BookContent.fromJson({
      'chapters': [
        {'id': 'ch-00', 'text': 'x'},
      ],
    });

    expect(book.title, '');
    expect(book.author, '');
  });

  test('tolerates a non-list chapters field', () {
    final book = BookContent.fromJson({
      'book': {'title': 'T'},
      'chapters': null,
    });

    expect(book.chapters, isEmpty);
    expect(book.title, 'T');
  });

  test('coerces a numeric chapter number from a string', () {
    final book = BookContent.fromJson({
      'chapters': [
        {'id': 'ch-05', 'number': '5', 'text': 'x'},
      ],
    });

    expect(book.chapters.single.number, 5);
  });
}
