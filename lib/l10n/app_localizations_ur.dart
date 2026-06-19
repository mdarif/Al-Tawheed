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
  String get tabBook => 'کتاب';

  @override
  String get tabHome => 'ہوم';

  @override
  String get tabStudyMode => 'تعلیم';

  @override
  String get tabSettings => 'ترتیبات';

  @override
  String get appTitle => 'شرح کتاب التوحید';

  @override
  String get nowPlaying => 'ابھی چل رہا ہے';

  @override
  String get allLecturesComplete => 'تمام دروس مکمل';

  @override
  String get allLecturesCompleteMessage =>
      'آپ نے تمام دروس سن لیے ہیں۔ اللہ تعالیٰ آپ کو علمِ نافع سے نوازے۔';

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
  String get studyOverallProgress => 'مجموعی پیش رفت';

  @override
  String get studyClassComplete => 'درس مکمل';

  @override
  String get studyClassCompleteFallback => 'درس مکمل';

  @override
  String get studyCompletedLabel => 'مکمل';

  @override
  String get studyCelebrationMessage =>
      'اللہ تعالیٰ آپ کے علمِ نافع میں اضافہ فرمائے۔';

  @override
  String studyContinueToNext(String title) {
    return '$title پر جاری رکھیں';
  }

  @override
  String get studySeriesComplete => 'سلسلہ مکمل';

  @override
  String get studySeriesCompleteTitle => '!سلسلہ مکمل';

  @override
  String get studySeriesCompleteCelebration =>
      'آپ نے سلسلے کے تمام دروس مکمل کر لیے ہیں۔ اللہ تعالیٰ اسے آپ کے لیے نافع علم بنائے۔';

  @override
  String get studyNextUp => 'اگلا درس';

  @override
  String get studyBackToOverview => 'تعلیمی طریقہ پر واپس';

  @override
  String get studyStatusStudied => 'پڑھا ہوا';

  @override
  String get studyStatusInProgress => 'جاری';

  @override
  String get studyStatusNotStarted => 'شروع نہیں';

  @override
  String get studyStart => 'شروع کریں';

  @override
  String get studyYourProgress => 'آپ کی پیش رفت';

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
  String get bookCouldNotLoad => 'کتاب لوڈ نہیں ہو سکی';

  @override
  String get bookShareChapter => 'باب شیئر کریں';

  @override
  String get bookDecreaseText => 'متن چھوٹا کریں';

  @override
  String get bookIncreaseText => 'متن بڑا کریں';

  @override
  String get retry => 'دوبارہ کوشش کریں';

  @override
  String get catalogConnectToLoadTitle =>
      'دروس لوڈ کرنے کے لیے انٹرنیٹ سے جڑیں';

  @override
  String get catalogConnectToLoadMessage =>
      'ایک بار انٹرنیٹ سے جڑ کر ایپ کھولیں تاکہ درسوں کے عنوانات اور آڈیو لنکس لوڈ ہو سکیں۔ پہلے سے محفوظ آڈیو آف لائن چلے گی۔';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsAppearance => 'ظاہری شکل';

  @override
  String get settingsSeries => 'سلسلہ';

  @override
  String get settingsDarkMode => 'ڈارک موڈ';

  @override
  String get settingsLightMode => 'لائٹ موڈ';

  @override
  String get settingsThemeSystem => 'سسٹم کے مطابق';

  @override
  String get settingsVisitWebsite => 'سرکاری ویب سائٹ';

  @override
  String get settingsBookFontSize => 'متن کا سائز';

  @override
  String get settingsVersionCopied => 'ورژن کاپی ہو گیا';

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
  String get settingsYouTubeChannel => 'یوٹیوب چینل';

  @override
  String get settingsAbout => 'ایپ کے بارے میں';

  @override
  String get statLectures => 'دروس';

  @override
  String get statClasses => 'کلاسیں';

  @override
  String get statDuration => 'دورانیہ';

  @override
  String get statOfflineReady => 'آف لائن تیار';

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
    return '$lecturer';
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
  String get changeSeriesConfirmTitle => 'سلسلہ تبدیل کریں؟';

  @override
  String changeSeriesConfirmMessage(String seriesName) {
    return '\"$seriesName\" پر سوئچ کرنے سے آپ کے فعال دروس تبدیل ہو جائیں گے۔ آپ کی پیش رفت، ڈاؤن لوڈز اور بک مارکس الگ الگ محفوظ رہتے ہیں اور آپ کسی بھی وقت واپس جا سکتے ہیں۔';
  }

  @override
  String get changeSeriesConfirm => 'تبدیل کریں';

  @override
  String get startListening => 'سننا شروع کریں';

  @override
  String get chooseSeriesTitle => 'اپنا سفرِ توحید شروع کریں';

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
  String get audioLabel => 'آڈیو';

  @override
  String partsCount(int count) {
    return '$count حصے';
  }

  @override
  String lecturesCount(int count, String duration) {
    return '$count دروس · $duration';
  }

  @override
  String get offlineSourceSaved => 'آف لائن محفوظ';

  @override
  String get offlineSourceStreaming => 'اسٹریمنگ';

  @override
  String get offlineNotAvailableOffline => 'آف لائن دستیاب نہیں';

  @override
  String get offlineBadge => 'آف لائن';

  @override
  String get retryDownload => 'دوبارہ ڈاؤن لوڈ کریں';

  @override
  String get offlineNoConnection => 'کوئی کنکشن نہیں';

  @override
  String get offlineConnectionLost => 'کنکشن ٹوٹ گیا';

  @override
  String offlineDownloading(int percent) {
    return 'ڈاؤن لوڈ ہو رہا ہے… $percent%';
  }

  @override
  String offlineDownloadLecture(String size) {
    return 'درس ڈاؤن لوڈ کریں · $size MB';
  }

  @override
  String get offlineCancelDownload => 'ڈاؤن لوڈ منسوخ کریں';

  @override
  String get offlineRemoveDownload => 'ڈاؤن لوڈ حذف کریں';

  @override
  String get offlineManageDownloads => 'ڈاؤن لوڈز منظم کریں';

  @override
  String get offlineNextBlockedTitle => 'آف لائن دستیاب نہیں';

  @override
  String offlineNextBlockedBody(String title) {
    return '\'$title\' محفوظ نہیں۔ آن لائن آنے پر ڈاؤن لوڈ کریں۔';
  }

  @override
  String offlineNextBlockedQueued(String title) {
    return '\'$title\' آن لائن آنے پر ڈاؤن لوڈ ہوگا۔';
  }

  @override
  String get offlineNotDownloaded =>
      'آف لائن سننے کے لیے یہ درس ڈاؤن لوڈ کریں۔';

  @override
  String get offlineLibrary => 'ڈاؤن لوڈز';

  @override
  String get offlineLibraryEmpty => 'ابھی کوئی ڈاؤن لوڈ نہیں';

  @override
  String get offlineLibraryEmptyHint =>
      'آف لائن سننے کے لیے کسی درس پر ڈاؤن لوڈ آئیکن ٹیپ کریں';

  @override
  String get viewOfflineLibrary => 'ڈاؤن لوڈز دیکھیں';

  @override
  String get downloadOnWifiOnly => 'صرف Wi-Fi پر ڈاؤن لوڈ کریں';

  @override
  String get downloadOnWifiOnlyHint => 'موبائل ڈیٹا پر ڈاؤن لوڈ روکیں';

  @override
  String get wifiOnlyBlocked => 'ڈاؤن لوڈ کے لیے Wi-Fi سے جڑیں';

  @override
  String downloadChapterAll(String size) {
    return 'باب ڈاؤن لوڈ کریں (~$size MB)';
  }

  @override
  String get cancelChapterDownload => 'باب کا ڈاؤن لوڈ منسوخ کریں';

  @override
  String offlineChapterProgress(int downloaded, int total) {
    return '$downloaded از $total حصے محفوظ';
  }

  @override
  String get deleteChapter => 'باب ہٹائیں';

  @override
  String get downloadRemaining => 'باقی ڈاؤن لوڈ کریں';

  @override
  String get deleteChapterConfirm => 'تمام محفوظ حصے ہٹائیں؟';

  @override
  String offlinePrepTitle(int count) {
    return 'اگلے $count حصے ڈاؤن لوڈ کریں';
  }

  @override
  String offlinePrepSize(String size) {
    return '~$size MB';
  }

  @override
  String get offlinePrepSave => 'ڈاؤن لوڈ کریں';

  @override
  String get downloadComplete => 'ڈاؤن لوڈ مکمل';
}

