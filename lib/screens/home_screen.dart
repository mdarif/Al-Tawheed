import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/home/study_mode_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<AnnouncementsProvider>().refresh(),
            context.read<FeatureFlagsProvider>().load(),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(context.l10n.tabHome),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _AnnouncementsBanner(),
                if (context.watch<FeatureFlagsProvider>().features.studyMode)
                  const StudyModeCard(),
                if (context.watch<FeatureFlagsProvider>().features.studyMode)
                  const SizedBox(height: 24),
                _ContinueListeningCard(),
                if (context.watch<FeatureFlagsProvider>().features.downloads)
                  _OfflinePrepStrip(),
                const SizedBox(height: 24),
                _DailyBenefitCard(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();

    final lastId = progress.lastLectureId;

    if (lastId == null || catalog.status != CatalogStatus.loaded) {
      return _emptyState(context);
    }

    Lecture? lecture;
    try {
      lecture = catalog.catalog!.lectures.firstWhere((l) => l.id == lastId);
    } catch (_) {
      return _emptyState(context);
    }

    final fraction = progress.getFraction(lastId, lecture.durationSeconds);
    final savedSeconds = progress.getPositionSeconds(lastId);
    final remaining = lecture.durationSeconds - savedSeconds;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.continueListening,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            final player = context.read<PlayerNotifier>();
            final allLectures = catalog.catalog!.lectures;
            player.loadAndPlay(lecture!, allLectures);
            context.push('/player');
          },
          child: Container(
            decoration: BoxDecoration(
              color: context.groupedSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.groupedBorder, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.semantic.brandSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.headphones_rounded,
                        color: context.brandColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.read<LanguageProvider>().resolve(lecture.title),
                            style: context.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.listenedDuration(
                              DurationFormatter.fromSeconds(savedSeconds),
                              DurationFormatter.fromSeconds(remaining),
                            ),
                            style: context.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.brandColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: context.onBrandColor,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: context.progressTrackColor,
                    color: context.brandColor,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.percentComplete((fraction * 100).round()),
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.continueListening,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.groupedSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.groupedBorder, width: 1),
          ),
          child: Column(
            children: [
              Icon(Icons.headphones_rounded,
                  size: 36, color: context.mutedIconColor),
              const SizedBox(height: 10),
              Text(
                l10n.continueListeningEmpty,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyBenefitCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

    if (catalog.status != CatalogStatus.loaded ||
        catalog.catalog!.dailyBenefits.isEmpty) {
      return const SizedBox.shrink();
    }

    final benefits = catalog.catalog!.dailyBenefits;
    final dayIndex = DateTime.now().difference(DateTime(2026)).inDays;
    final benefit = benefits[dayIndex % benefits.length];
    final semantic = context.semantic;
    final lang = context.read<LanguageProvider>();
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dailyBenefit,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                semantic.accentGradientStart,
                semantic.accentGradientEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: semantic.accentGradientBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded,
                  color: context.brandColor, size: 24),
              const SizedBox(height: 10),
              // Arabic text — right-aligned with proper RTL directionality
              if (benefit.textArabic != null) ...[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    benefit.textArabic!,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.8,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                lang.resolve(benefit.text),
                style: context.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: context.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '— ${lang.resolve(benefit.source)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: semantic.brandEmphasis,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Offline preparation strip ─────────────────────────────────────────────────

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
      .where((l) =>
          downloads.statusFor(l.id) == DownloadStatus.notDownloaded ||
          downloads.statusFor(l.id) == DownloadStatus.failed)
      .toList();
  final downloading = batch
      .where((l) => downloads.statusFor(l.id) == DownloadStatus.downloading)
      .toList();
  return (toDownload: toDownload, downloading: downloading);
}

class _OfflinePrepStrip extends StatefulWidget {
  @override
  State<_OfflinePrepStrip> createState() => _OfflinePrepStripState();
}

class _OfflinePrepStripState extends State<_OfflinePrepStrip> {
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

    if (toDownload.isEmpty && downloading.isEmpty) return const SizedBox.shrink();

    final anyDownloading = downloading.isNotEmpty;
    final totalBytes = toDownload.fold(0, (sum, l) => sum + l.fileSizeBytes);
    final sizeMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final avgProgress = anyDownloading
        ? downloading.fold(0.0, (s, l) => s + downloads.progressFor(l.id)) /
            downloading.length
        : 0.0;

    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.groupedSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.groupedBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              anyDownloading
                  ? Icons.downloading_rounded
                  : Icons.download_outlined,
              size: 18,
              color: context.brandColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: anyDownloading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.offlinePrepTitle(downloading.length + toDownload.length),
                          style: context.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: avgProgress,
                          borderRadius: BorderRadius.circular(2),
                          minHeight: 3,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.offlinePrepTitle(toDownload.length),
                          style: context.textTheme.bodySmall,
                        ),
                        if (totalBytes > 0)
                          Text(
                            l10n.offlinePrepSize(sizeMb),
                            style: context.textTheme.bodySmall
                                ?.copyWith(color: context.secondaryTextColor),
                          ),
                      ],
                    ),
            ),
            if (!anyDownloading) ...[
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _startDownloads(context, toDownload),
                child: Text(l10n.offlinePrepSave),
              ),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: context.mutedIconColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startDownloads(BuildContext context, List<Lecture> lectures) {
    final connectivity = context.read<ConnectivityProvider>();
    final downloads = context.read<DownloadsProvider>();
    if (downloads.downloadOnWifiOnly && !connectivity.isWifi) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.wifiOnlyBlocked),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    for (final l in lectures) {
      downloads.download(l);
    }
  }
}

// ── Announcements Banner ──────────────────────────────────────────────────────

class _AnnouncementsBanner extends StatelessWidget {
  static const _iconForType = {
    'info': Icons.info_outline_rounded,
    'warning': Icons.warning_amber_rounded,
    'success': Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (!context.watch<FeatureFlagsProvider>().features.announcements) {
      return const SizedBox.shrink();
    }

    final announcements = context.watch<AnnouncementsProvider>().visible;
    if (announcements.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final a in announcements) ...[
          _AnnouncementCard(announcement: a),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final icon = _AnnouncementsBanner._iconForType[announcement.type] ??
        Icons.info_outline_rounded;

    return Container(
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.groupedBorder, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gold left accent bar — matches the chapter header style
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: context.brandColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: context.brandColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lang.resolve(announcement.title),
                            style: context.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context
                              .read<AnnouncementsProvider>()
                              .dismiss(announcement.id),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: context.mutedIconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lang.resolve(announcement.body),
                      style: context.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: context.secondaryTextColor,
                      ),
                    ),
                    if (announcement.ctaUrl != null &&
                        announcement.ctaLabel != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(announcement.ctaUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          lang.resolve(announcement.ctaLabel!),
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.brandColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
