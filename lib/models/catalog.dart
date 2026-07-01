// V2 data models — replaces channel_model.dart and video_model.dart.
// Matches the catalog.json schema hosted on Cloudflare Pages.
//
// i18n: String fields that support multiple languages are stored as
// Map<String, dynamic> matching the JSON schema {en, ur, roman, hi, ar}.
// Use LanguageProvider.resolve(field) in widgets to get the display string.
// Use field.en for non-UI contexts (audio service lock screen, etc.)

import 'package:myapp/data/content_i18n_overlay.dart';
import 'package:myapp/models/i18n_field.dart';

export 'i18n_field.dart';

// ── Defensive parsing helpers ───────────────────────────────────────────────
//
// The catalog is remote, CDN-hosted content. A single malformed row must not
// blank the entire app, so non-critical fields default and bad list entries
// are skipped rather than throwing. Critical fields (ids, a lecture's audio
// URL) still throw [FormatException] — [_parseList] catches that and drops
// just that one entry.

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// Optional string — returns null when [v] is missing or not a String.
String? _optStr(dynamic v) => v is String ? v : null;

/// Required, non-empty string for [field]; throws [FormatException] otherwise
/// so [_parseList] drops the offending entry.
String _reqStr(dynamic v, String field) {
  if (v is String && v.isNotEmpty) return v;
  throw FormatException('catalog: missing/invalid "$field"');
}

/// Maps [raw] (expected to be a JSON list) with [parse], skipping any entry
/// that is not an object or that [parse] rejects — so one bad row can't fail
/// the whole catalog.
List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final e in raw) {
    if (e is! Map<String, dynamic>) continue;
    try {
      out.add(parse(e));
    } catch (_) {
      // Skip a single malformed entry rather than failing the whole catalog.
    }
  }
  return out;
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
  final String? titleArabic;

  const Book({
    required this.id,
    required this.title,
    required this.speaker,
    required this.totalDurationSeconds,
    required this.lectureCount,
    required this.coverImageUrl,
    required this.language,
    this.titleArabic,
  });

  // The book is the catalog's identity (app bar, About card) — parse it
  // leniently so a missing optional field never blanks the whole catalog.
  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: _optStr(json['id']) ?? '',
        title: toI18nMap(json['title']),
        speaker: toI18nMap(json['speaker']),
        totalDurationSeconds: _asInt(json['totalDurationSeconds']),
        lectureCount: _asInt(json['lectureCount']),
        coverImageUrl: _optStr(json['coverImageUrl']) ?? '',
        language: _optStr(json['language']) ?? 'ur',
        titleArabic: _optStr(json['titleArabic']),
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

  // `id` is required (it keys lecture grouping); a chapter without one is
  // dropped by [_parseList]. Everything else defaults.
  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: _reqStr(json['id'], 'chapter.id'),
        number: _asInt(json['number']),
        title: toI18nMap(json['title']),
        lectureCount: _asInt(json['lectureCount']),
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
  final String? titleArabic;

  const Lecture({
    required this.id,
    required this.number,
    required this.chapterId,
    required this.title,
    required this.audioUrl,
    required this.durationSeconds,
    required this.fileSizeBytes,
    this.description,
    this.titleArabic,
  });

  // `id` is the only hard requirement (it keys progress/downloads/grouping);
  // a lecture without one is dropped by [_parseList]. Everything else defaults
  // — a missing duration shows 0:00, and a missing/empty audioUrl matches the
  // original contract (the player already guards against empty sources) rather
  // than failing the whole catalog.
  factory Lecture.fromJson(Map<String, dynamic> json) => Lecture(
        id: _reqStr(json['id'], 'lecture.id'),
        number: _asInt(json['number']),
        chapterId: _optStr(json['chapterId']) ?? '',
        title: toI18nMap(json['title']),
        audioUrl: _optStr(json['audioUrl']) ?? '',
        durationSeconds: _asInt(json['durationSeconds']),
        fileSizeBytes: _asInt(json['fileSizeBytes']),
        description: _optStr(json['description']),
        titleArabic: _optStr(json['titleArabic']),
      );
}

class DailyBenefit {
  final String id;
  final Map<String, dynamic> text;
  final Map<String, dynamic> source;
  final String? textArabic;

  const DailyBenefit({
    required this.id,
    required this.text,
    required this.source,
    this.textArabic,
  });

  // `id` keys the i18n overlay lookup; a benefit without one is dropped.
  factory DailyBenefit.fromJson(Map<String, dynamic> json) {
    final id = _reqStr(json['id'], 'dailyBenefit.id');
    return DailyBenefit(
      id: id,
      text: mergeI18nOverlay(
        toI18nMap(json['text']),
        benefitTextOverlays[id],
      ),
      source: toI18nMap(json['source']),
      textArabic: _optStr(json['textArabic']),
    );
  }
}

class Catalog {
  final int version;
  final Book book;
  final List<Chapter> chapters;
  final List<Lecture> lectures;
  final List<DailyBenefit> dailyBenefits;

  Catalog({
    required this.version,
    required this.book,
    required this.chapters,
    required this.lectures,
    required this.dailyBenefits,
  });

  // Lookup indexes, built lazily on first access. Before this, `chapterById`,
  // `lectureById`, and `lecturesForChapter` were O(n) scans called many times
  // per rebuild (study aggregates, lecture-list headers, home) — an
  // O(chapters × lectures) cost every frame. These make each lookup O(1).
  late final Map<String, Chapter> _chapterById = {
    for (final c in chapters) c.id: c,
  };
  late final Map<String, Lecture> _lectureById = {
    for (final l in lectures) l.id: l,
  };
  late final Map<String, List<Lecture>> _lecturesByChapter = _groupLectures();

  Map<String, List<Lecture>> _groupLectures() {
    final map = <String, List<Lecture>>{};
    for (final l in lectures) {
      (map[l.chapterId] ??= <Lecture>[]).add(l);
    }
    return map;
  }

  factory Catalog.fromJson(Map<String, dynamic> json) {
    // The book is mandatory — without it there's nothing to show. A missing or
    // malformed book throws, surfacing as the catalog "couldn't load" state.
    final bookJson = json['book'];
    if (bookJson is! Map<String, dynamic>) {
      throw const FormatException('catalog: missing "book"');
    }
    return Catalog(
      version: _asInt(json['version'], 1),
      book: Book.fromJson(bookJson),
      chapters: _parseList(json['chapters'], Chapter.fromJson),
      lectures: _parseList(json['lectures'], Lecture.fromJson),
      dailyBenefits: _parseList(json['dailyBenefits'], DailyBenefit.fromJson),
    );
  }

  Chapter chapterById(String id) =>
      _chapterById[id] ?? (throw StateError('No chapter with id "$id"'));

  /// The lecture with [id], or null if the catalog has no such lecture.
  Lecture? lectureById(String id) => _lectureById[id];

  List<Lecture> lecturesForChapter(String chapterId) =>
      _lecturesByChapter[chapterId] ?? const [];
}
