import 'package:myapp/models/series.dart';

/// The locally-known navigation surface for a content edition.
///
/// This is deliberately separate from remote feature flags. The edition's
/// [SeriesConfig] describes which content is actually bundled/published;
/// feature flags may roll out unrelated features, but must not manufacture a
/// tab for content that the selected edition cannot serve.
enum SeriesNavigationTab { lectures, read, library, settings }

/// Single source of truth for the series-aware bottom navigation.
///
/// `read` covers both Book and Study: an edition with both gets one "Read"
/// destination with an in-screen Book/Study toggle (see `ReadScreen`) rather
/// than two separate tabs, keeping the bottom nav at 4 destinations even for
/// editions that bundle both. See D1 amendment in the IA roadmap.
abstract final class SeriesNavigationPolicy {
  /// Returns tabs in their production order. Lectures and Settings are always
  /// available; Read is conditional on the edition having a book and/or study
  /// mode.
  static List<SeriesNavigationTab> tabsFor(SeriesConfig series) => [
        for (final tab in SeriesNavigationTab.values)
          if (isAvailable(series, tab)) tab,
      ];

  /// Whether [series] can serve the route/content represented by [tab].
  static bool isAvailable(SeriesConfig series, SeriesNavigationTab tab) =>
      switch (tab) {
        SeriesNavigationTab.lectures => true,
        SeriesNavigationTab.read => series.hasBook || series.hasStudyMode,
        SeriesNavigationTab.library => true,
        SeriesNavigationTab.settings => true,
      };
}
