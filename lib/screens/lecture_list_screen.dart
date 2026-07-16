import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/announcements_bell.dart';
import 'package:myapp/widgets/app_overflow_menu.dart';
import 'package:myapp/widgets/catalog_connect_required.dart';
import 'package:myapp/widgets/catalog_error_body.dart';
import 'package:myapp/widgets/chapter_header.dart';
import 'package:myapp/widgets/continue_listening_banner.dart';
import 'package:myapp/widgets/lecture_tile.dart';

class LectureListScreen extends StatefulWidget {
  const LectureListScreen({super.key});

  @override
  State<LectureListScreen> createState() => _LectureListScreenState();
}

class _LectureListScreenState extends State<LectureListScreen> {
  // The series id we last kicked a catalog load for. Lets us reload exactly
  // once when the active series changes (e.g. restored from prefs or switched
  // after this screen mounted) instead of only loading at initState.
  String? _requestedSeriesId;

  /// Reloads the catalog whenever the active series changes so the displayed
  /// lectures always match the series the rest of the app (nav, chrome) shows
  /// — even when the series is restored from prefs or switched after this
  /// screen first mounted. Fires once per distinct series id; on failure the
  /// error UI's retry button drives re-attempts, so there is no retry loop.
  void _syncCatalogToSeries(BuildContext context) {
    final series = context.watch<SeriesProvider>().currentSeries;
    if (series.id == _requestedSeriesId) return;
    _requestedSeriesId = series.id;

    final catalog = context.read<CatalogProvider>();
    if (catalog.loadedSeriesId == series.id) return; // already in sync

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogProvider>().load(series);
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncCatalogToSeries(context);
    return Scaffold(
      body: Consumer<CatalogProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            CatalogStatus.idle || CatalogStatus.loading => _buildLoading(),
            CatalogStatus.error => provider.needsOnlineToLoad
                ? _buildConnectRequired(provider)
                : _buildError(provider.error!, provider),
            CatalogStatus.loaded => _buildList(provider.catalog!),
          };
        },
      ),
    );
  }

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(null),
        SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: context.brandColor),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectRequired(CatalogProvider provider) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(null),
        SliverFillRemaining(
          child: CatalogConnectRequiredBody(provider: provider),
        ),
      ],
    );
  }

  Widget _buildError(String message, CatalogProvider provider) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(null),
        SliverFillRemaining(
          child: CatalogErrorBody(
            icon: Icons.wifi_off_rounded,
            title: context.l10n.couldNotLoadLectures,
            message: message,
            onRetry: () => provider.load(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(null),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 52,
                    color: context.mutedIconColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.lecturesEmpty,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(Catalog catalog) {
    final lectures = catalog.lectures;
    if (lectures.isEmpty) return _buildEmpty();

    final items = <_ListItem>[];
    if (catalog.chapters.isEmpty) {
      // Flat series (e.g. standalone duroos) — no chapter headers.
      for (final lecture in lectures) {
        items.add(_ListItem.lecture(lecture));
      }
    } else {
      for (final chapter in catalog.chapters) {
        items.add(_ListItem.chapter(chapter));
        for (final lecture in catalog.lecturesForChapter(chapter.id)) {
          items.add(_ListItem.lecture(lecture));
        }
      }
    }

    return CustomScrollView(
      slivers: [
        _buildAppBar(catalog),
        // Resume-where-you-left-off, atop the list. Self-hides when there's
        // nothing to resume (the retired Home tab's only keeper).
        const SliverToBoxAdapter(child: ContinueListeningBanner()),
        SliverToBoxAdapter(
          child: Selector<ProgressProvider, bool>(
            selector: (_, p) => p.allComplete(lectures),
            builder: (_, allComplete, child) =>
                allComplete ? child! : const SizedBox.shrink(),
            child: const _AllLecturesCompleteBanner(),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              if (item.isChapter) {
                return ChapterHeader(
                  chapter: item.chapter!,
                  chapterLectures: catalog.lecturesForChapter(item.chapter!.id),
                );
              }
              // Divider sits between consecutive lectures only — suppressed on
              // the last lecture of a chapter (next item is a header) and at
              // the very end of the list, so no hairline dangles.
              final hasLectureBelow =
                  index < items.length - 1 && !items[index + 1].isChapter;
              return Column(
                children: [
                  LectureTile(
                    lecture: item.lecture!,
                    onTap: () => _onLectureTap(item.lecture!, lectures),
                  ),
                  if (hasLectureBelow)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 16,
                      color: context.dividerColor,
                    ),
                ],
              );
            },
            childCount: items.length,
          ),
        ),
        // Bottom padding that adapts to whether the mini player is visible.
        // Uses a Selector widget so context.select is properly inside a build method.
        SliverToBoxAdapter(
          child: Selector<PlayerNotifier, bool>(
            selector: (_, p) => p.hasAudio,
            builder: (_, hasAudio, __) => SizedBox(height: hasAudio ? 80 : 24),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(Catalog? catalog) {
    // Watch the language so the resolved title/speaker refresh when the user
    // switches UI language while this screen is on-screen.
    final lang = context.watch<LanguageProvider>();
    final series = context.read<SeriesProvider>().currentSeries;
    final isArabicContent = catalog != null && series.isRtl;

    final title = catalog != null
        ? lang.resolveForSeries(catalog.book.title, series)
        : context.l10n.appTitle;
    final speaker = catalog != null
        ? lang.resolveForSeries(catalog.book.speaker, series)
        : '';
    // No Arabic/English fork here: isRtl is `language == 'ar'`, so the Urdu
    // edition took the English branch and read "45 lectures · 23h 19m" directly
    // above badges numbered ۰۱. Wording comes from the ARB (canonical), digits
    // from the edition.
    final countLine = catalog == null
        ? ''
        : context.digitsForSeries(
            context.l10n.lecturesCount(
              catalog.book.lectureCount,
              context.hoursMinutesForSeries(catalog.book.totalDurationSeconds),
            ),
          );

    Widget maybeRtl(Widget child) => isArabicContent
        ? Directionality(textDirection: TextDirection.rtl, child: child)
        : child;

    // Each series shows its own teacher's portrait (Urdu → Shaikh Abdullah
    // Nasir Rahmani, Arabic → Shaikh Salih al-Fawzan).
    final teacherAsset = series.isRtl
        ? 'assets/images/sheikh_fawzan.png'
        : 'assets/images/sheikh-abdullah-nasir-rahmani.jpg';

    // Teacher-led hero: the portrait anchors a title · speaker · stats stack.
    // Bottom-aligned so it sits clear of the ⋮ that floats top-right, and it
    // collapses away on scroll (a compact title fades into the pinned bar).
    final hero = catalog == null
        ? null
        : SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TeacherAvatar(asset: teacherAsset),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: isArabicContent
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              textAlign:
                                  isArabicContent ? TextAlign.right : null,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            if (speaker.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                speaker,
                                textAlign:
                                    isArabicContent ? TextAlign.right : null,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.secondaryTextColor,
                                ),
                              ),
                            ],
                            if (countLine.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _StatsChip(label: countLine),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      expandedHeight: catalog != null ? 172 : 80,
      automaticallyImplyLeading: false,
      actions: const [AnnouncementsBell(), AppOverflowMenu()],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // The bar is collapsed once its height shrinks to the pinned toolbar.
          // Read the live extent from the sliver's own settings (no MediaQuery).
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final collapsed = constraints.maxHeight <=
              (settings?.minExtent ?? kToolbarHeight) + 12;

          // No catalog yet → keep the plain docked app title (loading state).
          // With a catalog, the title lives in the hero; only dock a compact
          // title once collapsed so it survives scrolling the list.
          final Widget? flexTitle = catalog == null
              ? Text(
                  title,
                  style: context.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                )
              : collapsed
                  ? Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    )
                  : null;

          return FlexibleSpaceBar(
            centerTitle: false,
            titlePadding:
                const EdgeInsetsDirectional.only(start: 16, bottom: 14),
            title: flexTitle == null ? null : maybeRtl(flexTitle),
            background: hero == null ? null : maybeRtl(hero),
          );
        },
      ),
    );
  }

  void _onLectureTap(Lecture lecture, List<Lecture> queue) {
    context.read<PlayerNotifier>().loadAndPlay(lecture, queue);
    context.push('/player');
  }
}

/// A circular portrait of the series' teacher, shown in the Lectures hero —
/// Shaikh Abdullah Nasir Rahmani for the Urdu duroos, Shaikh Salih al-Fawzan
/// for the Arabic. The asset is chosen per series by [_buildAppBar].
class _TeacherAvatar extends StatelessWidget {
  final String asset;

  const _TeacherAvatar({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(asset, fit: BoxFit.cover),
    );
  }
}

/// A subtle pill for the "N lectures · Hh Mm" line, set off from the title and
/// speaker. The wrapping [Directionality] mirrors the icon/label for Arabic.
class _StatsChip extends StatelessWidget {
  final String label;

  const _StatsChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 13, color: context.brandColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListItem {
  final Chapter? chapter;
  final Lecture? lecture;
  bool get isChapter => chapter != null;

  const _ListItem.chapter(Chapter c)
      : chapter = c,
        lecture = null;
  const _ListItem.lecture(Lecture l)
      : lecture = l,
        chapter = null;
}

class _AllLecturesCompleteBanner extends StatelessWidget {
  const _AllLecturesCompleteBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.brandColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.brandColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.brandColor.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: context.brandColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.allLecturesComplete,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.brandColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.allLecturesCompleteMessage,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