/// The translations for Urdu (`ur_roman`).
class AppLocalizationsUrRoman extends AppLocalizationsUr {
  AppLocalizationsUrRoman() : super('ur_roman');

  @override
  String get tabLectures => 'Duroos';

  @override
  String get tabBook => 'Kitab';

  @override
  String get tabHome => 'Home';

  @override
  String get tabStudyMode => 'Taleem';

  @override
  String get tabSettings => 'Tarteebat';

  @override
  String get appTitle => 'Sharah Kitab al-Tawheed';

  @override
  String get nowPlaying => 'Abhi chal raha hai';

  @override
  String get allLecturesComplete => 'Tamam Daras Mukammal';

  @override
  String get allLecturesCompleteMessage =>
      'Aap ne tamam daras sun liye hain. Allah Ta\'ala aap ko ilm-e-nafe se nawaze.';

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
  String get studyOverallProgress => 'Majmui Pesh Raft';

  @override
  String get studyClassComplete => 'Dars mukammal';

  @override
  String get studyClassCompleteFallback => 'Dars mukammal';

  @override
  String get studyCompletedLabel => 'Mukammal';

  @override
  String get studyCelebrationMessage =>
      'Allah Ta\'ala aap ke ilm-e-nafe mein izafa farmaye.';

  @override
  String studyContinueToNext(String title) {
    return '$title par jari rakhein';
  }

