import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
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

    final lectures = catalog.status == CatalogStatus.loaded
        ? catalog.catalog!.lectures
            .where((l) => progress.isBookmarked(l.id))
            .toList()
        : <Lecture>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lectures.isEmpty ? l10n.saved : l10n.savedCount(lectures.length),
        ),
      ),
      body: lectures.isEmpty
          ? _EmptyState(isLoading: catalog.status == CatalogStatus.loading)
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
            ),
    );
  }

  void _play(BuildContext context, Lecture lecture, CatalogProvider catalog) {
    context
        .read<PlayerNotifier>()
        .loadAndPlay(lecture, catalog.catalog!.lectures);
    context.push('/player');
  }
}

class _EmptyState extends StatelessWidget {
  final bool isLoading;
  const _EmptyState({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.brandColor),
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
