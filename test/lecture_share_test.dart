import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/utils/lecture_share.dart';

const _urdu = SeriesConfig(
  id: 'tawheed-ur',
  catalogUrl: 'https://example.com/tawheed-ur/catalog.json',
  storagePrefix: '',
  hasStudyMode: true,
  hasBook: true,
  language: 'ur',
  displayName: {'en': 'Kitab at-Tawheed (Urdu)'},
  speakerName: {'en': 'Shaikh Abdullah Nasir Rahmani'},
);

const _arabic = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: false,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan'},
);

Lecture _lec({required int number, String chapterId = 'class-01'}) => Lecture(
      id: 'lec-${number.toString().padLeft(3, '0')}',
      number: number,
      chapterId: chapterId,
      title: const {'en': 'A lecture'},
      audioUrl: 'https://pub.example.r2.dev/lec.mp3',
      durationSeconds: 60,
      fileSizeBytes: 1000,
    );

void main() {
  group('lectureWebUrl', () {
    test('Urdu series → chaptered /lectures/{chapterId}/part-NN/ path', () {
      // NN is the GLOBAL lecture number, not a per-chapter index — e.g. the
      // first lecture of class-02 is part-03. See docs/gotchas.md.
      expect(
        lectureWebUrl(
          _lec(number: 3, chapterId: 'class-02'),
          _urdu,
          websiteBase: 'https://kitabattawheed.com',
        ),
        'https://kitabattawheed.com/lectures/class-02/part-03/',
      );
    });

    test('Arabic series → /arabic/dars-NN/ path (chapterId ignored)', () {
      expect(
        lectureWebUrl(
          _lec(number: 7, chapterId: 'class-01'),
          _arabic,
          websiteBase: 'https://kitabattawheed.com',
        ),
        'https://kitabattawheed.com/arabic/dars-07/',
      );
    });

    test('single-digit numbers are zero-padded to two digits', () {
      expect(
        lectureWebUrl(_lec(number: 1), _urdu, websiteBase: 'https://x.com'),
        'https://x.com/lectures/class-01/part-01/',
      );
    });

    test('numbers ≥ 10 keep their natural width', () {
      expect(
        lectureWebUrl(_lec(number: 12), _arabic, websiteBase: 'https://x.com'),
        'https://x.com/arabic/dars-12/',
      );
    });

    test('slug digits are ASCII, never localized (Arabic/Urdu) numerals', () {
      final url =
          lectureWebUrl(_lec(number: 5), _urdu, websiteBase: 'https://x.com');
      expect(RegExp(r'[٠-٩۰-۹]').hasMatch(url), isFalse);
      expect(url.contains('part-05'), isTrue);
    });

    test('a trailing slash on the base is not doubled', () {
      expect(
        lectureWebUrl(_lec(number: 2), _urdu, websiteBase: 'https://x.com/'),
        'https://x.com/lectures/class-01/part-02/',
      );
    });

    test('falls back to the canonical site when base is null or empty', () {
      expect(
        lectureWebUrl(_lec(number: 2), _urdu, websiteBase: null),
        'https://kitabattawheed.com/lectures/class-01/part-02/',
      );
      expect(
        lectureWebUrl(_lec(number: 2), _urdu, websiteBase: ''),
        'https://kitabattawheed.com/lectures/class-01/part-02/',
      );
    });
  });

  test('lectureShareText joins title and url with a blank line', () {
    expect(
      lectureShareText(title: 'Class 01', url: 'https://x.com/y/'),
      'Class 01\n\nhttps://x.com/y/',
    );
  });
}
