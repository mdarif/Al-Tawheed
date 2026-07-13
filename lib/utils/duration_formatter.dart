class DurationFormatter {
  DurationFormatter._();

  /// 2157 → "35:57"   |   3661 → "1:01:01"
  static String fromSeconds(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 97617 → "27h 6m"
  static String toHoursMinutes(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// 83940 → "٢٣ س ١٩ د"
  static String toArabicHoursMinutes(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${toArabicDigits(h)} س ${toArabicDigits(m)} د';
    return '${toArabicDigits(m)} د';
  }
}

const _easternArabicDigits = [
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩',
];

/// Converts the Western digits of [n] to Eastern Arabic-Indic numerals.
/// 91 → "٩١"
String toArabicDigits(int n) => n
    .toString()
    .split('')
    .map((d) => _easternArabicDigits[int.parse(d)])
    .join();

/// Converts every Western digit (0-9) inside [s] to Eastern Arabic-Indic,
/// leaving all other characters untouched. Use for mixed Arabic text such as
/// book passages with inline ayah numbers, e.g. "...تَعقِلُونَ (151)".
String arabicDigitsInString(String s) => s.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => _easternArabicDigits[int.parse(m[0]!)],
    );

// Urdu uses a distinct set of Perso-Arabic numerals (U+06F0-06F9) that differ
// from the Arabic-Indic ones above — e.g. Urdu ۴ vs Arabic ٤.
const _urduDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Converts the Western digits of [n] to Urdu numerals. 91 → "۹۱"
String toUrduDigits(int n) =>
    n.toString().split('').map((d) => _urduDigits[int.parse(d)]).join();

/// Converts every Western digit (0-9) inside [s] to Urdu numerals.
String urduDigitsInString(String s) => s.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => _urduDigits[int.parse(m[0]!)],
    );

/// Localises digits in [s] for [language]: Urdu numerals for `'ur'`,
/// Eastern Arabic-Indic otherwise (Arabic content).
String localizedDigitsInString(String s, String language) =>
    language == 'ur' ? urduDigitsInString(s) : arabicDigitsInString(s);

/// Localises the digits of [n] for [language] (Urdu vs Arabic-Indic).
String toLocalizedDigits(int n, String language) =>
    language == 'ur' ? toUrduDigits(n) : toArabicDigits(n);
