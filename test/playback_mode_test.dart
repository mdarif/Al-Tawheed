import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/audio/playback_mode.dart';
import 'package:myapp/models/catalog.dart';

const _chapter = Chapter(
  id: 'class-01',
  number: 1,
  title: {'en': 'Class 01'},
  lectureCount: 3,
);

void main() {
  group('shouldCompleteStudyChapter', () {
    test('true on last part in study mode', () {
      expect(
        shouldCompleteStudyChapter(
          mode: PlaybackMode.study,
          currentIndex: 2,
          queueLength: 3,
        ),
        isTrue,
      );
    });

    test('false when more parts remain', () {
      expect(
        shouldCompleteStudyChapter(
          mode: PlaybackMode.study,
          currentIndex: 0,
          queueLength: 3,
        ),
        isFalse,
      );
    });

    test('false in casual mode even on last track', () {
      expect(
        shouldCompleteStudyChapter(
          mode: PlaybackMode.casual,
          currentIndex: 2,
          queueLength: 3,
        ),
        isFalse,
      );
    });
  });

  group('formatStudyContextLabel', () {
    test('returns class and part label in study mode', () {
      expect(
        formatStudyContextLabel(
          mode: PlaybackMode.study,
          chapter: _chapter,
          currentIndex: 1,
          queueLength: 3,
        ),
        'Class 01 · Part 2 of 3',
      );
    });

    test('returns null outside study mode', () {
      expect(
        formatStudyContextLabel(
          mode: PlaybackMode.casual,
          chapter: _chapter,
          currentIndex: 1,
          queueLength: 3,
        ),
        isNull,
      );
    });
  });
}
