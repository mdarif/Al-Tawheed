import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/audio/playback_source.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/offline_player_strip.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/download_button.dart';
import 'package:myapp/widgets/offline_sheet.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';

// Player-screen chrome strings shown in Arabic for the Arabic series,
// independent of the app's UI language (which still governs other
// screens' navigation/chrome).
const _arNowPlaying = 'يتم التشغيل الآن';
const _arStreaming = 'بث مباشر';
const _arSavedOffline = 'محفوظ للاستماع دون اتصال';
const _arNotAvailableOffline = 'غير متاح دون اتصال';
const _arNoConnection = 'لا يوجد اتصال';
const _arConnectionLost = 'انقطع الاتصال';
const _arBookmark = 'إضافة إشارة مرجعية';
const _arRemoveBookmark = 'إزالة الإشارة المرجعية';
String _arDownloading(int percent) => 'جارٍ التحميل... $percent%';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;
    return _NextBlockedListener(
      child: _StudyCompletionListener(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isArabic ? _arNowPlaying : 'Now Playing',
              style: context.textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            centerTitle: true,
            actions: [
              const _BookmarkButton(),
              if (context.select<FeatureFlagsProvider, bool>(
                (p) => p.features.downloads,
              ))
                const _PlayerDownloadButton(),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  const _CoverArt(),
                  const SizedBox(height: 32),
                  const _TrackInfo(),
                  const _OfflineStatusStrip(),
                  const SizedBox(height: 32),
                  const _SeekBar(),
                  const SizedBox(height: 28),
                  const _TransportControls(),
                  const SizedBox(height: 24),
                  const PlaybackSpeedSelectorCompact(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Offline next-blocked dialog listener ────────────────────────────────────

class _NextBlockedListener extends StatefulWidget {
  final Widget child;
  const _NextBlockedListener({required this.child});

  @override
  State<_NextBlockedListener> createState() => _NextBlockedListenerState();
}

class _NextBlockedListenerState extends State<_NextBlockedListener> {
  bool _handling = false;

  @override
  Widget build(BuildContext context) {
    final pending = context.select<PlayerNotifier, bool>(
      (p) => p.pendingNextBlocked,
    );

    if (pending && !_handling) {
      _handling = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handling = false;
        final notifier = context.read<PlayerNotifier>();
        final title = notifier.pendingNextBlockedTitle ?? '';
        final next = notifier.pendingNextBlockedLecture;
        notifier.clearPendingNextBlocked();
        _showBlockedDialog(context, title, next);
      });
    }

    return widget.child;
  }

  Future<void> _showBlockedDialog(
    BuildContext context,
    String title,
    Lecture? next,
  ) async {
    final l10n = context.l10n;
    final downloadsEnabled = context.read<FeatureFlagsProvider>().features.downloads;

    if (!downloadsEnabled || next == null) {
      await showAlertDialog(
        context,
        title: l10n.offlineNextBlockedTitle,
        message: l10n.offlineNextBlockedBody(title),
      );
      return;
    }

    final download = await showConfirmDialog(
      context,
      title: l10n.offlineNextBlockedTitle,
      message: l10n.offlineNextBlockedBody(title),
      confirmLabel: l10n.downloadForOffline,
      cancelLabel: l10n.cancel,
      filledConfirm: true,
    );
    if (!download || !context.mounted) return;

    final downloads = context.read<DownloadsProvider>();
    final connectivity = context.read<ConnectivityProvider>();

    if (connectivity.isOnline &&
        downloads.downloadOnWifiOnly &&
        !connectivity.isWifi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.wifiOnlyBlocked),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final started = downloads.downloadNowOrQueue(
      lecture: next,
      isOnline: connectivity.isOnline,
      isWifi: connectivity.isWifi,
    );

    if (!started && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.offlineNextBlockedQueued(title)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Study completion listener ────────────────────────────────────────────────

class _StudyCompletionListener extends StatefulWidget {
  final Widget child;
  const _StudyCompletionListener({required this.child});

  @override
  State<_StudyCompletionListener> createState() =>
      _StudyCompletionListenerState();
}

class _StudyCompletionListenerState extends State<_StudyCompletionListener> {
  String? _handledChapterId;

  @override
  Widget build(BuildContext context) {
    final pending = context.select<PlayerNotifier, String?>(
      (p) => p.pendingStudyChapterCompleteId,
    );

    if (pending != null && pending != _handledChapterId) {
      _handledChapterId = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = context.read<PlayerNotifier>();
        notifier.clearPendingStudyComplete();
        // Mark the chapter studied immediately so the completion screen's
        // "Next Up" recommendation and overall progress reflect it — even if
        // the session started mid-chapter and per-part progress hasn't all
        // crossed the live-complete threshold yet.
        context.read<StudyProgressProvider>().markChapterStudied(pending);
        Navigator.of(context).pop();
        context.push('/study/complete?chapterId=$pending');
      });
    }

    return widget.child;
  }
}

// ── Offline status strip ─────────────────────────────────────────────────────

class _OfflineStatusStrip extends StatelessWidget {
  const _OfflineStatusStrip();

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<PlayerNotifier, _OfflineSnapshot>(
      (p) => _OfflineSnapshot(
        source: p.playbackSource,
        isStuck: p.isStuckBuffering,
        lectureId: p.current?.id,
        lecture: p.current,
      ),
    );

    if (snapshot.lectureId == null) return const SizedBox.shrink();

    final isOffline = context.select<ConnectivityProvider, bool>(
      (c) => c.isOffline,
    );
    final dlStatus = context.select<DownloadsProvider, DownloadStatus>(
      (d) => d.statusFor(snapshot.lectureId!),
    );
    final dlProgress = context.select<DownloadsProvider, double>(
      (d) => d.progressFor(snapshot.lectureId!),
    );

    final resolution = resolveOfflinePlayerStrip(
      source: snapshot.source,
      isStuck: snapshot.isStuck,
      isOffline: isOffline,
      dlStatus: dlStatus,
      dlProgress: dlProgress,
    );
    final strip = resolution == null
        ? null
        : _stripFromResolution(context, resolution);
    if (strip == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: snapshot.lecture != null
            ? () => showOfflineSheet(context, snapshot.lecture!)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: strip.bgColor.withValues(
              alpha: context.isDarkTheme ? 0.25 : 0.18,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (strip.showProgress) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    value: dlProgress,
                    strokeWidth: 1.5,
                    color: strip.fgColor,
                  ),
                ),
              ] else
                Icon(strip.icon, size: 14, color: strip.fgColor),
              const SizedBox(width: 6),
              Text(
                strip.label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: strip.fgColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (strip.tappable) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 14,
                    color: strip.fgColor.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _StripConfig _stripFromResolution(
    BuildContext context,
    OfflineStripResolution resolution,
  ) {
    final l10n = context.l10n;
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;

    return switch (resolution.kind) {
      OfflineStripKind.downloading => _StripConfig(
          icon: Icons.download_rounded,
          label: isArabic
              ? _arDownloading(resolution.downloadPercent)
              : l10n.offlineDownloading(resolution.downloadPercent),
          fgColor: context.brandColor,
          bgColor: context.brandColor,
          showProgress: true,
          tappable: true,
        ),
      OfflineStripKind.saved => _StripConfig(
          icon: Icons.check_circle_outline_rounded,
          label: isArabic ? _arSavedOffline : l10n.offlineSourceSaved,
          fgColor: const Color(0xFF2E7D32),
          bgColor: const Color(0xFF2E7D32),
          tappable: true,
        ),
      OfflineStripKind.streaming => _StripConfig(
          icon: Icons.podcasts_rounded,
          label: isArabic ? _arStreaming : l10n.offlineSourceStreaming,
          fgColor: context.secondaryTextColor,
          bgColor: context.brandColor,
          tappable: true,
        ),
      OfflineStripKind.connectionLost => _StripConfig(
          icon: Icons.wifi_off_rounded,
          label: isArabic ? _arConnectionLost : l10n.offlineConnectionLost,
          fgColor: context.colorScheme.error,
          bgColor: context.colorScheme.error,
          tappable: true,
        ),
      OfflineStripKind.noConnection => _StripConfig(
          icon: Icons.wifi_off_rounded,
          label: isArabic ? _arNoConnection : l10n.offlineNoConnection,
          fgColor: const Color(0xFFE65100),
          bgColor: const Color(0xFFE65100),
          tappable: true,
        ),
      OfflineStripKind.notAvailableOffline => _StripConfig(
          icon: Icons.cloud_off_rounded,
          label: isArabic
              ? _arNotAvailableOffline
              : l10n.offlineNotAvailableOffline,
          fgColor: const Color(0xFFE65100),
          bgColor: const Color(0xFFE65100),
          tappable: true,
        ),
    };
  }
}

class _OfflineSnapshot {
  final PlaybackSource source;
  final bool isStuck;
  final String? lectureId;
  final Lecture? lecture;

  const _OfflineSnapshot({
    required this.source,
    required this.isStuck,
    required this.lectureId,
    required this.lecture,
  });

  @override
  bool operator ==(Object other) =>
      other is _OfflineSnapshot &&
      other.source == source &&
      other.isStuck == isStuck &&
      other.lectureId == lectureId;

  @override
  int get hashCode => Object.hash(source, isStuck, lectureId);
}

class _StripConfig {
  final IconData icon;
  final String label;
  final Color fgColor;
  final Color bgColor;
  final bool showProgress;
  final bool tappable;

  const _StripConfig({
    required this.icon,
    required this.label,
    required this.fgColor,
    required this.bgColor,
    this.showProgress = false,
    this.tappable = false,
  });
}

// ── Cover art ────────────────────────────────────────────────────────────────

class _CoverArt extends StatelessWidget {
  const _CoverArt();

  @override
  Widget build(BuildContext context) {
    final series = context.read<SeriesProvider>().currentSeries;
    final catalog = context.watch<CatalogProvider>().catalog;
    final wordmark = series.isRtl && catalog != null
        ? context
            .read<LanguageProvider>()
            .resolveForSeries(catalog.book.title, series)
        : 'شرح كتاب التوحيد';

    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.groupedBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(
              alpha: context.isDarkTheme ? 0.4 : 0.08,
            ),
            blurRadius: context.isDarkTheme ? 30 : 20,
            offset: Offset(0, context.isDarkTheme ? 12 : 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones_rounded,
              size: 72, color: context.brandColor),
          const SizedBox(height: 12),
          Text(
            wordmark,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.brandColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Track info ───────────────────────────────────────────────────────────────

class _TrackInfo extends StatelessWidget {
  const _TrackInfo();

  @override
  Widget build(BuildContext context) {
    final series = context.read<SeriesProvider>().currentSeries;
    final lang = context.read<LanguageProvider>();
    return Selector<PlayerNotifier, _TrackInfoSnapshot>(
      selector: (_, player) => _TrackInfoSnapshot(
        lectureId: player.current?.id,
        title: player.current?.title,
        studyLabel: player.studyContextLabel,
      ),
      builder: (_, snapshot, __) {
        final catalog = context.watch<CatalogProvider>().catalog;
        final speaker = catalog != null
            ? lang.resolveForSeries(catalog.book.speaker, series)
            : '';
        final title =
            snapshot.studyLabel ?? lang.resolveForSeries(snapshot.title, series);

        final content = Column(
          children: [
            Text(
              title,
              style: context.textTheme.headlineSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (speaker.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                speaker,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );

        return series.isRtl
            ? Directionality(textDirection: TextDirection.rtl, child: content)
            : content;
      },
    );
  }
}

class _TrackInfoSnapshot {
  final String? lectureId;
  final Map<String, dynamic>? title;
  final String? studyLabel;

  const _TrackInfoSnapshot({
    required this.lectureId,
    required this.title,
    required this.studyLabel,
  });

  @override
  bool operator ==(Object other) =>
      other is _TrackInfoSnapshot &&
      other.lectureId == lectureId &&
      other.studyLabel == studyLabel;

  @override
  int get hashCode => Object.hash(lectureId, studyLabel);
}

// ── Seek bar ─────────────────────────────────────────────────────────────────

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, _SeekSnapshot>(
      selector: (_, player) => _SeekSnapshot(
        progress: player.progress,
        positionSeconds: player.position.inSeconds,
        durationSeconds: player.duration.inSeconds,
      ),
      builder: (_, snapshot, __) {
        final sliderValue = _draggingValue ?? snapshot.progress;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: sliderValue.clamp(0.0, 1.0),
                onChangeStart: (v) => setState(() => _draggingValue = v),
                onChanged: (v) => setState(() => _draggingValue = v),
                onChangeEnd: (v) {
                  setState(() => _draggingValue = null);
                  context.read<PlayerNotifier>().seek(Duration(
                        milliseconds:
                            (v * snapshot.durationSeconds * 1000).round(),
                      ));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DurationFormatter.fromSeconds(snapshot.positionSeconds),
                    style: context.textTheme.bodySmall,
                  ),
                  Text(
                    DurationFormatter.fromSeconds(snapshot.durationSeconds),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeekSnapshot {
  final double progress;
  final int positionSeconds;
  final int durationSeconds;

  const _SeekSnapshot({
    required this.progress,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  @override
  bool operator ==(Object other) =>
      other is _SeekSnapshot &&
      other.progress == progress &&
      other.positionSeconds == positionSeconds &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(progress, positionSeconds, durationSeconds);
}

// ── Transport controls ───────────────────────────────────────────────────────

class _TransportControls extends StatelessWidget {
  const _TransportControls();

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerNotifier, _TransportSnapshot>(
      selector: (_, player) => _TransportSnapshot(
        isPlaying: player.isPlaying,
        isLoading: player.isLoading,
        hasPrevious: player.hasPrevious,
        hasNext: player.hasNext,
      ),
      builder: (_, snapshot, __) {
        final enabledColor = context.primaryTextColor;
        final disabledColor = context.mutedIconColor;
        final player = context.read<PlayerNotifier>();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 32,
              icon: Icon(
                Icons.skip_previous_rounded,
                color: snapshot.hasPrevious ? enabledColor : disabledColor,
              ),
              onPressed: snapshot.hasPrevious ? player.playPrevious : null,
            ),
            IconButton(
              iconSize: 28,
              icon: Icon(Icons.replay_10_rounded, color: enabledColor),
              onPressed: player.skipBackward,
            ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: context.brandColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.brandColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: snapshot.isLoading
                  ? Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: context.onBrandColor,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : IconButton(
                      iconSize: 36,
                      icon: Icon(
                        snapshot.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: context.onBrandColor,
                      ),
                      onPressed: player.playPause,
                    ),
            ),
            IconButton(
              iconSize: 28,
              icon: Icon(Icons.forward_10_rounded, color: enabledColor),
              onPressed: player.skipForward,
            ),
            IconButton(
              iconSize: 32,
              icon: Icon(
                Icons.skip_next_rounded,
                color: snapshot.hasNext ? enabledColor : disabledColor,
              ),
              onPressed: snapshot.hasNext ? player.playNext : null,
            ),
          ],
        );
      },
    );
  }
}

class _TransportSnapshot {
  final bool isPlaying;
  final bool isLoading;
  final bool hasPrevious;
  final bool hasNext;

  const _TransportSnapshot({
    required this.isPlaying,
    required this.isLoading,
    required this.hasPrevious,
    required this.hasNext,
  });

  @override
  bool operator ==(Object other) =>
      other is _TransportSnapshot &&
      other.isPlaying == isPlaying &&
      other.isLoading == isLoading &&
      other.hasPrevious == hasPrevious &&
      other.hasNext == hasNext;

  @override
  int get hashCode => Object.hash(isPlaying, isLoading, hasPrevious, hasNext);
}

// ── App bar buttons ──────────────────────────────────────────────────────────

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton();

  @override
  Widget build(BuildContext context) {
    final lectureId = context.select<PlayerNotifier, String?>(
      (player) => player.current?.id,
    );
    if (lectureId == null) return const SizedBox.shrink();

    final isBookmarked = context.select<ProgressProvider, bool>(
      (p) => p.isBookmarked(lectureId),
    );
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;

    return IconButton(
      tooltip: isArabic
          ? (isBookmarked ? _arRemoveBookmark : _arBookmark)
          : (isBookmarked ? 'Remove bookmark' : 'Bookmark'),
      icon: Icon(
        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
        color: isBookmarked ? context.brandColor : context.primaryTextColor,
      ),
      onPressed: () =>
          context.read<ProgressProvider>().toggleBookmark(lectureId),
    );
  }
}

class _PlayerDownloadButton extends StatelessWidget {
  const _PlayerDownloadButton();

  @override
  Widget build(BuildContext context) {
    final lecture = context.select<PlayerNotifier, Lecture?>(
      (p) => p.current,
    );
    if (lecture == null) return const SizedBox.shrink();
    return DownloadButton(lecture: lecture, size: 22);
  }
}
