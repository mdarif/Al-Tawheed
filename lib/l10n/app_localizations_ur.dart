// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get tabLectures => 'دروس';

  @override
  String get tabHome => 'ہوم';

  @override
  String get tabSaved => 'محفوظ';

  @override
  String get tabSettings => 'ترتیبات';

  @override
  String get appTitle => 'شرح کتاب التوحید';

  @override
  String get nowPlaying => 'ابھی چل رہا ہے';

  @override
  String get continueListening => 'سننا جاری رکھیں';

  @override
  String get continueListeningEmpty =>
      'یہاں سے جاری رکھنے کے لیے کوئی درس شروع کریں';

  @override
  String listenedDuration(String listened, String remaining) {
    return '$listened سنا · $remaining باقی';
  }

  @override
  String percentComplete(int percent) {
    return '$percent٪ مکمل';
  }

  @override
  String get dailyBenefit => 'روزانہ فائدہ';

  @override
  String get studyMode => 'تعلیمی طریقہ';

  @override
  String studyModeSubtitle(int studied, int total) {
    return '$total میں سے $studied دروس پڑھے';
  }

  @override
  String get saved => 'محفوظ';

  @override
  String savedCount(int count) {
    return 'محفوظ ($count)';
  }

  @override
  String get noSavedLectures => 'ابھی تک کوئی درس محفوظ نہیں';

  @override
  String get noSavedHint =>
      'کوئی درس محفوظ کرنے کے لیے پلیئر میں بُک مارک آئیکن پر ٹیپ کریں';

  @override
  String get couldNotLoadLectures => 'دروس لوڈ نہیں ہو سکے';

  @override
  String get retry => 'دوبارہ کوشش کریں';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsPlayback => 'پلے بیک';

  @override
  String get settingsPlaybackSpeed => 'پلے بیک رفتار';

  @override
  String get settingsApp => 'ایپ';

  @override
  String get settingsContactUs => 'ہم سے رابطہ کریں';

  @override
  String get settingsShareApp => 'ایپ شیئر کریں';

  @override
  String get settingsRateApp => 'پلے اسٹور پر ریٹنگ دیں';

  @override
  String get settingsAbout => 'ایپ کے بارے میں';

  @override
  String get settingsDownloads => 'ڈاؤن لوڈز';

  @override
  String get settingsNoDownloads => 'کوئی درس ڈاؤن لوڈ نہیں';

  @override
  String settingsDownloadsCount(int count) {
    return '$count درس ڈاؤن لوڈ شدہ';
  }

  @override
  String get settingsClearDownloads => 'تمام ڈاؤن لوڈ حذف کریں';

  @override
  String settingsStorageUsed(String size) {
    return '$size استعمال';
  }

  @override
  String get downloadForOffline => 'آف لائن کے لیے ڈاؤن لوڈ کریں';

  @override
  String get deleteDownload => 'ڈاؤن لوڈ حذف کریں؟';

  @override
  String deleteDownloadMessage(String title) {
    return '$title ڈیوائس سے ہٹا دیا جائے گا۔';
  }

  @override
  String get delete => 'حذف کریں';

  @override
  String get cancel => 'منسوخ';

  @override
  String get clearAllDownloads => 'تمام ڈاؤن لوڈ حذف کریں؟';

  @override
  String clearAllDownloadsMessage(int count, String size) {
    return '$count دروس ($size) اس ڈیوائس سے حذف کر دیے جائیں گے۔';
  }

  @override
  String get deleteAll => 'سب حذف کریں';

  @override
  String get startListening => 'سننا شروع کریں';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get languageRomanUrdu => 'Roman Urdu';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get languageArabic => 'العربية';

  @override
  String partsCount(int count) {
    return '$count حصے';
  }

  @override
  String lecturesCount(int count, String duration) {
    return '$count دروس · $duration';
  }
}
