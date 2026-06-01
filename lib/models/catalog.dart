// V2 data models — replaces channel_model.dart and video_model.dart.
// Matches the catalog.json schema hosted on Cloudflare Pages.
//
// i18n: String fields that support multiple languages are stored as
// Map<String, dynamic> matching the JSON schema {en, ur, roman, hi, ar}.
// Use LanguageProvider.resolve(field) in widgets to get the display string.
// Use field.en for non-UI contexts (audio service lock screen, etc.)

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Converts a JSON value that may be a plain String (legacy) or an i18n Map
/// into a normalised Map<String, dynamic>.
Map<String, dynamic> _toI18nMap(dynamic value) {
  if (value is String) return {'en': value};
  if (value is Map) return Map<String, dynamic>.from(value);
  return {'en': ''};
}

// Convenience extension so widgets can write field.en instead of field['en'].
extension I18nField on Map<String, dynamic> {
  String get en => (this['en'] as String?) ?? '';
  String get ur => (this['ur'] as String?) ?? en;
  String get roman => (this['roman'] as String?) ?? en;
}

// ── Models ────────────────────────────────────────────────────────────────────

class Book {
  final String id;
  final Map<String, dynamic> title;
  final Map<String, dynamic> speaker;
  final int totalDurationSeconds;
  final int lectureCount;
  final String coverImageUrl;
  final String language;

  const Book({
    required this.id,
    required this.title,
    required this.speaker,
    required this.totalDurationSeconds,
    required this.lectureCount,
    required this.coverImageUrl,
    required this.language,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: _toI18nMap(json['title']),
        speaker: _toI18nMap(json['speaker']),
        totalDurationSeconds: json['totalDurationSeconds'] as int,
        lectureCount: json['lectureCount'] as int,
        coverImageUrl: json['coverImageUrl'] as String,
        language: json['language'] as String? ?? 'ur',
      );
}

class Chapter {
  final String id;
  final int number;
  final Map<String, dynamic> title;
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
        title: _toI18nMap(json['title']),
        lectureCount: json['lectureCount'] as int,
      );
}

class Lecture {
  final String id;
  final int number;
  final String chapterId;
  final Map<String, dynamic> title;
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
        title: _toI18nMap(json['title']),
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
