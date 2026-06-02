import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/widgets/chapter_header.dart';
import 'package:myapp/widgets/lecture_tile.dart';
class LectureListScreen extends StatefulWidget {
  const LectureListScreen({super.key});

  @override
  State<LectureListScreen> createState() => _LectureListScreenState();
}

class _LectureListScreenState extends State<LectureListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CatalogProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            CatalogStatus.idle || CatalogStatus.loading => _buildLoading(),
            CatalogStatus.error => _buildError(provider.error!, provider),
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

  Widget _buildError(String message, CatalogProvider provider) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(null),
        SliverFillRemaining(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 52, color: context.mutedIconColor),
                const SizedBox(height: 20),
                Text(
                  'Could not load lectures',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: provider.load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(Catalog catalog) {
    final lectures = catalog.lectures;
    final items = <_ListItem>[];
    for (final chapter in catalog.chapters) {
      items.add(_ListItem.chapter(chapter));
      for (final lecture in catalog.lecturesForChapter(chapter.id)) {
        items.add(_ListItem.lecture(lecture));
      }
    }

    return CustomScrollView(
      slivers: [
        _buildAppBar(catalog),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              if (item.isChapter) return ChapterHeader(chapter: item.chapter!);
              return Column(
                children: [
                  LectureTile(
                    lecture: item.lecture!,
                    onTap: () => _onLectureTap(item.lecture!, lectures),
                  ),
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
            builder: (_, hasAudio, __) =>
                SizedBox(height: hasAudio ? 80 : 24),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(Catalog? catalog) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: catalog != null ? 140 : 80,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sharah Kitab al-Tawheed',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (catalog != null)
              Text(
                '${catalog.book.lectureCount} lectures · '
                '${DurationFormatter.toHoursMinutes(catalog.book.totalDurationSeconds)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
              ),
          ],
        ),
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
