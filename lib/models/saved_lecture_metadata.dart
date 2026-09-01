import 'package:myapp/models/catalog.dart';

/// Immutable row data retained for content the user explicitly keeps.
///
/// A remote catalogue is a convenience, not the authority for bookmarks and
/// local audio. This snapshot is deliberately sufficient to render and play a
/// row after a cold offline launch.
class SavedLectureMetadata {
  const SavedLectureMetadata({
    required this.id,
    required this.number,
    required this.chapterId,
    required this.title,
    required this.audioUrl,
    required this.durationSeconds,
    required this.fileSizeBytes,
  });

  final String id;
  final int number;
  final String chapterId;
  final Map<String, dynamic> title;
  final String audioUrl;
  final int durationSeconds;
  final int fileSizeBytes;

  factory SavedLectureMetadata.fromLecture(Lecture lecture) =>
      SavedLectureMetadata(
        id: lecture.id,
        number: lecture.number,
        chapterId: lecture.chapterId,
        title: Map<String, dynamic>.from(lecture.title),
        audioUrl: lecture.audioUrl,
        durationSeconds: lecture.durationSeconds,
        fileSizeBytes: lecture.fileSizeBytes,
      );

  factory SavedLectureMetadata.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('saved lecture metadata requires an id');
    }
    return SavedLectureMetadata(
      id: id,
      number: json['number'] is num ? (json['number'] as num).toInt() : 0,
      chapterId: json['chapterId'] is String ? json['chapterId'] as String : '',
      title: json['title'] is Map
          ? Map<String, dynamic>.from(json['title'] as Map)
          : const {},
      audioUrl: json['audioUrl'] is String ? json['audioUrl'] as String : '',
      durationSeconds: json['durationSeconds'] is num
          ? (json['durationSeconds'] as num).toInt()
          : 0,
      fileSizeBytes: json['fileSizeBytes'] is num
          ? (json['fileSizeBytes'] as num).toInt()
          : 0,
    );
  }

  Lecture toLecture() => Lecture(
        id: id,
        number: number,
        chapterId: chapterId,
        title: title,
        audioUrl: audioUrl,
        durationSeconds: durationSeconds,
        fileSizeBytes: fileSizeBytes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'chapterId': chapterId,
        'title': title,
        'audioUrl': audioUrl,
        'durationSeconds': durationSeconds,
        'fileSizeBytes': fileSizeBytes,
      };
}
