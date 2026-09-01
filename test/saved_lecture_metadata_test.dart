import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/saved_lecture_metadata.dart';

void main() {
  const lecture = Lecture(
    id: 'lec-01',
    number: 1,
    chapterId: 'chapter-01',
    title: {'en': 'Reliable title', 'ur': 'قابلِ اعتماد عنوان'},
    audioUrl: 'https://example.test/lec-01.mp3',
    durationSeconds: 123,
    fileSizeBytes: 456,
  );

  test('round-trips the immutable data needed for an offline row', () {
    final restored = SavedLectureMetadata.fromJson(
      SavedLectureMetadata.fromLecture(lecture).toJson(),
    ).toLecture();

    expect(restored.id, lecture.id);
    expect(restored.title, lecture.title);
    expect(restored.audioUrl, lecture.audioUrl);
    expect(restored.durationSeconds, lecture.durationSeconds);
  });

  test('rejects an entry without an id', () {
    expect(
      () => SavedLectureMetadata.fromJson(const {
        'title': {'en': 'Bad'},
      }),
      throwsFormatException,
    );
  });
}
