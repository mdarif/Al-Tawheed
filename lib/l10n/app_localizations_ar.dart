// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get tabLectures => 'الدروس';

  @override
  String get tabBook => 'الكتاب';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabStudyMode => 'الدراسة';

  @override
  String get tabSettings => 'الإعدادات';

  @override
  String get appTitle => 'شرح كتاب التوحيد';

  @override
  String get nowPlaying => 'يُشغَّل الآن';

  @override
  String get bookmark => 'إضافة إشارة مرجعية';

  @override
  String get removeBookmark => 'إزالة الإشارة المرجعية';

  @override
  String get playbackPrevious => 'الدرس السابق';

  @override
  String get playbackRewind => 'إرجاع ١٠ ثوانٍ';

  @override
  String get playbackPlay => 'تشغيل';

  @override
  String get playbackPause => 'إيقاف مؤقت';

  @override
  String get playbackForward => 'تقديم ١٠ ثوانٍ';

  @override
  String get playbackNext => 'الدرس التالي';

  @override
  String get allLecturesComplete => 'اكتملت جميع الدروس';

  @override
  String get allLecturesCompleteMessage =>
      'لقد استمعتَ إلى جميع الدروس. بارك الله لك في علمك.';

  @override
  String get continueListening => 'متابعة الاستماع';

  @override
  String get continueListeningEmpty => 'ابدأ درسًا للمتابعة من هنا';

  @override
  String listenedDuration(String listened, String remaining) {
    return '$listened مستمَع · $remaining متبقٍّ';
  }

  @override
  String percentComplete(int percent) {
    return '$percent% مكتمل';
  }

  @override
  String get dailyBenefit => 'فائدة اليوم';

  @override
  String get studyMode => 'وضع الدراسة';

  @override
  String studyModeSubtitle(int studied, int total) {
    return '$studied من $total درسًا مدروسًا';
  }

  @override
  String studyContinueClass(String title) {
    return 'متابعة $title';
  }

  @override
  String studyStartClass(String title) {
    return 'بدء $title';
  }

  @override
  String get studyAllComplete => 'تمّت دراسة جميع الدروس — راجعها في أيّ وقت';

  @override
  String get studyOpenOverview => 'فتح نظرة عامة على الدراسة';

  @override
  String get studyClasses => 'الدروس';

  @override
  String get studyCouldNotLoadClasses => 'تعذّر تحميل الدروس';

  @override
  String studyRestartTitle(String title) {
    return 'إعادة بدء $title؟';
  }

  @override
  String get studyRestartMessage =>
      'تمّت دراسة هذا الدرس بالفعل. هل تريد البدء من الجزء الأول مجدّدًا؟';

  @override
  String get studyRestart => 'إعادة البدء';

  @override
  String get studyOverallComplete => 'أتممتَ السلسلة بالكامل.';

  @override
  String get studyOverallInProgress => 'تدرّج في كلّ درس بوتيرتك الخاصة.';

  @override
  String get studyOverallProgress => 'التقدم الكلّي';

  @override
  String get studyClassComplete => 'اكتمل الدرس';

  @override
  String get studyClassCompleteFallback => 'اكتمل الدرس';

  @override
  String get studyCompletedLabel => 'مكتمل';

  @override
  String get studyCelebrationMessage => 'زادك الله علمًا نافعًا.';

  @override
  String studyContinueToNext(String title) {
    return 'الانتقال إلى $title';
  }

  @override
  String get studySeriesComplete => 'اكتملت السلسلة';

  @override
  String get studySeriesCompleteTitle => '!اكتملت السلسلة';

  @override
  String get studySeriesCompleteCelebration =>
      'لقد أتممتَ دراسة جميع الدروس في السلسلة. جعله الله علمًا نافعًا لك.';

  @override
  String get studyNextUp => 'التالي';

  @override
  String get studyBackToOverview => 'العودة إلى وضع الدراسة';

  @override
  String get studyStatusStudied => 'مدروس';

  @override
  String get studyStatusInProgress => 'قيد الدراسة';

  @override
  String get studyStatusNotStarted => 'لم يُبدأ بعد';

  @override
  String get studyStart => 'ابدأ';

  @override
  String get studyYourProgress => 'تقدّمك';

  @override
  String get studyRecommendedNext => 'الموصى به تاليًا';

  @override
  String studyPartsComplete(int completed, int total) {
    return '$completed من $total جزء مكتمل';
  }

  @override
  String get saved => 'المحفوظات';

  @override
  String savedCount(int count) {
    return 'المحفوظات ($count)';
  }

  @override
  String get noSavedLectures => 'لا توجد دروس محفوظة بعد';

  @override
  String get noSavedHint => 'اضغط أيقونة الإشارة المرجعية في المشغّل لحفظ درس';

  @override
  String get couldNotLoadLectures => 'تعذّر تحميل الدروس';

  @override
  String get lecturesEmpty => 'لا توجد دروس متاحة بعد';

  @override
  String get bookCouldNotLoad => 'تعذّر تحميل الكتاب';

  @override
  String get bookShareChapter => 'مشاركة الباب';

  @override
  String get shareLecture => 'مشاركة المحاضرة';

  @override
  String get bookReportIssue => 'الإبلاغ عن خطأ';

  @override
  String get bookReportIssueSubject => 'كتاب التوحيد — تصويب في الكتاب';

  @override
  String get bookReportIssueIntro =>
      'يُرجى وصف الخطأ أدناه، مع نقل الكلمات المحيطة به إن أمكن. أبقِ التفاصيل في الأسفل — فهي تدلّنا على الصفحة المقصودة بالضبط.';

  @override
  String bookReportIssueCopied(String email) {
    return 'تطبيق البريد غير متاح — تم نسخ التقرير. أرسله إلى $email.';
  }

  @override
  String get bookColorKey => 'مفتاح الألوان';

  @override
  String get bookLegendVerse => 'آية قرآنية';

  @override
  String get bookLegendCitation => 'مرجع (سورة:آية)';

  @override
  String get bookLegendHadith => 'حديث';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get catalogConnectToLoadTitle => 'اتصل بالإنترنت لتحميل الدروس';

  @override
  String get catalogConnectToLoadMessage =>
      'افتح التطبيق مرة واحدة مع الإنترنت لتنزيل عناوين الدروس وروابط الصوت. ستعمل الدروس التي حفظتها على جهازك دون اتصال.';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsAppLanguage => 'لغة التطبيق';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsSeries => 'السلسلة';

  @override
  String get settingsDarkMode => 'الوضع الداكن';

  @override
  String get settingsLightMode => 'الوضع الفاتح';

  @override
  String get settingsThemeSystem => 'اتبع النظام';

  @override
  String get settingsVisitWebsite => 'الموقع الرسمي';

  @override
  String get settingsBookFontSize => 'حجم الخط';

  @override
  String get settingsVersionCopied => 'تم نسخ الإصدار';

  @override
  String get settingsPlayback => 'التشغيل';

  @override
  String get settingsPlaybackSpeed => 'سرعة التشغيل';

  @override
  String get settingsApp => 'التطبيق';

  @override
  String get settingsContactUs => 'اتصل بنا';

  @override
  String get settingsShareApp => 'مشاركة التطبيق';

  @override
  String get settingsRateApp => 'تقييم في متجر Play';

  @override
  String get settingsYouTubeChannel => 'قناة يوتيوب';

  @override
  String get settingsAbout => 'حول';

  @override
  String get statLectures => 'الدروس';

  @override
  String get statClasses => 'الصفوف';

  @override
  String get statDuration => 'المدة';

  @override
  String get statOfflineReady => 'متاح بلا إنترنت';

  @override
  String get settingsAboutArabicTitle => 'شرح كتاب التوحيد';

  @override
  String settingsAboutStats(int lectures, int classes, String duration) {
    return '$lectures درسًا · $classes صفًا · $duration';
  }

  @override
  String get settingsAboutDescriptionLine1 =>
      'سلسلة صوتية كاملة على كتاب التوحيد.';

  @override
  String get settingsAboutDescriptionLine2 => 'أساس التوحيد في الإسلام.';

  @override
  String settingsAboutVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String settingsAboutLine(int count, String appName) {
    return '$count درسًا · $appName';
  }

  @override
  String settingsAboutBy(String lecturer) {
    return '$lecturer';
  }

  @override
  String get settingsDownloads => 'التنزيلات';

  @override
  String get settingsNoDownloads => 'لا توجد دروس محمَّلة';

  @override
  String settingsDownloadsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دروس محمَّلة',
      one: '$count درس محمَّل',
    );
    return '$_temp0';
  }

  @override
  String get settingsClearDownloads => 'مسح جميع التنزيلات';

  @override
  String settingsStorageUsed(String size) {
    return '$size مستخدَم';
  }

  @override
  String get downloadForOffline => 'تنزيل للاستماع بلا إنترنت';

  @override
  String get deleteDownload => 'حذف التنزيل؟';

  @override
  String deleteDownloadMessage(String title) {
    return 'سيتم حذف $title من التخزين غير المتصل.';
  }

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get clearAllDownloads => 'مسح جميع التنزيلات؟';

  @override
  String clearAllDownloadsMessage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دروس',
      one: '$count درس',
    );
    return '$_temp0 ($size) سيتم حذفها من هذا الجهاز.';
  }

  @override
  String get deleteAll => 'حذف الكل';

  @override
  String get changeSeriesConfirmTitle => 'تغيير اللغة؟';

  @override
  String changeSeriesConfirmMessage(String seriesName) {
    return 'ستنتقل إلى \"$seriesName\". يُحفظ تقدّمك والتنزيلات والعلامات المرجعية لكل لغة بشكل منفصل — ويمكنك العودة في أيّ وقت.';
  }

  @override
  String get changeSeriesConfirm => 'تغيير';

  @override
  String get startListening => 'ابدأ الاستماع';

  @override
  String get chooseSeriesTitle => 'ابدأ رحلتك مع التوحيد';

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
  String get audioLabel => 'صوتي';

  @override
  String partsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أجزاء',
      one: '$count جزء',
    );
    return '$_temp0';
  }

  @override
  String lecturesCount(int count, String duration) {
    return '$count درس · $duration';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours س $minutes د';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes د';
  }

  @override
  String get offlineSourceSaved => 'محفوظ بلا إنترنت';

  @override
  String get offlineSourceStreaming => 'يُبثّ مباشرةً';

  @override
  String get offlineNotAvailableOffline => 'غير متاح بلا إنترنت';

  @override
  String get offlineBadge => 'بلا إنترنت';

  @override
  String get retryDownload => 'إعادة التنزيل';

  @override
  String get offlineNoConnection => 'لا يوجد اتصال';

  @override
  String get offlineConnectionLost => 'انقطع الاتصال';

  @override
  String offlineDownloading(int percent) {
    return 'جارٍ التنزيل… $percent%';
  }

  @override
  String offlineDownloadLecture(String size) {
    return 'تنزيل الدرس · $size ميغابايت';
  }

  @override
  String get offlineCancelDownload => 'إلغاء التنزيل';

  @override
  String get offlineRemoveDownload => 'إزالة التنزيل';

  @override
  String get offlineManageDownloads => 'إدارة التنزيلات';

  @override
  String get offlineNextBlockedTitle => 'غير متاح بلا إنترنت';

  @override
  String offlineNextBlockedBody(String title) {
    return '\'$title\' غير محفوظ. نزّله عند عودة الاتصال.';
  }

  @override
  String offlineNextBlockedQueued(String title) {
    return '\'$title\' سيُنزَّل عند عودة الاتصال.';
  }

  @override
  String get offlineNotDownloaded => 'نزّل هذا الدرس للاستماع بلا إنترنت.';

  @override
  String get offlineLibrary => 'التنزيلات';

  @override
  String get offlineLibraryEmpty => 'لا توجد تنزيلات بعد';

  @override
  String get offlineLibraryEmptyHint =>
      'اضغط أيقونة التنزيل على أي درس للاستماع بلا إنترنت';

  @override
  String get viewOfflineLibrary => 'عرض التنزيلات';

  @override
  String get downloadOnWifiOnly => 'التنزيل عبر Wi-Fi فقط';

  @override
  String get downloadOnWifiOnlyHint => 'إيقاف التنزيل على بيانات الجوال';

  @override
  String get wifiOnlyBlocked => 'اتصل بـ Wi-Fi للتنزيل';

  @override
  String downloadChapterAll(String size) {
    return 'تنزيل الباب (~$size ميغابايت)';
  }

  @override
  String get cancelChapterDownload => 'إلغاء تنزيل الباب';

  @override
  String offlineChapterProgress(int downloaded, int total) {
    return '$downloaded من $total جزء محفوظ';
  }

  @override
  String get deleteChapter => 'إزالة الباب';

  @override
  String get downloadRemaining => 'تنزيل الباقي';

  @override
  String get deleteChapterConfirm => 'إزالة جميع الأجزاء المحفوظة؟';

  @override
  String offlinePrepTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تنزيل $count أجزاء التالية بلا إنترنت',
      one: 'تنزيل الجزء التالي بلا إنترنت',
    );
    return '$_temp0';
  }

  @override
  String offlinePrepSize(String size) {
    return '~$size ميغابايت';
  }

  @override
  String get offlinePrepSave => 'تنزيل';

  @override
  String get downloadComplete => 'اكتمل التنزيل';
}
