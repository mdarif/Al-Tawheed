import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

class ChapterHeader extends StatelessWidget {
  final Chapter chapter;
  final List<Lecture> chapterLectures;

  const ChapterHeader({
    super.key,
    required this.chapter,
    required this.chapterLectures,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloadsEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.downloads,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: context.brandColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.read<LanguageProvider>().resolve(chapter.title),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            context.localizedDigits(l10n.partsCount(chapter.lectureCount)),
            style: context.textTheme.bodySmall,
          ),
          if (downloadsEnabled && chapterLectures.length > 1) ...[
            const SizedBox(width: 4),
            _ChapterDownloadAction(
              chapter: chapter,
              chapterLectures: chapterLectures,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChapterDownloadAction extends StatelessWidget {
  final Chapter chapter;
  final List<Lecture> chapterLectures;

  const _ChapterDownloadAction({
    required this.chapter,
    required this.chapterLectures,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloads = context.watch<DownloadsProvider>();
    final isDownloading = downloads.isChapterDownloading(chapter.id);
    final allSaved = downloads.isChapterFullyDownloaded(chapterLectures);

    if (allSaved) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Icon(
          Icons.check_circle_outline_rounded,
          size: 18,
          color: context.brandColor,
        ),
      );
    }

    if (isDownloading) {
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: l10n.cancelChapterDownload,
        icon: Icon(
          Icons.stop_circle_outlined,
          size: 20,
          color: context.colorScheme.error,
        ),
        onPressed: () => downloads.cancelChapterDownload(chapter.id),
      );
    }

    final sizeMb = _sizeMb(downloads.chapterTotalBytes(chapterLectures));

    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: l10n.downloadChapterAll(sizeMb),
      icon: Icon(
        Icons.download_for_offline_outlined,
        size: 20,
        color: context.mutedIconColor,
      ),
      onPressed: () => _startDownload(context),
    );
  }

  void _startDownload(BuildContext context) {
    final downloads = context.read<DownloadsProvider>();
    final connectivity = context.read<ConnectivityProvider>();
    if (downloads.downloadOnWifiOnly && !connectivity.isWifi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.wifiOnlyBlocked),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    downloads.downloadChapter(chapter.id, chapterLectures);
  }

  static String _sizeMb(int bytes) {
    if (bytes <= 0) return '?';
    final mb = bytes / (1024 * 1024);
    return mb.toStringAsFixed(mb < 10 ? 1 : 0);
  }
}
