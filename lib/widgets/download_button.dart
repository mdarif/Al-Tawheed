import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/widgets/confirm_dialog.dart';

class DownloadButton extends StatelessWidget {
  final Lecture lecture;
  final double size;

  const DownloadButton({
    super.key,
    required this.lecture,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final status = context.select<DownloadsProvider, DownloadStatus>(
      (p) => p.statusFor(lecture.id),
    );
    final progress = context.select<DownloadsProvider, int>(
      (p) => (p.progressFor(lecture.id) * 100).round(),
    );

    return switch (status) {
      DownloadStatus.notDownloaded => IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
          tooltip: 'Download for offline',
          icon: Icon(
            Icons.download_rounded,
            size: size,
            color: context.mutedIconColor,
          ),
          onPressed: () =>
              context.read<DownloadsProvider>().download(lecture),
        ),
      DownloadStatus.downloading => SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress > 0 ? progress / 100 : null,
                strokeWidth: 2,
                color: context.brandColor,
              ),
              if (progress > 0)
                Text(
                  '$progress',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: context.brandColor,
                  ),
                ),
            ],
          ),
        ),
      DownloadStatus.downloaded => IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
          tooltip: 'Delete download',
          icon: Icon(
            Icons.download_done_rounded,
            size: size,
            color: context.brandColor,
          ),
          onPressed: () => _confirmDelete(context),
        ),
      DownloadStatus.failed => IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
          tooltip: 'Retry download',
          icon: Icon(
            Icons.error_outline_rounded,
            size: size,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () =>
              context.read<DownloadsProvider>().download(lecture),
        ),
    };
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete download?',
      message: '${lecture.title.en} will be removed from offline storage.',
      confirmLabel: 'Delete',
    );
    if (confirmed && context.mounted) {
      context.read<DownloadsProvider>().delete(lecture.id);
    }
  }
}
