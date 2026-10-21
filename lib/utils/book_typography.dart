// Script-aware typography shared by the book reader and the text-size preview,
// so the preview in Settings and the reader's "Aa" sheet paints a line exactly
// as the reader does.

/// Urdu uses letters (ک گ چ پ ژ ٹ ڈ ڑ ں ھ ہ ی ے) that Qur'anic Arabic never
/// does, so a run's script is unambiguous. Arabic (verses, hadith, narrator
/// prose) renders in Naskh; Urdu (translation, sharah, masā'il) in the series
/// font (Nastaliq), which also needs more generous leading.
final RegExp bookUrduLetters = RegExp(r'[کگچپژٹڈڑںھہیے]');

/// Font for Arabic runs in every edition's book.
const String bookArabicFontFamily = 'NotoNaskhArabic';

/// Noto Nastaliq Urdu renders visually larger than Noto Naskh Arabic at the
/// same point size, so Urdu is scaled to sit level with the Arabic matn.
/// Tunable: raise toward 1.0 for larger Urdu, lower for smaller.
const double bookUrduSizeFactor = 0.78;

/// Line leading follows the taller script present (Nastaliq needs more).
const double bookUrduLineHeight = 2.0;
const double bookArabicLineHeight = 1.8;
