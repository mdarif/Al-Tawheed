import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/duration_formatter.dart';

void main() {
  group('arabicDigitsInString', () {
    test('converts Western digits to Eastern Arabic-Indic', () {
      expect(arabicDigitsInString('151'), '١٥١');
      expect(arabicDigitsInString('0123456789'), '٠١٢٣٤٥٦٧٨٩');
    });

    test('leaves non-digit characters untouched', () {
      expect(
        arabicDigitsInString('تَعقِلُونَ (151)'),
        'تَعقِلُونَ (١٥١)',
      );
      expect(arabicDigitsInString('بلا أرقام'), 'بلا أرقام');
    });
  });

  group('toHoursAndMinutes', () {
    test('splits seconds into whole hours and remaining minutes', () {
      expect(DurationFormatter.toHoursAndMinutes(97617), (27, 6));
      expect(DurationFormatter.toHoursAndMinutes(83940), (23, 19));
      expect(DurationFormatter.toHoursAndMinutes(0), (0, 0));
    });

    test('drops seconds rather than rounding up', () {
      // 59:59 is "0h 59m", never "1h 0m" — a total must not overstate itself.
      expect(DurationFormatter.toHoursAndMinutes(3599), (0, 59));
    });
  });

  group('toArabicDigits', () {
    test('converts an int to Eastern Arabic-Indic numerals', () {
      expect(toArabicDigits(91), '٩١');
      expect(toArabicDigits(0), '٠');
    });
  });

  group('localizedDigitsInString', () {
    test('uses Urdu numerals (U+06Fx) for the Urdu series', () {
      expect(localizedDigitsInString('04', 'ur'), '۰۴');
      // Urdu and Arabic-Indic are DIFFERENT codepoints that look alike at a
      // glance — assert the actual scalar values, not just the glyphs.
      expect('۰۴'.codeUnits, [0x06F0, 0x06F4]);
    });

    test('uses Arabic-Indic numerals (U+066x) for the Arabic series', () {
      expect(localizedDigitsInString('04', 'ar'), '٠٤');
      expect('٠٤'.codeUnits, [0x0660, 0x0664]);
    });

    test('leaves digits Western for a language we have no numerals for', () {
      // SeriesConfig.fromJson defaults a manifest without `language` to 'en'.
      // Silently emitting Arabic numerals there hides the misconfiguration;
      // Western digits make it visible.
      expect(localizedDigitsInString('04', 'en'), '04');
      expect(localizedDigitsInString('04', ''), '04');
    });

    test('leaves non-digits untouched', () {
      expect(localizedDigitsInString('الدرس 1', 'ar'), 'الدرس ١');
    });
  });

  group('toLocalizedDigits', () {
    test('follows the same language rules as localizedDigitsInString', () {
      expect(toLocalizedDigits(45, 'ur'), '۴۵');
      expect(toLocalizedDigits(45, 'ar'), '٤٥');
      expect(toLocalizedDigits(45, 'en'), '45');
    });
  });
}
