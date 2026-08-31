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
  static const shellBookTab = ValueKey<String>('shell.tab.book');
  static const shellStudyTab = ValueKey<String>('shell.tab.study');
  static const shellSettingsTab = ValueKey<String>('shell.tab.settings');

  static const offlineStatusBanner = ValueKey<String>(
    'shell.offline-status-banner',
  );

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

  static const settingsOfflineLibrary = ValueKey<String>(
    'settings.offline-library',
  );
  static const settingsDownloadOnWifiOnly = ValueKey<String>(
    'settings.download-on-wifi-only',
  );
  static ValueKey<String> settingsSeriesOption(String seriesId) =>
      ValueKey<String>('settings.series-option.$seriesId');
}
