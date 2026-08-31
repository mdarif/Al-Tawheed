import 'package:myapp/models/series.dart';

/// The locally-known navigation surface for a content edition.
///
/// This is deliberately separate from remote feature flags. The edition's
/// [SeriesConfig] describes which content is actually bundled/published;
/// feature flags may roll out unrelated features, but must not manufacture a
/// tab for content that the selected edition cannot serve.
enum SeriesNavigationTab { lectures, book, study, settings }

/// Single source of truth for the series-aware bottom navigation.
abstract final class SeriesNavigationPolicy {
  /// Returns tabs in their production order. Lectures and Settings are always
  /// available; Book and Study are conditional on the edition capabilities.
  static List<SeriesNavigationTab> tabsFor(SeriesConfig series) => [
    for (final tab in SeriesNavigationTab.values)
      if (isAvailable(series, tab)) tab,
  ];

  /// Whether [series] can serve the route/content represented by [tab].
  static bool isAvailable(SeriesConfig series, SeriesNavigationTab tab) =>
      switch (tab) {
        SeriesNavigationTab.lectures => true,
        SeriesNavigationTab.book => series.hasBook,
        SeriesNavigationTab.study => series.hasStudyMode,
        SeriesNavigationTab.settings => true,
      };
}