  @override
  String get studySeriesComplete => 'Silsila Mukammal';

  @override
  String get studySeriesCompleteTitle => 'Silsila Mukammal!';

  @override
  String get studySeriesCompleteCelebration =>
      'Aap ne silsile ke tamam daras mukammal kar liye hain. Allah Ta\'ala ise aap ke liye nafe ka ilm banaye.';

  @override
  String get studyNextUp => 'Agla Dars';

  @override
  String get studyBackToOverview => 'Taleemi Tareeqa par wapas';

  @override
  String get studyStatusStudied => 'Parha hua';

  @override
  String get studyStatusInProgress => 'Jari';

  @override
  String get studyStatusNotStarted => 'Shuru nahin';

  @override
  String get studyStart => 'Shuru karein';

  @override
  String get studyYourProgress => 'Aap ki pesh raft';

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
  String get bookCouldNotLoad => 'Kitab load nahin ho saki';

  @override
  String get bookShareChapter => 'Baab share karein';

  @override
  String get bookDecreaseText => 'Text chhota karein';

  @override
  String get bookIncreaseText => 'Text bada karein';

  @override
  String get retry => 'Dobara koshish karein';

  @override
  String get catalogConnectToLoadTitle =>
      'Dars load karne ke liye internet se judein';

  @override
  String get catalogConnectToLoadMessage =>
      'Ek bar internet se judein aur app kholen taake dars ke unwan aur audio links load ho saken. Pehle se mahfooz audio offline chalegi.';

  @override
  String get settingsLanguage => 'Zabaan';

  @override
  String get settingsAppearance => 'Zahiri shakl';

  @override
  String get settingsSeries => 'Silsila';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsLightMode => 'Light mode';

  @override
  String get settingsThemeSystem => 'System ke mutabiq';

  @override
  String get settingsVisitWebsite => 'Official website';

  @override
  String get settingsBookFontSize => 'Text size';

  @override
  String get settingsVersionCopied => 'Version copy ho gaya';

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
  String get settingsYouTubeChannel => 'YouTube channel';

