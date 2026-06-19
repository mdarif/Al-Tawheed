// Data models for the bundled "Book" asset (assets/content/book_<seriesId>.json)
// — the full original Arabic text of Kitab at-Tawheed, shown in the Book tab.
//
// Unlike catalog.dart's i18n maps, these fields are plain Arabic strings:
// the book's own text is never translated, regardless of the app's UI
// language (see SeriesConfig.isRtl / LanguageProvider.resolveForSeries).

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
        id: json['id'] as String,
        number: json['number'] as int,
        title: json['title'] as String,
        text: json['text'] as String,
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

  factory BookContent.fromJson(Map<String, dynamic> json) => BookContent(
        title: json['book']['title'] as String,
        author: json['book']['author'] as String,
        chapters: (json['chapters'] as List<dynamic>)
            .map((e) => BookChapter.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  BookChapter chapterById(String id) => chapters.firstWhere((c) => c.id == id);
}
