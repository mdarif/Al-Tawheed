import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/testing/widget_keys.dart';

void main() {
  test('high-value controls have stable, distinct key values', () {
    final keys = <ValueKey<String>>[
      WidgetKeys.welcomeStartListening,
      WidgetKeys.shellLecturesTab,
      WidgetKeys.shellBookTab,
      WidgetKeys.shellStudyTab,
      WidgetKeys.shellSettingsTab,
      WidgetKeys.playerClose,
      WidgetKeys.playerBookmark,
      WidgetKeys.playerDownload,
      WidgetKeys.playerShare,
      WidgetKeys.playerOfflineStatus,
      WidgetKeys.playerTransportControls,
      WidgetKeys.offlineDownloadLecture,
      WidgetKeys.offlineCancelDownload,
      WidgetKeys.offlineRemoveDownload,
      WidgetKeys.offlineDownloadChapter,
      WidgetKeys.offlineCancelChapter,
      WidgetKeys.offlineManageDownloads,
      WidgetKeys.settingsOfflineLibrary,
      WidgetKeys.settingsDownloadOnWifiOnly,
    ];

    expect(keys.map((key) => key.value).toSet(), hasLength(keys.length));
    expect(
      WidgetKeys.chooseSeriesCard('urdu'),
      equals(WidgetKeys.chooseSeriesCard('urdu')),
    );
    expect(
      WidgetKeys.chooseSeriesCard('urdu'),
      isNot(equals(WidgetKeys.chooseSeriesCard('arabic'))),
    );
    expect(
      WidgetKeys.settingsSeriesOption('urdu'),
      isNot(equals(WidgetKeys.settingsSeriesOption('arabic'))),
    );
  });
}
