import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

const _arOfflineLibrary = 'التنزيلات';
String _arOfflinePrepTitle(int count) =>
    count == 1 ? 'تحميل الجزء التالي دون اتصال' : 'تحميل $count أجزاء قادمة دون اتصال';
String _arOfflinePrepSize(String sizeMb) => '~$sizeMb ميجابايت';
const _arOfflinePrepSave = 'تحميل';
const _arConnectWifiToDownload = 'اتصل بشبكة Wi-Fi للتحميل';

/// Returns the next ≤3 lectures after [lastId] split into two lists:
/// [toDownload] (not yet started) and [downloading] (in progress).
/// Exported for testing; should not be called outside this file or tests.
@visibleForTesting
({List<Lecture> toDownload, List<Lecture> downloading}) computeOfflinePrepBatch(
  List<Lecture> allLectures,
  String lastId,
  DownloadsProvider downloads,
) {
  final currentIdx = allLectures.indexWhere((l) => l.id == lastId);
  if (currentIdx < 0 || currentIdx >= allLectures.length - 1) {
    return (toDownload: [], downloading: []);
  }
  final end = (currentIdx + 4).clamp(0, allLectures.length);
  final batch = allLectures.sublist(currentIdx + 1, end);
  final toDownload = batch
      .where(
        (l) =>
            downloads.statusFor(l.id) == DownloadStatus.notDownloaded ||
            downloads.statusFor(l.id) == DownloadStatus.failed,
      )
      .toList();
  final downloading = batch
      .where((l) => downloads.statusFor(l.id) == DownloadStatus.downloading)
      .toList();
  return (toDownload: toDownload, downloading: downloading);
}

class OfflinePrepStrip extends StatefulWidget {
  const OfflinePrepStrip({super.key});

  @override
  State<OfflinePrepStrip> createState() => _OfflinePrepStripState();
}

class _OfflinePrepStripState extends State<OfflinePrepStrip> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final connectivity = context.watch<ConnectivityProvider>();
    if (connectivity.isOffline) return const SizedBox.shrink();

    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();
    final downloads = context.watch<DownloadsProvider>();

    final lastId = progress.lastLectureId;
    if (lastId == null || catalog.status != CatalogStatus.loaded) {
      return const SizedBox.shrink();
    }

    final allLectures = catalog.catalog!.lectures;
    final (:toDownload, :downloading) =
        computeOfflinePrepBatch(allLectures, lastId, downloads);

    if (toDownload.isEmpty && downloading.isEmpty) {
      return const SizedBox.shrink();
    }

    final anyDownloading = downloading.isNotEmpty;
    final totalBytes = toDownload.fold(0, (sum, l) => sum + l.fileSizeBytes);
    final sizeMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final avgProgress = anyDownloading
        ? downloading.fold(0.0, (s, l) => s + downloads.progressFor(l.id)) /
            downloading.length
        : 0.0;

    final l10n = context.l10n;
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? _arOfflineLibrary : l10n.offlineLibrary,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.groupedSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.groupedBorder, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.semantic.brandSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    anyDownloading
                        ? Icons.downloading_rounded
                        : Icons.download_outlined,
                    color: context.brandColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: anyDownloading
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic
                                  ? _arOfflinePrepTitle(
                                      downloading.length + toDownload.length,
                                    )
                                  : l10n.offlinePrepTitle(
                                      downloading.length + toDownload.length,
                                    ),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: avgProgress,
                                backgroundColor: context.progressTrackColor,
                                color: context.brandColor,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic
                                  ? _arOfflinePrepTitle(toDownload.length)
                                  : l10n.offlinePrepTitle(toDownload.length),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.secondaryTextColor,
                              ),
                            ),
                            if (totalBytes > 0) ...[
                              const SizedBox(height: 3),
                              Text(
                                isArabic
                                    ? _arOfflinePrepSize(sizeMb)
                                    : l10n.offlinePrepSize(sizeMb),
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.secondaryTextColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                if (!anyDownloading) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _startDownloads(context, toDownload),
                    child: Text(
                      isArabic ? _arOfflinePrepSave : l10n.offlinePrepSave,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: context.mutedIconColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startDownloads(BuildContext context, List<Lecture> lectures) {
    final connectivity = context.read<ConnectivityProvider>();
    final downloads = context.read<DownloadsProvider>();
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;
    if (downloads.downloadOnWifiOnly && !connectivity.isWifi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? _arConnectWifiToDownload : context.l10n.wifiOnlyBlocked,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    for (final l in lectures) {
      downloads.download(l);
    }
  }
}
