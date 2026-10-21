import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/section_tab_header.dart';

/// The two things Read holds.
enum ReadTab {
  book,
  study;

  /// The `?tab=` query value, or null for anything unrecognised.
  static ReadTab? fromQuery(String? value) => switch (value) {
        'book' => book,
        'study' => study,
        _ => null,
      };
}

/// The shell home for reading and studying the book — Book and Study merged
/// into one destination under a single plain header ("Read", the book's name
/// beside it, then underline tabs), the same pattern as Library. See D1
/// amendment in the IA roadmap.
///
/// The tab bar exists only when the edition has both: a book-only edition
/// (Arabic) or a study-only edition shows its one body under just the title.
///
/// A null [initialTab] means "no preference" and keeps the current tab.
class ReadScreen extends StatelessWidget {
  final ReadTab? initialTab;

  const ReadScreen({super.key, this.initialTab});

  @override
  Widget build(BuildContext context) {
    final series = context.watch<SeriesProvider>().currentSeries;
    final hasBook = series.hasBook;
    final hasStudy = series.hasStudyMode;

    return Scaffold(
      body: hasBook && hasStudy
          ? _ReadTabs(initialTab: initialTab)
          : Column(
              children: [
                _ReadHeader(series: series),
                Expanded(
                  child: hasBook
                      ? const BookChapterListBody()
                      : hasStudy
                          ? const StudyBody()
                          : const SizedBox.shrink(),
                ),
              ],
            ),
    );
  }
}

class _ReadTabs extends StatefulWidget {
  final ReadTab? initialTab;

  const _ReadTabs({required this.initialTab});

  @override
  State<_ReadTabs> createState() => _ReadTabsState();
}

class _ReadTabsState extends State<_ReadTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  /// The tab index the location (or the initial tab) already reflects, so a
  /// settled change is mirrored into the URL exactly once.
  late int _syncedIndex;

  @override
  void initState() {
    super.initState();
    _syncedIndex = widget.initialTab?.index ?? 0;
    _controller = TabController(
      length: ReadTab.values.length,
      vsync: this,
      initialIndex: _syncedIndex,
    )..addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(_ReadTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new `?tab=` link (e.g. Study completion's "Back to overview") while
    // Read is alive.
    final requested = widget.initialTab;
    if (requested != null &&
        requested != oldWidget.initialTab &&
        requested.index != _controller.index) {
      _syncedIndex = requested.index;
      _controller.animateTo(requested.index);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  /// Mirrors a user-chosen tab into `/read?tab=…`, for the same reason as
  /// Library: otherwise the location keeps the last link's tab and repeating
  /// that link is a router no-op that leaves the user on the other tab.
  void _onTabChanged() {
    if (_controller.indexIsChanging) return;
    final index = _controller.index;
    if (index == _syncedIndex) return;
    _syncedIndex = index;
    context.go('/read?tab=${ReadTab.values[index].name}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final series = context.watch<SeriesProvider>().currentSeries;
    return Column(
      children: [
        _ReadHeader(
          series: series,
          controller: _controller,
          tabs: [
            SectionTab(label: l10n.tabBook, tabKey: WidgetKeys.readTabBook),
            SectionTab(
              label: l10n.tabStudyMode,
              tabKey: WidgetKeys.readTabStudy,
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: const [
              _KeepAlive(child: BookChapterListBody()),
              _KeepAlive(child: StudyBody()),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Read", with the book's name (in the book's own script and font) as a quiet
/// subtitle once it has loaded and the edition has a book.
class _ReadHeader extends StatelessWidget {
  final SeriesConfig series;
  final TabController? controller;
  final List<SectionTab> tabs;

  const _ReadHeader({
    required this.series,
    this.controller,
    this.tabs = const [],
  });

  @override
  Widget build(BuildContext context) {
    final bookTitle =
        series.hasBook ? context.watch<BookProvider>().book?.title : null;
    return SectionTabHeader(
      key: WidgetKeys.readHeader,
      title: context.l10n.tabRead,
      subtitle: bookTitle,
      subtitleDirection: TextDirection.rtl,
      subtitleStyle: context.textTheme.bodyMedium?.copyWith(
        color: context.secondaryTextColor,
        fontFamily: series.bookFontFamily,
        // Nastaliq stacks tall: a tight line height clips its marks.
        height: series.language == 'ur' ? 1.9 : null,
      ),
      controller: controller,
      tabs: tabs,
    );
  }
}

/// Keeps a tab's list (and its scroll position) alive while the other tab is
/// showing.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
