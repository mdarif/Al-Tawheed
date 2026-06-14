import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/confirm_dialog.dart';

// Offline-sheet chrome strings shown in Arabic for the Arabic series,
// independent of the app's UI language (which still governs other
// screens' navigation/chrome).
const _arCancelDownload = 'إلغاء التحميل';
const _arRemoveDownload = 'إزالة التحميل';
const _arManageDownloads = 'إدارة التنزيلات';
const _arCancel = 'إلغاء';
const _arConnectWifiToDownload = 'اتصل بشبكة Wi-Fi للتحميل';
String _arDownloadLecture(String sizeMb) => 'تحميل الدرس · $sizeMb MB';
String _arDownloading(int percent) => 'جارٍ التحميل... $percent%';

void showOfflineSheet(BuildContext context, Lecture lecture) {
  final catalog = context.read<CatalogProvider>().catalog;
  // Flat-list series (no chapters) have no "whole chapter" concept — treat
  // each lecture as its own single-item group so the bulk download option
  // below stays hidden for them.
  final chapterLectures = (catalog != null && catalog.chapters.isNotEmpty)
      ? catalog.lecturesForChapter(lecture.chapterId)
      : <Lecture>[lecture];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<DownloadsProvider>()),
        ChangeNotifierProvider.value(
            value: context.read<ConnectivityProvider>()),
        ChangeNotifierProvider.value(value: context.read<SeriesProvider>()),
        ChangeNotifierProvider.value(value: context.read<LanguageProvider>()),
      ],
      child: _OfflineSheetContent(
          lecture: lecture, chapterLectures: chapterLectures),
    ),
  );
}

class _OfflineSheetContent extends StatelessWidget {
  final Lecture lecture;
  final List<Lecture> chapterLectures;
  const _OfflineSheetContent(
      {required this.lecture, required this.chapterLectures});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloads = context.watch<DownloadsProvider>();
    final connectivity = context.read<ConnectivityProvider>();
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;
    final status = downloads.statusFor(lecture.id);
    final isDownloaded = status == DownloadStatus.downloaded;
    final isDownloading = status == DownloadStatus.downloading;
    final isChapterDownloading =
        downloads.isChapterDownloading(lecture.chapterId);
    final chapterFull =
        downloads.isChapterFullyDownloaded(chapterLectures);
    final sizeMb = _sizeMb(lecture.fileSizeBytes);
    final chapterTotalMb = _sizeMb(downloads.chapterTotalBytes(chapterLectures));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(context),
            const SizedBox(height: 12),
            _header(context, isDownloaded),
            const Divider(height: 24),

