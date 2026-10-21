import 'package:flutter/foundation.dart';

/// Stable semantic keys for controls exercised by on-device tests.
///
/// Keep these values independent of translated copy. Dynamic keys use stable
/// domain identifiers (for example a series id), never a localized label.
abstract final class WidgetKeys {
  static const welcomeStartListening = ValueKey<String>(
    'welcome.start-listening',
  );
  static const startupInteractiveMarker = ValueKey<String>(
    'startup.interactive-marker',
  );

  static ValueKey<String> chooseSeriesCard(String seriesId) =>
      ValueKey<String>('choose-series.card.$seriesId');

  static const shellLecturesTab = ValueKey<String>('shell.tab.lectures');
  static const shellReadTab = ValueKey<String>('shell.tab.read');
  static const shellLibraryTab = ValueKey<String>('shell.tab.library');
  static const shellSettingsTab = ValueKey<String>('shell.tab.settings');

  static const offlineStatusBanner = ValueKey<String>(
    'shell.offline-status-banner',
  );

  static const libraryHeader = ValueKey<String>('library.header');
  static const libraryTabBookmarks = ValueKey<String>('library.tab.bookmarks');
  static const libraryTabDownloads = ValueKey<String>('library.tab.downloads');
  static const libraryRemoveAllDownloads = ValueKey<String>(
    'library.remove-all-downloads',
  );

  static const readHeader = ValueKey<String>('read.header');
  static const readTabBook = ValueKey<String>('read.tab.book');
  static const readTabStudy = ValueKey<String>('read.tab.study');

  static const playerClose = ValueKey<String>('player.close');
  static const playerBookmark = ValueKey<String>('player.bookmark');
  static const playerDownload = ValueKey<String>('player.download');
  static const playerShare = ValueKey<String>('player.share');
  static const playerOfflineStatus = ValueKey<String>('player.offline-status');
  static const playerTransportControls = ValueKey<String>(
    'player.transport-controls',
  );

  static const offlineDownloadLecture = ValueKey<String>(
    'offline.download-lecture',
  );
  static const offlineCancelDownload = ValueKey<String>(
    'offline.cancel-download',
  );
  static const offlineRemoveDownload = ValueKey<String>(
    'offline.remove-download',
  );
  static const offlineDownloadChapter = ValueKey<String>(
    'offline.download-chapter',
  );
  static const offlineCancelChapter = ValueKey<String>(
    'offline.cancel-chapter',
  );
  static const offlineManageDownloads = ValueKey<String>(
    'offline.manage-downloads',
  );

  // The Offline-library row left Settings (it lives in Library › Downloads).
  // Kept only so integration_test/support/app_flow.dart still compiles until
  // its P6T update repoints `openOfflineLibraryFromSettings`; nothing in lib/
  // attaches it any more.
  static const settingsOfflineLibrary = ValueKey<String>(
    'settings.offline-library',
  );
  static const settingsDownloadsHint = ValueKey<String>(
    'settings.downloads-hint',
  );
  static const settingsDownloadOnWifiOnly = ValueKey<String>(
    'settings.download-on-wifi-only',
  );
  static ValueKey<String> settingsSeriesOption(String seriesId) =>
      ValueKey<String>('settings.series-option.$seriesId');

  static const settingsReadingSection = ValueKey<String>('settings.reading');
  static const settingsTextSize = ValueKey<String>('settings.text-size');
  static const settingsTextSizeDecrease = ValueKey<String>(
    'settings.text-size.decrease',
  );
  static const settingsTextSizeIncrease = ValueKey<String>(
    'settings.text-size.increase',
  );
  static const settingsTextSizeValue = ValueKey<String>(
    'settings.text-size.value',
  );
  static const settingsTextSizeSlider = ValueKey<String>(
    'settings.text-size.slider',
  );
  static const settingsTextSizePreview = ValueKey<String>(
    'settings.text-size.preview',
  );

  static const settingsAbout = ValueKey<String>('settings.about');
  static const settingsShareApp = ValueKey<String>('settings.share-app');
  static const settingsContactUs = ValueKey<String>('settings.contact-us');
  static const settingsRateApp = ValueKey<String>('settings.rate-app');
  static const settingsYouTube = ValueKey<String>('settings.youtube');

  static const settingsOtherAppsSection = ValueKey<String>(
    'settings.other-apps',
  );
  static ValueKey<String> settingsOtherApp(String packageId) =>
      ValueKey<String>('settings.other-app.$packageId');

  static const readerTextSize = ValueKey<String>('reader.text-size');
}
