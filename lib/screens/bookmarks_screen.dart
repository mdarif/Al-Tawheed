import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/lecture_tile.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();

    final lectures = catalog.status == CatalogStatus.loaded
        ? catalog.catalog!.lectures
            .where((l) => progress.isBookmarked(l.id))
            .toList()
        : <Lecture>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lectures.isEmpty ? 'Saved' : 'Saved (${lectures.length})',
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
                    color: AppColors.surfaceContainerDark,
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
    if (isLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_outline_rounded,
              size: 52, color: AppColors.onDarkSecondary),
          const SizedBox(height: 16),
          Text(
            'No saved lectures yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the bookmark icon in the player to save a lecture',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
