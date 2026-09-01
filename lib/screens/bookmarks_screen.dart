import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/saved_lecture_metadata.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/lecture_tile.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();
    final l10n = context.l10n;

    final lectures = _lectures(progress, catalog);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lectures.isEmpty ? l10n.saved : l10n.savedCount(lectures.length),
        ),
      ),
      body: const BookmarksBody(),
    );
  }
}

/// The Saved collection without route chrome, for embedding in Library.
class BookmarksBody extends StatelessWidget {
  const BookmarksBody({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();

    final lectures = _lectures(progress, catalog);

    return lectures.isEmpty
        ? _EmptyState(
            isLoading: catalog.status == CatalogStatus.loading,
            unavailable: progress.bookmarkedIds.isNotEmpty &&
                catalog.status != CatalogStatus.loaded,
          )
        : ListView.builder(
            itemCount: lectures.length,
            itemBuilder: (context, i) => Column(
              children: [
                LectureTile(
                  lecture: lectures[i],
                  onTap: () => _play(context, lectures[i], catalog),
                ),
                Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 16,
                  color: context.dividerColor,
                ),
              ],
            ),
          );
  }

  void _play(BuildContext context, Lecture lecture, CatalogProvider catalog) {
    context
        .read<PlayerNotifier>()
        .loadAndPlay(lecture, catalog.catalog?.lectures ?? [lecture]);
    context.push('/player');
  }
}

List<Lecture> _lectures(ProgressProvider progress, CatalogProvider catalog) {
  final live = catalog.catalog;
  if (live != null) {
    final savedById = {
      for (final row in progress.bookmarkedMetadata) row.id: row.toLecture(),
    };
    final result = <Lecture>[];
    for (final lecture in live.lectures) {
      if (progress.isBookmarked(lecture.id)) {
        result.add(lecture);
        savedById.remove(lecture.id);
      }
    }
    result.addAll(savedById.values);
    return result;
  }
  return progress.bookmarkedMetadata
      .map((SavedLectureMetadata row) => row.toLecture())
      .toList();
}

class _EmptyState extends StatelessWidget {
  final bool isLoading;
  final bool unavailable;
  const _EmptyState({required this.isLoading, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.brandColor),
      );
    }
    if (unavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.libraryContentUnavailable,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_outline_rounded,
            size: 52,
            color: context.mutedIconColor,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noSavedLectures,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noSavedHint,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
