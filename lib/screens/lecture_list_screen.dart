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
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/catalog_connect_required.dart';
import 'package:myapp/widgets/catalog_error_body.dart';
import 'package:myapp/widgets/chapter_header.dart';
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
    final countLine = catalog == null
        ? ''
        : isArabicContent
            ? '${toArabicDigits(catalog.book.lectureCount)} محاضرة · '
                '${DurationFormatter.toArabicHoursMinutes(catalog.book.totalDurationSeconds)}'
            : '${catalog.book.lectureCount} lectures · '
                '${DurationFormatter.toHoursMinutes(catalog.book.totalDurationSeconds)}';

    final titleWidget = Text(
      title,
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    final subInfo = (speaker.isNotEmpty || countLine.isNotEmpty)
        ? SafeArea(
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                16,
                0,
                16,
                isArabicContent ? 50 : 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: isArabicContent
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (speaker.isNotEmpty)
                    Text(
                      speaker,
                      textAlign: isArabicContent ? TextAlign.right : null,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  if (countLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      countLine,
                      textAlign: isArabicContent ? TextAlign.right : null,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          )
        : null;

    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      expandedHeight: catalog != null ? 130 : 80,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
        title: isArabicContent
            ? Directionality(
                textDirection: TextDirection.rtl,
                child: titleWidget,
              )
            : titleWidget,
        background: subInfo != null
            ? isArabicContent
                ? Directionality(
                    textDirection: TextDirection.rtl,
                    child: subInfo,
                  )
                : subInfo
            : null,
      ),
    );
  }

  void _onLectureTap(Lecture lecture, List<Lecture> queue) {
    context.read<PlayerNotifier>().loadAndPlay(lecture, queue);
    context.push('/player');
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
