import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
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
    final l10n = context.l10n;
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
          tooltip: l10n.downloadForOffline,
          icon: Icon(
            Icons.download_rounded,
            size: size,
            color: context.mutedIconColor,
          ),
          onPressed: () => _startDownload(context),
        ),
      DownloadStatus.downloading => IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
          tooltip: l10n.offlineCancelDownload,
          icon: SizedBox(
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
          onPressed: () => context.read<DownloadsProvider>().cancelDownload(
                lecture.id,
              ),
        ),
      DownloadStatus.downloaded => IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
          tooltip: l10n.deleteDownload,
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
          tooltip: l10n.retryDownload,
          icon: Icon(
            Icons.error_outline_rounded,
            size: size,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _startDownload(context),
        ),
    };
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
    downloads.download(lecture);
  }

  void _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final title =
        context.read<LanguageProvider>().resolve(lecture.title);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteDownload,
      message: l10n.deleteDownloadMessage(title),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<DownloadsProvider>().delete(lecture.id);
    }
  }
}
