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
  String studyContinueClass(String title) {
    return '$title جاری رکھیں';
  }

  @override
  String studyStartClass(String title) {
    return '$title شروع کریں';
  }

  @override
  String get studyAllComplete => 'تمام دروس مکمل — کسی بھی وقت دوبارہ دیکھیں';

  @override
  String get studyOpenOverview => 'تعلیمی جائزہ کھولیں';

  @override
  String get studyClasses => 'دروس';

  @override
  String get studyCouldNotLoadClasses => 'دروس لوڈ نہیں ہو سکے';

  @override
  String studyRestartTitle(String title) {
    return '$title دوبارہ شروع کریں؟';
  }

  @override
  String get studyRestartMessage =>
      'یہ درس پہلے ہی پڑھا جا چکا ہے۔ پہلے حصے سے دوبارہ شروع کریں؟';

  @override
  String get studyRestart => 'دوبارہ شروع';

  @override
  String get studyOverallComplete => 'آپ نے مکمل سلسلہ مکمل کر لیا ہے۔';

  @override
  String get studyOverallInProgress =>
      'ہر درس کو ترتیب سے اپنے وقت پر مکمل کریں۔';

  @override
  String get studyClassComplete => 'درس مکمل';

  @override
  String studyClassCompleteTitle(String title) {
    return '$title مکمل';
  }

  @override
  String get studyClassCompleteFallback => 'درس مکمل';

  @override
  String get studyWellDone => 'بہت خوب — اپنے وقت پر آگے بڑھتے رہیں۔';

  @override
  String studyContinueToNext(String title) {
    return '$title پر جاری رکھیں';
  }

  @override
  String get studyBackToOverview => 'تعلیمی جائزے پر واپس';

  @override
  String get studyStatusStudied => 'پڑھا ہوا';

  @override
  String get studyStatusInProgress => 'جاری';

  @override
  String get studyStatusNotStarted => 'شروع نہیں';

  @override
  String get studyRecommendedNext => 'اگلا تجویز شدہ';

  @override
  String studyPartsComplete(int completed, int total) {
    return '$total میں سے $completed حصے مکمل';
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
  String get settingsAppearance => 'ظاہری شکل';

  @override
  String get settingsDarkMode => 'ڈارک موڈ';

  @override
  String get settingsLightMode => 'لائٹ موڈ';

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
  String get settingsAboutArabicTitle => 'شرح کتاب التوحید';

  @override
  String settingsAboutStats(int lectures, int classes, String duration) {
    return '$lectures دروس · $classes کلاسیں · $duration';
  }

  @override
  String get settingsAboutDescriptionLine1 => 'کتاب التوحید پر مکمل آڈیو سلسلہ';

  @override
  String get settingsAboutDescriptionLine2 => 'اسلامی توحید کی بنیاد';

  @override
  String settingsAboutVersion(String version) {
    return 'ورژن $version';
  }

  @override
  String settingsAboutLine(int count, String appName) {
    return '$count دروس · $appName';
  }

  @override
  String settingsAboutBy(String lecturer) {
    return '$lecturer کی طرف سے';
  }

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

/// The translations for Urdu (`ur_roman`).
class AppLocalizationsUrRoman extends AppLocalizationsUr {
  AppLocalizationsUrRoman() : super('ur_roman');

  @override
  String get tabLectures => 'Duroos';

  @override
  String get tabHome => 'Home';

  @override
  String get tabSaved => 'Mehfooz';

  @override
  String get tabSettings => 'Tarteebat';

  @override
  String get appTitle => 'Sharah Kitab al-Tawheed';

  @override
  String get nowPlaying => 'Abhi chal raha hai';

  @override
  String get continueListening => 'Sunna Jari Rakhein';

  @override
  String get continueListeningEmpty =>
      'Yahan se jari rakhne ke liye koi dars shuru karein';

  @override
  String listenedDuration(String listened, String remaining) {
    return '$listened suna · $remaining baqi';
  }

  @override
  String percentComplete(int percent) {
    return '$percent% mukammal';
  }

  @override
  String get dailyBenefit => 'Rozana Faida';

  @override
  String get studyMode => 'Taleemi Tareeqa';

  @override
  String studyModeSubtitle(int studied, int total) {
    return '$total mein se $studied daras parhe';
  }

  @override
  String studyContinueClass(String title) {
    return '$title jari rakhein';
  }

  @override
  String studyStartClass(String title) {
    return '$title shuru karein';
  }

  @override
  String get studyAllComplete =>
      'Tamam daras mukammal — kisi bhi waqt dobara dekhein';

  @override
  String get studyOpenOverview => 'Taleemi jaiza kholen';

  @override
  String get studyClasses => 'Dars';

  @override
  String get studyCouldNotLoadClasses => 'Dars load nahin ho sake';

  @override
  String studyRestartTitle(String title) {
    return '$title dobara shuru karein?';
  }

  @override
  String get studyRestartMessage =>
      'Yeh dars pehle hi parha ja chuka hai. Pehle hisse se dobara shuru karein?';

  @override
  String get studyRestart => 'Dobara shuru';

  @override
  String get studyOverallComplete =>
      'Aap ne mukammal silsila mukammal kar liya hai.';

  @override
  String get studyOverallInProgress =>
      'Har dars ko tarteeb se apne waqt par mukammal karein.';

  @override
  String get studyClassComplete => 'Dars mukammal';

  @override
  String studyClassCompleteTitle(String title) {
    return '$title mukammal';
  }

  @override
  String get studyClassCompleteFallback => 'Dars mukammal';

  @override
  String get studyWellDone => 'Bohat khoob — apne waqt par aage barhte rahein.';

  @override
  String studyContinueToNext(String title) {
    return '$title par jari rakhein';
  }

  @override
  String get studyBackToOverview => 'Taleemi jaize par wapas';

  @override
  String get studyStatusStudied => 'Parha hua';

  @override
  String get studyStatusInProgress => 'Jari';

  @override
  String get studyStatusNotStarted => 'Shuru nahin';

  @override
  String get studyRecommendedNext => 'Agla tajweez shuda';

  @override
  String studyPartsComplete(int completed, int total) {
    return '$total mein se $completed hisse mukammal';
  }

  @override
  String get saved => 'Mehfooz';

  @override
  String savedCount(int count) {
    return 'Mehfooz ($count)';
  }

  @override
  String get noSavedLectures => 'Abhi tak koi dars mehfooz nahin';

  @override
  String get noSavedHint =>
      'Koi dars mehfooz karne ke liye player mein bookmark icon par tap karein';

  @override
  String get couldNotLoadLectures => 'Dars load nahin ho sake';

  @override
  String get retry => 'Dobara koshish karein';

  @override
  String get settingsLanguage => 'Zabaan';

  @override
  String get settingsAppearance => 'Zahiri shakl';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsLightMode => 'Light mode';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsPlaybackSpeed => 'Playback raftaar';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsContactUs => 'Hum se rabta karein';

  @override
  String get settingsShareApp => 'App share karein';

  @override
  String get settingsRateApp => 'Play Store par rating dein';

  @override
  String get settingsAbout => 'App ke baare mein';

  @override
  String get settingsAboutArabicTitle => 'شرح کتاب التوحید';

  @override
  String settingsAboutStats(int lectures, int classes, String duration) {
    return '$lectures Lectures · $classes Classes · $duration';
  }

  @override
  String get settingsAboutDescriptionLine1 =>
      'Complete Audio Series on Kitab al-Tawheed.';

  @override
  String get settingsAboutDescriptionLine2 =>
      'The Foundation of Islamic Monotheism.';

  @override
  String settingsAboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String settingsAboutLine(int count, String appName) {
    return '$count dars · $appName';
  }

  @override
  String settingsAboutBy(String lecturer) {
    return '$lecturer ki taraf se';
  }

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String get settingsNoDownloads => 'Koi dars download nahin';

  @override
  String settingsDownloadsCount(int count) {
    return '$count dars download shuda';
  }

  @override
  String get settingsClearDownloads => 'Tamam download hata dein';

  @override
  String settingsStorageUsed(String size) {
    return '$size istemaal';
  }

  @override
  String get downloadForOffline => 'Offline ke liye download karein';

  @override
  String get deleteDownload => 'Download hata dein?';

  @override
  String deleteDownloadMessage(String title) {
    return '$title device se hata diya jayega.';
  }

  @override
  String get delete => 'Hata dein';

  @override
  String get cancel => 'Mansookh';

  @override
  String get clearAllDownloads => 'Tamam download hata dein?';

  @override
  String clearAllDownloadsMessage(int count, String size) {
    return '$count dars ($size) is device se hata diye jayenge.';
  }

  @override
  String get deleteAll => 'Sab hata dein';

  @override
  String get startListening => 'Sunna shuru karein';

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
    return '$count hisse';
  }

  @override
  String lecturesCount(int count, String duration) {
    return '$count dars · $duration';
  }
}
