import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/screens/offline_library_screen.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/section_tab_header.dart';

/// The two collections Library holds.
enum LibraryTab {
  bookmarks,
  downloads;

  /// The `?tab=` query value, or null for anything unrecognised.
  static LibraryTab? fromQuery(String? value) => switch (value) {
        'bookmarks' => bookmarks,
        'downloads' => downloads,
        _ => null,
      };
}

/// Where a user finds content they have explicitly kept: Bookmarks and
/// Downloads, as two tabs under one plain title.
///
/// Mounted in two places, both rendering this same widget:
///  * the shell's Library branch (`/library?tab=…`), which is stateful so the
///    selected tab survives switches to other destinations; and
///  * the root-navigator legacy routes `/bookmarks` and `/offline-library`
///    (pushed from Player and the offline sheet), as [standalone] adapters with
///    a back button and the matching [initialTab].
///
/// A null [initialTab] means "no preference" and keeps the current tab.
class LibraryScreen extends StatefulWidget {
  final LibraryTab? initialTab;

  /// True for the pushed legacy routes: adds a back button and leaves the URL
  /// alone, since there is no shell location to mirror the tab into.
  final bool standalone;

  const LibraryScreen({super.key, this.initialTab, this.standalone = false});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Catalog? _backfilledCatalog;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>().catalog;
    if (catalog != null && !identical(catalog, _backfilledCatalog)) {
      _backfilledCatalog = catalog;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<ProgressProvider>()
            .backfillBookmarkMetadata(catalog.lectures);
        context
            .read<DownloadsProvider>()
            .backfillDownloadedMetadata(catalog.lectures);
      });
    }
    final l10n = context.l10n;
    final downloadsEnabled =
        context.watch<FeatureFlagsProvider>().features.downloads;
    final bookmarkCount =
        context.watch<ProgressProvider>().bookmarkedIds.length;
    final downloadCount = context.watch<DownloadsProvider>().downloadedCount;

    return Scaffold(
      body: downloadsEnabled
          ? _LibraryTabs(
              initialTab: widget.initialTab,
              standalone: widget.standalone,
              bookmarkCount: bookmarkCount,
              downloadCount: downloadCount,
            )
          // A single destination needs no tab bar: just the title and the
          // Bookmarks body.
          : Column(
              children: [
                SectionTabHeader(
                  key: WidgetKeys.libraryHeader,
                  title: l10n.tabLibrary,
                  showBack: widget.standalone,
                ),
                const Expanded(child: BookmarksBody()),
              ],
            ),
    );
  }
}

class _LibraryTabs extends StatefulWidget {
  final LibraryTab? initialTab;
  final bool standalone;
  final int bookmarkCount;
  final int downloadCount;

  const _LibraryTabs({
    required this.initialTab,
    required this.standalone,
    required this.bookmarkCount,
    required this.downloadCount,
  });

  @override
  State<_LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<_LibraryTabs>
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
      length: LibraryTab.values.length,
      vsync: this,
      initialIndex: _syncedIndex,
    )..addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(_LibraryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new `?tab=` link (e.g. the offline banner) while Library is alive.
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

  /// Mirrors a user-chosen tab into `/library?tab=…`. Without this the
  /// location would keep the last link's tab, and repeating that link (the
  /// offline banner is always on screen while offline) would be a no-op for
  /// the router once the user had moved to the other tab.
  void _onTabChanged() {
    if (_controller.indexIsChanging) return;
    final index = _controller.index;
    if (index == _syncedIndex) return;
    _syncedIndex = index;
    if (widget.standalone) return;
    context.go('/library?tab=${LibraryTab.values[index].name}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        SectionTabHeader(
          key: WidgetKeys.libraryHeader,
          title: l10n.tabLibrary,
          showBack: widget.standalone,
          controller: _controller,
          tabs: [
            SectionTab(
              label: l10n.saved,
              count: widget.bookmarkCount,
              tabKey: WidgetKeys.libraryTabBookmarks,
            ),
            SectionTab(
              label: l10n.offlineLibrary,
              count: widget.downloadCount,
              tabKey: WidgetKeys.libraryTabDownloads,
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: const [
              _KeepAlive(child: BookmarksBody()),
              _KeepAlive(child: _DownloadsTab()),
            ],
          ),
        ),
      ],
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

/// The Downloads collection, topped by "remove all" once there is something
/// to remove.
class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final count = downloads.downloadedCount;
    final l10n = context.l10n;
    final error = context.colorScheme.error;

    return Column(
      children: [
        if (count > 0)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, top: 4),
              child: TextButton.icon(
                key: WidgetKeys.libraryRemoveAllDownloads,
                style: TextButton.styleFrom(
                  foregroundColor: error,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: Text(l10n.settingsClearDownloads),
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: l10n.clearAllDownloads,
                    message: l10n.clearAllDownloadsMessage(
                      count,
                      context.localizedDecimal(
                        _formatBytes(downloads.totalDownloadedBytes),
                      ),
                    ),
                    confirmLabel: l10n.deleteAll,
                    destructive: true,
                  );
                  if (confirmed && context.mounted) {
                    await context.read<DownloadsProvider>().deleteAll();
                  }
                },
              ),
            ),
          ),
        const Expanded(child: OfflineLibraryBody()),
      ],
    );
  }
}
