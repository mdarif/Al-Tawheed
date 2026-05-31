// V2 data models — replaces channel_model.dart and video_model.dart.
// Matches the catalog.json schema hosted on Cloudflare Pages.
// json_serializable added in Phase 2 when catalog_service.dart is implemented.

class Book {
  final String id;
  final String title;
  final String titleArabic;
  final String speaker;
  final int totalDurationSeconds;
  final int lectureCount;
  final String coverImageUrl;
  final String language;

  const Book({
    required this.id,
    required this.title,
    required this.titleArabic,
    required this.speaker,
    required this.totalDurationSeconds,
    required this.lectureCount,
    required this.coverImageUrl,
    required this.language,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String,
        titleArabic: json['titleArabic'] as String,
        speaker: json['speaker'] as String,
        totalDurationSeconds: json['totalDurationSeconds'] as int,
        lectureCount: json['lectureCount'] as int,
        coverImageUrl: json['coverImageUrl'] as String,
        language: json['language'] as String,
      );
}

class Chapter {
  final String id;
  final int number;
  final String title;
  final int lectureCount;

  const Chapter({
    required this.id,
    required this.number,
    required this.title,
    required this.lectureCount,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'] as String,
        number: json['number'] as int,
        title: json['title'] as String,
        lectureCount: json['lectureCount'] as int,
      );
}

class Lecture {
  final String id;
  final int number;
  final String chapterId;
  final String title;
  final String audioUrl;
  final int durationSeconds;
  final int fileSizeBytes;
  final String? description;

  const Lecture({
    required this.id,
    required this.number,
    required this.chapterId,
    required this.title,
    required this.audioUrl,
    required this.durationSeconds,
    required this.fileSizeBytes,
    this.description,
  });

  factory Lecture.fromJson(Map<String, dynamic> json) => Lecture(
        id: json['id'] as String,
        number: json['number'] as int,
        chapterId: json['chapterId'] as String,
        title: json['title'] as String,
        audioUrl: json['audioUrl'] as String,
        durationSeconds: json['durationSeconds'] as int,
        fileSizeBytes: json['fileSizeBytes'] as int,
        description: json['description'] as String?,
      );
}

class DailyBenefit {
  final String id;
  final String text;
  final String source;
  final String? textArabic;

  const DailyBenefit({
    required this.id,
    required this.text,
    required this.source,
    this.textArabic,
  });

  factory DailyBenefit.fromJson(Map<String, dynamic> json) => DailyBenefit(
        id: json['id'] as String,
        text: json['text'] as String,
        source: json['source'] as String,
        textArabic: json['textArabic'] as String?,
      );
}

class Catalog {
  final int version;
  final Book book;
  final List<Chapter> chapters;
  final List<Lecture> lectures;
  final List<DailyBenefit> dailyBenefits;

  const Catalog({
    required this.version,
    required this.book,
    required this.chapters,
    required this.lectures,
    required this.dailyBenefits,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
        version: json['version'] as int,
        book: Book.fromJson(json['book'] as Map<String, dynamic>),
        chapters: (json['chapters'] as List<dynamic>)
            .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
            .toList(),
        lectures: (json['lectures'] as List<dynamic>)
            .map((e) => Lecture.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyBenefits: json['dailyBenefits'] != null
            ? (json['dailyBenefits'] as List<dynamic>)
                .map((e) => DailyBenefit.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
      );

  Chapter chapterById(String id) =>
      chapters.firstWhere((c) => c.id == id);

  List<Lecture> lecturesForChapter(String chapterId) =>
      lectures.where((l) => l.chapterId == chapterId).toList();
}
