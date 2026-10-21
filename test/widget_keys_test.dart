import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/testing/widget_keys.dart';

void main() {
  test('high-value controls have stable, distinct key values', () {
    final keys = <ValueKey<String>>[
      WidgetKeys.welcomeStartListening,
      WidgetKeys.startupInteractiveMarker,
      WidgetKeys.shellLecturesTab,
      WidgetKeys.shellReadTab,
      WidgetKeys.shellLibraryTab,
      WidgetKeys.shellSettingsTab,
      WidgetKeys.offlineStatusBanner,
      WidgetKeys.libraryHeader,
      WidgetKeys.libraryTabBookmarks,
      WidgetKeys.libraryTabDownloads,
      WidgetKeys.libraryRemoveAllDownloads,
      WidgetKeys.readHeader,
      WidgetKeys.readTabBook,
      WidgetKeys.readTabStudy,
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
      WidgetKeys.settingsDownloadsHint,
      WidgetKeys.settingsReadingSection,
      WidgetKeys.settingsTextSize,
      WidgetKeys.settingsTextSizeDecrease,
      WidgetKeys.settingsTextSizeIncrease,
      WidgetKeys.settingsTextSizeValue,
      WidgetKeys.settingsTextSizeSlider,
      WidgetKeys.settingsTextSizePreview,
      WidgetKeys.settingsAbout,
      WidgetKeys.settingsShareApp,
      WidgetKeys.settingsContactUs,
      WidgetKeys.settingsRateApp,
      WidgetKeys.settingsYouTube,
      WidgetKeys.settingsOtherAppsSection,
      WidgetKeys.readerTextSize,
      WidgetKeys.lecturesSearchAction,
      WidgetKeys.searchBack,
      WidgetKeys.searchField,
      WidgetKeys.searchClear,
      WidgetKeys.searchIdle,
      WidgetKeys.searchLoading,
      WidgetKeys.searchResults,
      WidgetKeys.searchNoResults,
      WidgetKeys.searchUnavailable,
      WidgetKeys.searchError,
      WidgetKeys.searchResultCount,
      WidgetKeys.searchSectionClasses,
      WidgetKeys.searchSectionLectures,
      WidgetKeys.searchRetry,
      WidgetKeys.searchOpenDownloads,
      WidgetKeys.searchClearAction,
      WidgetKeys.searchBrowseClasses,
      WidgetKeys.searchClassGrid,
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
    expect(
      WidgetKeys.settingsOtherApp('com.almarfa.alquran'),
      equals(WidgetKeys.settingsOtherApp('com.almarfa.alquran')),
    );
    expect(
      WidgetKeys.settingsOtherApp('com.almarfa.alquran'),
      isNot(equals(WidgetKeys.settingsOtherApp('com.almarfa.assunnah'))),
    );

    // Search and chapter-jump keys that carry a domain id (never a label).
    expect(
      WidgetKeys.searchClassCell('class-01'),
      equals(WidgetKeys.searchClassCell('class-01')),
    );
    expect(
      WidgetKeys.searchClassCell('class-01'),
      isNot(equals(WidgetKeys.searchClassCell('class-02'))),
    );
    expect(
      WidgetKeys.searchClassRow('class-01'),
      isNot(equals(WidgetKeys.searchClassCell('class-01'))),
    );
    expect(
      WidgetKeys.searchLectureRow('lec-001'),
      isNot(equals(WidgetKeys.searchLectureRow('lec-002'))),
    );
    expect(
      WidgetKeys.searchChip('12'),
      isNot(equals(WidgetKeys.searchChip('Part 03'))),
    );
    expect(
      WidgetKeys.lecturesChapterHeader('class-15'),
      equals(WidgetKeys.lecturesChapterHeader('class-15')),
    );
    expect(
      WidgetKeys.lecturesChapterHeader('class-15'),
      isNot(equals(WidgetKeys.lecturesChapterHeader('class-14'))),
    );
  });
}
