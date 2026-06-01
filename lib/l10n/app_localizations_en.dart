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
  String get tabSaved => 'Saved';

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
  String get settingsLanguage => 'Language';

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
  String get settingsAbout => 'About';

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
  String get startListening => 'Start Listening';

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
}