  @override
  String get settingsAbout => 'App ke baare mein';

  @override
  String get statLectures => 'Lectures';

  @override
  String get statClasses => 'Classes';

  @override
  String get statDuration => 'Duration';

  @override
  String get statOfflineReady => 'Offline Ready';

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
    return '$lecturer';
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
  String get changeSeriesConfirmTitle => 'Silsila tabdeel karein?';

  @override
  String changeSeriesConfirmMessage(String seriesName) {
    return '\"$seriesName\" par switch karne se aap ke active dars tabdeel ho jayenge. Aap ki progress, downloads aur bookmarks alag se mahfooz rehte hain aur aap kabhi bhi wapas ja sakte hain.';
  }

  @override
  String get changeSeriesConfirm => 'Tabdeel karein';

  @override
  String get startListening => 'Sunna shuru karein';

  @override
  String get chooseSeriesTitle => 'Apna Safar-e-Tawheed Shuru Karein';

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
  String get audioLabel => 'Audio';

  @override
  String partsCount(int count) {
    return '$count hisse';
  }

  @override
  String lecturesCount(int count, String duration) {
    return '$count dars · $duration';
  }

  @override
  String get offlineSourceSaved => 'Offline محفوظ';

  @override
  String get offlineSourceStreaming => 'Streaming';

  @override
  String get offlineNotAvailableOffline => 'Offline dastiyab nahi';

  @override
  String get offlineBadge => 'Offline';

  @override
  String get retryDownload => 'Dobara download karein';

  @override
  String get offlineNoConnection => 'Koi connection nahi';

  @override
  String get offlineConnectionLost => 'Connection toot gaya';

  @override
  String offlineDownloading(int percent) {
    return 'Download ho raha hai… $percent%';
  }

  @override
  String offlineDownloadLecture(String size) {
    return 'Dars download karein · $size MB';
  }

  @override
  String get offlineCancelDownload => 'Download mansookh karein';

  @override
  String get offlineRemoveDownload => 'Download hata dein';

  @override
  String get offlineManageDownloads => 'Downloads manage karein';

  @override
  String get offlineNextBlockedTitle => 'Offline dastiyab nahi';

  @override
  String offlineNextBlockedBody(String title) {
    return '\'$title\' محفوظ نہیں۔ Online aane par download karein.';
  }

  @override
  String offlineNextBlockedQueued(String title) {
    return '\'$title\' online aane par download hoga.';
  }

  @override
  String get offlineNotDownloaded =>
      'Offline sunne ke liye yeh dars download karein.';

  @override
  String get offlineLibrary => 'Downloads';

  @override
  String get offlineLibraryEmpty => 'Abhi koi download nahi';

  @override
  String get offlineLibraryEmptyHint =>
      'Offline sunne ke liye kisi bhi dars par download icon tap karein';

  @override
  String get viewOfflineLibrary => 'Downloads dekhein';

  @override
  String get downloadOnWifiOnly => 'Sirf Wi-Fi par download karein';

  @override
  String get downloadOnWifiOnlyHint => 'Mobile data par download rokein';

  @override
  String get wifiOnlyBlocked => 'Download ke liye Wi-Fi se judein';

  @override
  String downloadChapterAll(String size) {
    return 'Chapter download karein (~$size MB)';
  }

  @override
  String get cancelChapterDownload => 'Chapter download mansookh karein';

  @override
  String offlineChapterProgress(int downloaded, int total) {
    return '$downloaded az $total hisse mahfooz';
  }

  @override
  String get deleteChapter => 'Chapter hata dein';

  @override
  String get downloadRemaining => 'Baqi download karein';

  @override
  String get deleteChapterConfirm => 'Tamam mahfooz hisse hata dein?';

  @override
  String offlinePrepTitle(int count) {
    return 'Aglay $count hisse download karein';
  }

  @override
  String offlinePrepSize(String size) {
    return '~$size MB';
  }

  @override
  String get offlinePrepSave => 'Download karein';

  @override
  String get downloadComplete => 'Download mukammal';
}
