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

  group('toArabicDigits', () {
    test('converts an int to Eastern Arabic-Indic numerals', () {
      expect(toArabicDigits(91), '٩١');
      expect(toArabicDigits(0), '٠');
    });
  });
}
