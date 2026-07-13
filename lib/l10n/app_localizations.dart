import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('ur'),
    Locale.fromSubtags(languageCode: 'ur', scriptCode: 'roman')
  ];

  /// No description provided for @tabLectures.
  ///
  /// In en, this message translates to:
  /// **'Lectures'**
  String get tabLectures;

  /// No description provided for @tabBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get tabBook;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabStudyMode.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get tabStudyMode;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharah Kitab at-Tawheed'**
  String get appTitle;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @allLecturesComplete.
  ///
  /// In en, this message translates to:
  /// **'All Lectures Complete'**
  String get allLecturesComplete;

  /// No description provided for @allLecturesCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'You have listened to every lecture. May Allah bless you with beneficial knowledge.'**
  String get allLecturesCompleteMessage;

  /// No description provided for @continueListening.
  ///
  /// In en, this message translates to:
  /// **'Continue Listening'**
  String get continueListening;

  /// No description provided for @continueListeningEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start a lecture to resume here'**
  String get continueListeningEmpty;

  /// No description provided for @listenedDuration.
  ///
  /// In en, this message translates to:
  /// **'{listened} listened · {remaining} left'**
  String listenedDuration(String listened, String remaining);

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(int percent);

  /// No description provided for @dailyBenefit.
  ///
  /// In en, this message translates to:
  /// **'Daily Benefit'**
  String get dailyBenefit;

  /// No description provided for @studyMode.
  ///
  /// In en, this message translates to:
  /// **'Study Mode'**
  String get studyMode;

  /// No description provided for @studyModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{studied} of {total} classes studied'**
  String studyModeSubtitle(int studied, int total);

  /// No description provided for @studyContinueClass.
  ///
  /// In en, this message translates to:
  /// **'Continue {title}'**
  String studyContinueClass(String title);

  /// No description provided for @studyStartClass.
  ///
  /// In en, this message translates to:
  /// **'Start {title}'**
  String studyStartClass(String title);

  /// No description provided for @studyAllComplete.
  ///
  /// In en, this message translates to:
  /// **'All classes studied — review anytime'**
  String get studyAllComplete;

  /// No description provided for @studyOpenOverview.
  ///
  /// In en, this message translates to:
  /// **'Open study overview'**
  String get studyOpenOverview;

  /// No description provided for @studyClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get studyClasses;

  /// No description provided for @studyCouldNotLoadClasses.
  ///
  /// In en, this message translates to:
  /// **'Could not load classes'**
  String get studyCouldNotLoadClasses;

  /// No description provided for @studyRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart {title}?'**
  String studyRestartTitle(String title);

  /// No description provided for @studyRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'This class is already studied. Restart from the first part?'**
  String get studyRestartMessage;

  /// No description provided for @studyRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get studyRestart;

  /// No description provided for @studyOverallComplete.
  ///
  /// In en, this message translates to:
  /// **'You have completed the full series.'**
  String get studyOverallComplete;

  /// No description provided for @studyOverallInProgress.
  ///
  /// In en, this message translates to:
  /// **'Work through each class in order at your own pace.'**
  String get studyOverallInProgress;

  /// No description provided for @studyOverallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get studyOverallProgress;

  /// No description provided for @studyClassComplete.
  ///
  /// In en, this message translates to:
  /// **'Class Complete'**
  String get studyClassComplete;

  /// No description provided for @studyClassCompleteFallback.
  ///
  /// In en, this message translates to:
  /// **'Class complete'**
  String get studyClassCompleteFallback;

  /// No description provided for @studyCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get studyCompletedLabel;

  /// No description provided for @studyCelebrationMessage.
  ///
  /// In en, this message translates to:
  /// **'May Allah increase you in beneficial knowledge.'**
  String get studyCelebrationMessage;

  /// No description provided for @studyContinueToNext.
  ///
  /// In en, this message translates to:
  /// **'Continue to {title}'**
  String studyContinueToNext(String title);

  /// No description provided for @studySeriesComplete.
  ///
  /// In en, this message translates to:
  /// **'Series Complete'**
  String get studySeriesComplete;

  /// No description provided for @studySeriesCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Series Completed!'**
  String get studySeriesCompleteTitle;

  /// No description provided for @studySeriesCompleteCelebration.
  ///
  /// In en, this message translates to:
  /// **'You have studied every class in the series. May Allah make it a source of lasting benefit for you.'**
  String get studySeriesCompleteCelebration;

  /// No description provided for @studyNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next Up'**
  String get studyNextUp;

  /// No description provided for @studyBackToOverview.
  ///
  /// In en, this message translates to:
  /// **'Back to Study Mode'**
  String get studyBackToOverview;

  /// No description provided for @studyStatusStudied.
  ///
  /// In en, this message translates to:
  /// **'Studied'**
  String get studyStatusStudied;

  /// No description provided for @studyStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get studyStatusInProgress;

  /// No description provided for @studyStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get studyStatusNotStarted;

  /// No description provided for @studyStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get studyStart;

  /// No description provided for @studyYourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get studyYourProgress;

  /// No description provided for @studyRecommendedNext.
  ///
  /// In en, this message translates to:
  /// **'Recommended next'**
  String get studyRecommendedNext;

  /// No description provided for @studyPartsComplete.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} parts complete'**
  String studyPartsComplete(int completed, int total);

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get saved;

  /// No description provided for @savedCount.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks ({count})'**
  String savedCount(int count);

  /// No description provided for @noSavedLectures.
  ///
  /// In en, this message translates to:
  /// **'No bookmarked lectures yet'**
  String get noSavedLectures;

  /// No description provided for @noSavedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark icon in the player to save a lecture'**
  String get noSavedHint;

  /// No description provided for @couldNotLoadLectures.
  ///
  /// In en, this message translates to:
  /// **'Could not load lectures'**
  String get couldNotLoadLectures;

  /// No description provided for @lecturesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lectures available yet'**
  String get lecturesEmpty;

  /// No description provided for @bookCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load the book'**
  String get bookCouldNotLoad;

  /// No description provided for @bookShareChapter.
  ///
  /// In en, this message translates to:
  /// **'Share chapter'**
  String get bookShareChapter;

  /// No description provided for @bookDecreaseText.
  ///
  /// In en, this message translates to:
  /// **'Decrease text size'**
  String get bookDecreaseText;

  /// No description provided for @bookIncreaseText.
  ///
  /// In en, this message translates to:
  /// **'Increase text size'**
  String get bookIncreaseText;

  /// No description provided for @bookColorKey.
  ///
  /// In en, this message translates to:
  /// **'Color key'**
  String get bookColorKey;

  /// No description provided for @bookLegendVerse.
  ///
  /// In en, this message translates to:
  /// **'Qur\'an verse'**
  String get bookLegendVerse;

  /// No description provided for @bookLegendCitation.
  ///
  /// In en, this message translates to:
  /// **'Reference (surah:ayah)'**
  String get bookLegendCitation;

  /// No description provided for @bookLegendHadith.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get bookLegendHadith;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @catalogConnectToLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to load lectures'**
  String get catalogConnectToLoadTitle;

  /// No description provided for @catalogConnectToLoadMessage.
  ///
  /// In en, this message translates to:
  /// **'Open the app once with internet so lecture titles and audio links can download. Lectures you already saved on this device will still play offline.'**
  String get catalogConnectToLoadMessage;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get settingsSeries;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get settingsLightMode;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsVisitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get settingsVisitWebsite;

  /// No description provided for @settingsBookFontSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsBookFontSize;

  /// No description provided for @settingsVersionCopied.
  ///
  /// In en, this message translates to:
  /// **'Version copied'**
  String get settingsVersionCopied;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get settingsPlaybackSpeed;

  /// No description provided for @settingsApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsApp;

  /// No description provided for @settingsContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get settingsContactUs;

  /// No description provided for @settingsShareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get settingsShareApp;

  /// No description provided for @settingsRateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate on Play Store'**
  String get settingsRateApp;

  /// No description provided for @settingsYouTubeChannel.
  ///
  /// In en, this message translates to:
  /// **'YouTube channel'**
  String get settingsYouTubeChannel;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @statLectures.
  ///
  /// In en, this message translates to:
  /// **'Lectures'**
  String get statLectures;

  /// No description provided for @statClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get statClasses;

  /// No description provided for @statDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get statDuration;

  /// No description provided for @statOfflineReady.
  ///
  /// In en, this message translates to:
  /// **'Offline Ready'**
  String get statOfflineReady;

  /// No description provided for @settingsAboutArabicTitle.
  ///
  /// In en, this message translates to:
  /// **'شرح کتاب التوحید'**
  String get settingsAboutArabicTitle;

  /// No description provided for @settingsAboutStats.
  ///
  /// In en, this message translates to:
  /// **'{lectures} Lectures · {classes} Classes · {duration}'**
  String settingsAboutStats(int lectures, int classes, String duration);

  /// No description provided for @settingsAboutDescriptionLine1.
  ///
  /// In en, this message translates to:
  /// **'Complete Audio Series on Kitab at-Tawheed.'**
  String get settingsAboutDescriptionLine1;

  /// No description provided for @settingsAboutDescriptionLine2.
  ///
  /// In en, this message translates to:
  /// **'The Foundation of Islamic Monotheism.'**
  String get settingsAboutDescriptionLine2;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAboutVersion(String version);

  /// No description provided for @settingsAboutLine.
  ///
  /// In en, this message translates to:
  /// **'{count} lectures · {appName}'**
  String settingsAboutLine(int count, String appName);

  /// No description provided for @settingsAboutBy.
  ///
  /// In en, this message translates to:
  /// **'{lecturer}'**
  String settingsAboutBy(String lecturer);

  /// No description provided for @settingsDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsDownloads;

  /// No description provided for @settingsNoDownloads.
  ///
  /// In en, this message translates to:
  /// **'No lectures downloaded'**
  String get settingsNoDownloads;

  /// No description provided for @settingsDownloadsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, one{lecture} other{lectures}} downloaded'**
  String settingsDownloadsCount(int count);

  /// No description provided for @settingsClearDownloads.
  ///
  /// In en, this message translates to:
  /// **'Clear all downloads'**
  String get settingsClearDownloads;

  /// No description provided for @settingsStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{size} used'**
  String settingsStorageUsed(String size);

  /// No description provided for @downloadForOffline.
  ///
  /// In en, this message translates to:
  /// **'Download for offline'**
  String get downloadForOffline;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get deleteDownload;

  /// No description provided for @deleteDownloadMessage.
  ///
  /// In en, this message translates to:
  /// **'{title} will be removed from offline storage.'**
  String deleteDownloadMessage(String title);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clearAllDownloads.
  ///
  /// In en, this message translates to:
  /// **'Clear all downloads?'**
  String get clearAllDownloads;

  /// No description provided for @clearAllDownloadsMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, one{lecture} other{lectures}} ({size}) will be deleted from this device.'**
  String clearAllDownloadsMessage(int count, String size);

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAll;

  /// No description provided for @changeSeriesConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change language?'**
  String get changeSeriesConfirmTitle;

  /// No description provided for @changeSeriesConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You are switching to \"{seriesName}\". Your progress, downloads, and bookmarks are kept separately for each language — you can switch back anytime.'**
  String changeSeriesConfirmMessage(String seriesName);

  /// No description provided for @changeSeriesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get changeSeriesConfirm;

  /// No description provided for @startListening.
  ///
  /// In en, this message translates to:
  /// **'Start Listening'**
  String get startListening;

  /// No description provided for @chooseSeriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Series'**
  String get chooseSeriesTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUrdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get languageUrdu;

  /// No description provided for @languageRomanUrdu.
  ///
  /// In en, this message translates to:
  /// **'Roman Urdu'**
  String get languageRomanUrdu;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get languageHindi;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @audioLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioLabel;

  /// No description provided for @partsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} part} other{{count} parts}}'**
  String partsCount(int count);

  /// No description provided for @lecturesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lectures · {duration}'**
  String lecturesCount(int count, String duration);

  /// No description provided for @offlineSourceSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline'**
  String get offlineSourceSaved;

  /// No description provided for @offlineSourceStreaming.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get offlineSourceStreaming;

  /// No description provided for @offlineNotAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Not available offline'**
  String get offlineNotAvailableOffline;

  /// No description provided for @offlineBadge.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineBadge;

  /// No description provided for @retryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get retryDownload;

  /// No description provided for @offlineNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get offlineNoConnection;

  /// No description provided for @offlineConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get offlineConnectionLost;

  /// No description provided for @offlineDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String offlineDownloading(int percent);

  /// No description provided for @offlineDownloadLecture.
  ///
  /// In en, this message translates to:
  /// **'Download lecture · {size} MB'**
  String offlineDownloadLecture(String size);

  /// No description provided for @offlineCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get offlineCancelDownload;

  /// No description provided for @offlineRemoveDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get offlineRemoveDownload;

  /// No description provided for @offlineManageDownloads.
  ///
  /// In en, this message translates to:
  /// **'Manage downloads'**
  String get offlineManageDownloads;

  /// No description provided for @offlineNextBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available offline'**
  String get offlineNextBlockedTitle;

  /// No description provided for @offlineNextBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'\'{title}\' isn\'t saved. Download it when you\'re back online.'**
  String offlineNextBlockedBody(String title);

  /// No description provided for @offlineNextBlockedQueued.
  ///
  /// In en, this message translates to:
  /// **'\'{title}\' will download when you\'re back online.'**
  String offlineNextBlockedQueued(String title);

  /// No description provided for @offlineNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Download this lecture to listen offline.'**
  String get offlineNotDownloaded;

  /// No description provided for @offlineLibrary.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get offlineLibrary;

  /// No description provided for @offlineLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get offlineLibraryEmpty;

  /// No description provided for @offlineLibraryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the download icon on any lecture to listen offline'**
  String get offlineLibraryEmptyHint;

  /// No description provided for @viewOfflineLibrary.
  ///
  /// In en, this message translates to:
  /// **'View downloads'**
  String get viewOfflineLibrary;

  /// No description provided for @downloadOnWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Download on Wi-Fi only'**
  String get downloadOnWifiOnly;

  /// No description provided for @downloadOnWifiOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Pause downloads on mobile data'**
  String get downloadOnWifiOnlyHint;

  /// No description provided for @wifiOnlyBlocked.
  ///
  /// In en, this message translates to:
  /// **'Connect to Wi-Fi to download'**
  String get wifiOnlyBlocked;

  /// No description provided for @downloadChapterAll.
  ///
  /// In en, this message translates to:
  /// **'Download chapter (~{size} MB)'**
  String downloadChapterAll(String size);

  /// No description provided for @cancelChapterDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel chapter download'**
  String get cancelChapterDownload;

  /// No description provided for @offlineChapterProgress.
  ///
  /// In en, this message translates to:
  /// **'{downloaded} of {total} parts saved'**
  String offlineChapterProgress(int downloaded, int total);

  /// No description provided for @deleteChapter.
  ///
  /// In en, this message translates to:
  /// **'Remove chapter'**
  String get deleteChapter;

  /// No description provided for @downloadRemaining.
  ///
  /// In en, this message translates to:
  /// **'Download remaining'**
  String get downloadRemaining;

  /// No description provided for @deleteChapterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove all saved parts?'**
  String get deleteChapterConfirm;

  /// No description provided for @offlinePrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Download next {count} {count, plural, =1{part} other{parts}} offline'**
  String offlinePrepTitle(int count);

  /// No description provided for @offlinePrepSize.
  ///
  /// In en, this message translates to:
  /// **'~{size} MB'**
  String offlinePrepSize(String size);

  /// No description provided for @offlinePrepSave.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get offlinePrepSave;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get downloadComplete;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'ur':
      {
        switch (locale.scriptCode) {
          case 'roman':
            return AppLocalizationsUrRoman();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