            // ── This lecture ────────────────────────────────────────────────
            if (isDownloading) ...[
              _ProgressRow(lectureId: lecture.id),
              const SizedBox(height: 4),
              _SheetTile(
                icon: Icons.cancel_outlined,
                label: isArabic ? _arCancelDownload : l10n.offlineCancelDownload,
                color: context.colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  downloads.cancelDownload(lecture.id);
                },
              ),
            ] else if (isDownloaded) ...[
              _SheetTile(
                icon: Icons.delete_outline_rounded,
                label: isArabic ? _arRemoveDownload : l10n.offlineRemoveDownload,
                color: context.colorScheme.error,
                onTap: () => _confirmDeleteLecture(context, downloads),
              ),
            ] else ...[
              _SheetTile(
                icon: Icons.download_rounded,
                label: isArabic
                    ? _arDownloadLecture(sizeMb)
                    : l10n.offlineDownloadLecture(sizeMb),
                onTap: () => _startDownload(context, downloads, connectivity),
              ),
            ],

            // ── Whole chapter ───────────────────────────────────────────────
            if (chapterLectures.length > 1) ...[
              if (isChapterDownloading) ...[
                _SheetTile(
                  icon: Icons.stop_circle_outlined,
                  label: l10n.cancelChapterDownload,
                  color: context.colorScheme.error,
                  onTap: () {
                    Navigator.pop(context);
                    downloads.cancelChapterDownload(lecture.chapterId);
                  },
                ),
              ] else if (!chapterFull) ...[
                _SheetTile(
                  icon: Icons.download_for_offline_outlined,
                  label: l10n.downloadChapterAll(chapterTotalMb),
                  onTap: () =>
                      _startChapterDownload(context, downloads, connectivity),
                ),
              ],
            ],

            const SizedBox(height: 4),
            _SheetTile(
              icon: Icons.folder_open_rounded,
              label: isArabic ? _arManageDownloads : l10n.offlineManageDownloads,
              color: context.secondaryTextColor,
              onTap: () {
                // Capture the router and delay the push to the next frame.
                // Navigator.pop (direct) + router.push (via GoRouter) in the
                // same sync block causes Navigator._updatePages to see
                // duplicate ValueKeys while the sheet pop is in-flight.
                final router = GoRouter.of(context);
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  router.push('/offline-library');
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startDownload(BuildContext context, DownloadsProvider downloads,
      ConnectivityProvider connectivity) {
    if (_wifiOnlyBlocked(context, downloads, connectivity)) return;
    Navigator.pop(context);
    downloads.download(lecture);
  }

  void _startChapterDownload(BuildContext context, DownloadsProvider downloads,
      ConnectivityProvider connectivity) {
    if (_wifiOnlyBlocked(context, downloads, connectivity)) return;
    Navigator.pop(context);
    downloads.downloadChapter(lecture.chapterId, chapterLectures);
  }

  bool _wifiOnlyBlocked(BuildContext context, DownloadsProvider downloads,
      ConnectivityProvider connectivity) {
    if (downloads.downloadOnWifiOnly && !connectivity.isWifi) {
      final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isArabic ? _arConnectWifiToDownload : context.l10n.wifiOnlyBlocked),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    }
    return false;
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: context.dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(BuildContext context, bool isDownloaded) {
    final series = context.read<SeriesProvider>().currentSeries;
    final title =
        context.read<LanguageProvider>().resolveForSeries(lecture.title, series);
    final titleWidget = Text(
      title,
      style: context.textTheme.titleSmall,
      textAlign: series.isRtl ? TextAlign.right : null,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return Row(
      children: [
        Icon(
          isDownloaded
              ? Icons.check_circle_outline_rounded
              : Icons.headphones_rounded,
          size: 20,
          color:
              isDownloaded ? context.brandColor : context.secondaryTextColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: series.isRtl
              ? Directionality(
                  textDirection: TextDirection.rtl, child: titleWidget)
              : titleWidget,
        ),
      ],
    );
  }

  void _confirmDeleteLecture(
      BuildContext context, DownloadsProvider downloads) {
    final l10n = context.l10n;
    final series = context.read<SeriesProvider>().currentSeries;
    final isArabic = series.isRtl;
    final title =
        context.read<LanguageProvider>().resolveForSeries(lecture.title, series);
    showConfirmDialog(
      context,
      title: isArabic ? _arRemoveDownload : l10n.offlineRemoveDownload,
      message: title,
      confirmLabel: isArabic ? _arRemoveDownload : l10n.offlineRemoveDownload,
      cancelLabel: isArabic ? _arCancel : 'Cancel',
      destructive: true,
    ).then((confirmed) {
      if (confirmed && context.mounted) {
        Navigator.pop(context);
        downloads.delete(lecture.id);
      }
    });
  }

  static String _sizeMb(int bytes) {
    if (bytes <= 0) return '?';
    final mb = bytes / (1024 * 1024);
    return mb.toStringAsFixed(mb < 10 ? 1 : 0);
  }
}

class _ProgressRow extends StatelessWidget {
  final String lectureId;
  const _ProgressRow({required this.lectureId});

  @override
  Widget build(BuildContext context) {
    final progress = context.select<DownloadsProvider, double>(
      (d) => d.progressFor(lectureId),
    );
    final l10n = context.l10n;
    final percent = (progress * 100).round();
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? _arDownloading(percent) : l10n.offlineDownloading(percent),
            style: context.textTheme.bodySmall
                ?.copyWith(color: context.secondaryTextColor),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? context.primaryTextColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: tileColor),
      title: Text(label, style: TextStyle(color: tileColor)),
      onTap: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
