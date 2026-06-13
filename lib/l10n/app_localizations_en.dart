// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabLectures => 'Lectures';

  @override
  String get tabHome => 'Home';

  @override
  String get tabStudyMode => 'Study';

  @override
  String get tabSettings => 'Settings';

  @override
  String get appTitle => 'Sharah Kitab al-Tawheed';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get continueListening => 'Continue Listening';

  @override
  String get continueListeningEmpty => 'Start a lecture to resume here';

  @override
  String listenedDuration(String listened, String remaining) {
    return '$listened listened · $remaining left';
  }

  @override
  String percentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get dailyBenefit => 'Daily Benefit';

  @override
  String get studyMode => 'Study Mode';

  @override
  String studyModeSubtitle(int studied, int total) {
    return '$studied of $total classes studied';
  }

  @override
  String studyContinueClass(String title) {
    return 'Continue $title';
  }

  @override
  String studyStartClass(String title) {
    return 'Start $title';
  }

  @override
  String get studyAllComplete => 'All classes studied — review anytime';

  @override
  String get studyOpenOverview => 'Open study overview';

  @override
  String get studyClasses => 'Classes';

  @override
  String get studyCouldNotLoadClasses => 'Could not load classes';

  @override
  String studyRestartTitle(String title) {
    return 'Restart $title?';
  }

  @override
  String get studyRestartMessage =>
      'This class is already studied. Restart from the first part?';

  @override
  String get studyRestart => 'Restart';

  @override
  String get studyOverallComplete => 'You have completed the full series.';

  @override
  String get studyOverallInProgress =>
      'Work through each class in order at your own pace.';

  @override
  String get studyOverallProgress => 'Overall Progress';

  @override
  String get studyClassComplete => 'Class Complete';

  @override
  String get studyClassCompleteFallback => 'Class complete';

  @override
  String get studyCompletedLabel => 'Completed';

  @override
  String get studyCelebrationMessage =>
      'May Allah increase you in beneficial knowledge.';

  @override
  String studyContinueToNext(String title) {
    return 'Continue to $title';
  }

  @override
  String get studyNextUp => 'Next Up';

  @override
  String get studyBackToOverview => 'Back to Study Mode';

  @override
  String get studyStatusStudied => 'Studied';

  @override
  String get studyStatusInProgress => 'In progress';

  @override
  String get studyStatusNotStarted => 'Not started';

  @override
  String get studyStart => 'Start';

  @override
  String get studyYourProgress => 'Your progress';

  @override
  String get studyRecommendedNext => 'Recommended next';

  @override
  String studyPartsComplete(int completed, int total) {
    return '$completed of $total parts complete';
  }

  @override
  String get saved => 'Saved';

  @override
  String savedCount(int count) {
    return 'Saved ($count)';
  }

  @override
  String get noSavedLectures => 'No saved lectures yet';

  @override
  String get noSavedHint =>
      'Tap the bookmark icon in the player to save a lecture';

  @override
  String get couldNotLoadLectures => 'Could not load lectures';

  @override
  String get retry => 'Retry';

  @override
  String get catalogConnectToLoadTitle => 'Connect to load lectures';

  @override
  String get catalogConnectToLoadMessage =>
      'Open the app once with internet so lecture titles and audio links can download. Lectures you already saved on this device will still play offline.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsSeries => 'Series';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsLightMode => 'Light mode';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsPlaybackSpeed => 'Playback speed';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsContactUs => 'Contact Us';

  @override
  String get settingsShareApp => 'Share app';

  @override
  String get settingsRateApp => 'Rate on Play Store';

  @override
  String get settingsYouTubeChannel => 'YouTube channel';

  @override
  String get settingsAbout => 'About';

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
    return '$count lectures · $appName';
  }

  @override
  String settingsAboutBy(String lecturer) {
    return 'By $lecturer';
  }

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String get settingsNoDownloads => 'No lectures downloaded';

  @override
  String settingsDownloadsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'lectures',
      one: 'lecture',
    );
    return '$count $_temp0 downloaded';
  }

  @override
  String get settingsClearDownloads => 'Clear all downloads';

  @override
  String settingsStorageUsed(String size) {
    return '$size used';
  }

  @override
  String get downloadForOffline => 'Download for offline';

  @override
  String get deleteDownload => 'Delete download?';

  @override
  String deleteDownloadMessage(String title) {
    return '$title will be removed from offline storage.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearAllDownloads => 'Clear all downloads?';

  @override
  String clearAllDownloadsMessage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'lectures',
      one: 'lecture',
    );
    return '$count $_temp0 ($size) will be deleted from this device.';
  }

  @override
  String get deleteAll => 'Delete all';

  @override
  String get changeSeriesConfirmTitle => 'Change Series?';

  @override
  String changeSeriesConfirmMessage(String seriesName) {
    return 'Switching to \"$seriesName\" changes your active lectures. Your progress, downloads, and bookmarks are saved separately and you can switch back anytime.';
  }

  @override
  String get changeSeriesConfirm => 'Switch';

  @override
  String get startListening => 'Start Listening';

  @override
  String get chooseSeriesTitle => 'Choose Your Series';

  @override
  String get chooseSeriesSubtitle =>
      'Pick the series you\'d like to study. You can change this later in Settings.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts',
      one: '$count part',
    );
    return '$_temp0';
  }

  @override
  String lecturesCount(int count, String duration) {
    return '$count lectures · $duration';
  }

  @override
  String get offlineSourceSaved => 'Saved for offline';

  @override
  String get offlineSourceStreaming => 'Streaming';

  @override
  String get offlineNotAvailableOffline => 'Not available offline';

  @override
  String get offlineBadge => 'Offline';

  @override
  String get retryDownload => 'Retry download';

  @override
  String get offlineNoConnection => 'No connection';

  @override
  String get offlineConnectionLost => 'Connection lost';

  @override
  String offlineDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String offlineDownloadLecture(String size) {
    return 'Download lecture · $size MB';
  }

  @override
  String get offlineCancelDownload => 'Cancel download';

  @override
  String get offlineRemoveDownload => 'Remove download';

  @override
  String get offlineManageDownloads => 'Manage downloads';

  @override
  String get offlineNextBlockedTitle => 'Not available offline';

  @override
  String offlineNextBlockedBody(String title) {
    return '\'$title\' isn\'t saved. Download it when you\'re back online.';
  }

  @override
  String offlineNextBlockedQueued(String title) {
    return '\'$title\' will download when you\'re back online.';
  }

  @override
  String get offlineNotDownloaded => 'Download this lecture to listen offline.';

  @override
  String get offlineLibrary => 'Downloads';

  @override
  String get offlineLibraryEmpty => 'No downloads yet';

  @override
  String get offlineLibraryEmptyHint =>
      'Tap the download icon on any lecture to listen offline';

  @override
  String get viewOfflineLibrary => 'View downloads';

  @override
  String get downloadOnWifiOnly => 'Download on Wi-Fi only';

  @override
  String get downloadOnWifiOnlyHint => 'Pause downloads on mobile data';

  @override
  String get wifiOnlyBlocked => 'Connect to Wi-Fi to download';

  @override
  String downloadChapterAll(String size) {
    return 'Download chapter (~$size MB)';
  }

  @override
  String get cancelChapterDownload => 'Cancel chapter download';

  @override
  String offlineChapterProgress(int downloaded, int total) {
    return '$downloaded of $total parts saved';
  }

  @override
  String get deleteChapter => 'Remove chapter';

  @override
  String get downloadRemaining => 'Download remaining';

  @override
  String get deleteChapterConfirm => 'Remove all saved parts?';

  @override
  String offlinePrepTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'parts',
      one: 'part',
    );
    return 'Download next $count $_temp0 offline';
  }

  @override
  String offlinePrepSize(String size) {
    return '~$size MB';
  }

  @override
  String get offlinePrepSave => 'Download';

  @override
  String get downloadComplete => 'Download complete';
}
