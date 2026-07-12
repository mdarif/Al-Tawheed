// Data models for the bundled "Book" asset (assets/content/book_<seriesId>.json)
// — the full original Arabic text of Kitab at-Tawheed, shown in the Book tab.
//
// Unlike catalog.dart's i18n maps, these fields are plain Arabic strings:
// the book's own text is never translated, regardless of the app's UI
// language (see SeriesConfig.isRtl / LanguageProvider.resolveForSeries).

// ── Defensive parsing helpers ───────────────────────────────────────────────
//
// The book is a bundled asset, but a single malformed chapter must not throw
// and blank the whole reader. A chapter's `id` (keys scroll-position storage)
// and `text` (its content) are required; a bad chapter is skipped. Everything
// else defaults. Mirrors the lenient approach in catalog.dart.

String _reqStr(dynamic v, String field) {
  if (v is String && v.isNotEmpty) return v;
  throw FormatException('book: missing/invalid "$field"');
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class BookChapter {
  final String id;
  final int number;
  final String title;
  final String text;

  const BookChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.text,
  });

  factory BookChapter.fromJson(Map<String, dynamic> json) => BookChapter(
        id: _reqStr(json['id'], 'chapter.id'),
        number: _asInt(json['number']),
        title: json['title'] is String ? json['title'] as String : '',
        text: _reqStr(json['text'], 'chapter.text'),
      );
}

class BookContent {
  final String title;
  final String author;
  final List<BookChapter> chapters;

  const BookContent({
    required this.title,
    required this.author,
    required this.chapters,
  });

  factory BookContent.fromJson(Map<String, dynamic> json) {
    final rawBook = json['book'];
    final meta = rawBook is Map<String, dynamic> ? rawBook : const <String, dynamic>{};
    final rawChapters = json['chapters'];
    final chapters = <BookChapter>[];
    if (rawChapters is List) {
      for (final e in rawChapters) {
        if (e is! Map<String, dynamic>) continue;
        try {
          chapters.add(BookChapter.fromJson(e));
        } catch (_) {
          // Skip a single malformed chapter rather than blanking the reader.
        }
      }
    }
    return BookContent(
      title: meta['title'] is String ? meta['title'] as String : '',
      author: meta['author'] is String ? meta['author'] as String : '',
      chapters: chapters,
    );
  }

  BookChapter chapterById(String id) => chapters.firstWhere((c) => c.id == id);
}
