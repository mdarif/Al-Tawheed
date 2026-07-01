import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/confirm_dialog.dart';

class OfflineLibraryScreen extends StatelessWidget {
  const OfflineLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final catalog = context.watch<CatalogProvider>().catalog;
    final downloads = context.watch<DownloadsProvider>();

    if (catalog == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.offlineLibrary)),
        body: _EmptyState(),
      );
    }

    if (catalog.chapters.isEmpty) {
      // Flat series (e.g. standalone duroos) — no chapter grouping, just
      // list the downloaded lectures directly.
      final saved =
          catalog.lectures.where((l) => downloads.isDownloaded(l.id)).toList();
      return Scaffold(
        appBar: AppBar(title: Text(l10n.offlineLibrary)),
        body: saved.isEmpty
            ? _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                itemCount: saved.length,
                itemBuilder: (context, i) => _LectureTile(lecture: saved[i]),
              ),
      );
    }

    final chaptersWithDownloads = catalog.chapters
        .map((ch) {
          final lectures = catalog.lecturesForChapter(ch.id);
          final saved =
              lectures.where((l) => downloads.isDownloaded(l.id)).toList();
          return _ChapterGroup(
            chapter: ch,
            allLectures: lectures,
            savedLectures: saved,
          );
        })
        .where((g) => g.savedLectures.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineLibrary)),
      body: chaptersWithDownloads.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: chaptersWithDownloads.length,
              itemBuilder: (context, i) =>
                  _ChapterSection(group: chaptersWithDownloads[i]),
            ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 56,
              color: context.mutedIconColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.offlineLibraryEmpty,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.offlineLibraryEmptyHint,
              style: context.textTheme.bodySmall
                  ?.copyWith(color: context.secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chapter section ───────────────────────────────────────────────────────────

class _ChapterGroup {
  final Chapter chapter;
  final List<Lecture> allLectures;
  final List<Lecture> savedLectures;
  const _ChapterGroup({
    required this.chapter,
    required this.allLectures,
    required this.savedLectures,
  });
}

class _ChapterSection extends StatelessWidget {
  final _ChapterGroup group;
  const _ChapterSection({required this.group});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloads = context.watch<DownloadsProvider>();
    final connectivity = context.read<ConnectivityProvider>();
    final isChapterDownloading =
        downloads.isChapterDownloading(group.chapter.id);
    final allSaved = downloads.isChapterFullyDownloaded(group.allLectures);
    final savedBytes =
        group.savedLectures.fold(0, (sum, l) => sum + l.fileSizeBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Chapter header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context
                          .read<LanguageProvider>()
                          .resolve(group.chapter.title),
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.offlineChapterProgress(group.savedLectures.length, group.allLectures.length)}  ·  ${_fmt(savedBytes)}',
                      style: context.textTheme.bodySmall
                          ?.copyWith(color: context.secondaryTextColor),
                    ),
                  ],
                ),
              ),
              // Chapter-level actions
              if (isChapterDownloading)
                _ActionChip(
                  label: l10n.cancelChapterDownload,
                  icon: Icons.stop_rounded,
                  color: context.colorScheme.error,
                  onTap: () =>
                      downloads.cancelChapterDownload(group.chapter.id),
                )
              else if (!allSaved)
                _ActionChip(
                  label: l10n.downloadRemaining,
                  icon: Icons.download_rounded,
                  onTap: () {
                    if (downloads.downloadOnWifiOnly && !connectivity.isWifi) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.wifiOnlyBlocked),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    downloads.downloadChapter(
                      group.chapter.id,
                      group.allLectures,
                    );
                  },
                )
              else
                _ActionChip(
                  label: l10n.deleteChapter,
                  icon: Icons.delete_outline_rounded,
                  color: context.colorScheme.error,
                  onTap: () => _confirmDeleteChapter(context, downloads),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Saved lectures ──────────────────────────────────────────────────
        ...group.savedLectures.map(
          (lecture) => _LectureTile(lecture: lecture),
        ),
      ],
    );
  }

  void _confirmDeleteChapter(
    BuildContext context,
    DownloadsProvider downloads,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteChapterConfirm,
      message: context.read<LanguageProvider>().resolve(group.chapter.title),
      confirmLabel: l10n.deleteChapter,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      await downloads.deleteChapter(group.allLectures);
    }
  }

  static String _fmt(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.brandColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.textTheme.labelSmall
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual lecture tile ───────────────────────────────────────────────────

class _LectureTile extends StatelessWidget {
  final Lecture lecture;
  const _LectureTile({required this.lecture});

  @override
  Widget build(BuildContext context) {
    final series = context.read<SeriesProvider>().currentSeries;
    final title = context
        .read<LanguageProvider>()
        .resolveForSeries(lecture.title, series);
    final sizeMb = lecture.fileSizeBytes > 0
        ? '${(lecture.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';

    final titleWidget = Text(
      title,
      style: context.textTheme.bodyMedium,
      textAlign: series.isRtl ? TextAlign.right : null,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final removeLabel = context.l10nForSeries(series).offlineRemoveDownload;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.elevatedSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          lecture.number.toString().padLeft(2, '0'),
          style:
              context.textTheme.labelSmall?.copyWith(color: context.brandColor),
        ),
      ),
      title: series.isRtl
          ? Directionality(textDirection: TextDirection.rtl, child: titleWidget)
          : titleWidget,
      subtitle: Text(
        '${DurationFormatter.fromSeconds(lecture.durationSeconds)}  ·  $sizeMb',
        style: context.textTheme.bodySmall
            ?.copyWith(color: context.secondaryTextColor),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline_rounded,
          size: 20,
          color: context.mutedIconColor,
        ),
        onPressed: () => _confirmDelete(context, title, removeLabel),
        tooltip: removeLabel,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String title,
    String removeLabel,
  ) async {
    final l10n =
        context.l10nForSeries(context.read<SeriesProvider>().currentSeries);
    final confirmed = await showConfirmDialog(
      context,
      title: removeLabel,
      message: title,
      confirmLabel: removeLabel,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      await context.read<DownloadsProvider>().delete(lecture.id);
    }
  }
}
