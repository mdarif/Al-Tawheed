import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/announcements_banner.dart';
import 'package:myapp/widgets/offline_prep_strip.dart';

// Home-screen chrome strings shown in Arabic for the Arabic series,
// independent of the app's UI language (which still governs other
// screens' navigation/chrome).
const _arSaved = 'المحفوظات';
const _arContinueListening = 'متابعة الاستماع';
const _arContinueListeningEmpty =
    'ابدأ الاستماع إلى أحد الدروس لمتابعته من هنا';
String _arListenedDuration(String listened, String remaining) =>
    'تم الاستماع: $listened · المتبقي: $remaining';
String _arPercentComplete(int percent) => '$percent% مكتمل';
const _arDailyBenefit = 'فائدة اليوم';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.bookmark_outline_rounded),
                  tooltip: isArabic ? _arSaved : context.l10n.saved,
                  onPressed: () => context.push('/bookmarks'),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  AnnouncementsBanner(),
                  const _ContinueListeningCard(),
                  if (context.watch<FeatureFlagsProvider>().features.downloads)
                    OfflinePrepStrip(),
                  const SizedBox(height: 24),
                  const _DailyBenefitCard(),
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
  const _ContinueListeningCard();

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();
    final study = context.watch<StudyProgressProvider>();

    final lastId = progress.lastLectureId;

    if (lastId == null || catalog.status != CatalogStatus.loaded) {
      return _emptyState(context, study);
    }

    Lecture? lecture;
    try {
      lecture = catalog.catalog!.lectures.firstWhere((l) => l.id == lastId);
    } catch (e) {
      debugPrint('HomeScreen: last-played lecture not found in catalog: $e');
      return _emptyState(context, study);
    }

    final fraction = progress.getFraction(lastId, lecture.durationSeconds);
    final savedSeconds = progress.getPositionSeconds(lastId);
    final remaining = lecture.durationSeconds - savedSeconds;
    final l10n = context.l10n;
    final series = context.read<SeriesProvider>().currentSeries;
    final isArabic = series.isRtl;
    // Watch the language so the resolved title refreshes on a UI-language
    // change while Home stays alive in the bottom-nav shell.
    final lectureTitle = context
        .watch<LanguageProvider>()
        .resolveForSeries(lecture.title, series);

    final card = GestureDetector(
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
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          lectureTitle,
                          textAlign: isArabic ? TextAlign.right : null,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isArabic
                            ? _arListenedDuration(
                                DurationFormatter.fromSeconds(savedSeconds),
                                DurationFormatter.fromSeconds(remaining),
                              )
                            : l10n.listenedDuration(
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
              isArabic
                  ? _arPercentComplete((fraction * 100).round())
                  : l10n.percentComplete((fraction * 100).round()),
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, study),
        const SizedBox(height: 12),
        // Mirror the whole card for the Arabic series: the icon/play row flips
        // and the progress bar fills right-to-left, matching the RTL content.
        isArabic
            ? Directionality(textDirection: TextDirection.rtl, child: card)
            : card,
      ],
    );
  }

  Widget _header(BuildContext context, StudyProgressProvider study) {
    final l10n = context.l10n;
    final stats = study.stats;
    final series = context.watch<SeriesProvider>().currentSeries;
    final hasStudyMode = series.hasStudyMode;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          series.isRtl ? _arContinueListening : l10n.continueListening,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (stats.totalLectures > 0)
          _OverallProgressStats(
            completedLectures: stats.completedLectures,
            totalLectures: stats.totalLectures,
            studiedClasses: study.studiedCount,
            totalClasses: study.totalChapterCount,
            showClasses: hasStudyMode,
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, StudyProgressProvider study) {
    final l10n = context.l10n;
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;
    final messageWidget = Text(
      isArabic ? _arContinueListeningEmpty : l10n.continueListeningEmpty,
      textAlign: isArabic ? TextAlign.right : null,
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.secondaryTextColor,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, study),
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
              Icon(
                Icons.headphones_rounded,
                size: 36,
                color: context.mutedIconColor,
              ),
              const SizedBox(height: 10),
              isArabic
                  ? Directionality(
                      textDirection: TextDirection.rtl,
                      child: messageWidget,
                    )
                  : messageWidget,
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact "X/Y lectures · X/Y classes" summary shown beside the
/// "Continue Listening" header — overall progress at a glance.
class _OverallProgressStats extends StatelessWidget {
  final int completedLectures;
  final int totalLectures;
  final int studiedClasses;
  final int totalClasses;
  final bool showClasses;

  const _OverallProgressStats({
    required this.completedLectures,
    required this.totalLectures,
    required this.studiedClasses,
    required this.totalClasses,
    this.showClasses = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.labelSmall?.copyWith(
      color: context.secondaryTextColor,
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.headphones_rounded, size: 13, color: context.mutedIconColor),
        const SizedBox(width: 3),
        Text('$completedLectures/$totalLectures', style: style),
        if (showClasses) ...[
          const SizedBox(width: 10),
          Icon(
            Icons.menu_book_rounded,
            size: 13,
            color: context.mutedIconColor,
          ),
          const SizedBox(width: 3),
          Text('$studiedClasses/$totalClasses', style: style),
        ],
      ],
    );
  }
}

class _DailyBenefitCard extends StatelessWidget {
  const _DailyBenefitCard();

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
    // Watch the language so the resolved benefit text/source refresh on a
    // UI-language change while Home stays alive in the bottom-nav shell.
    final lang = context.watch<LanguageProvider>();
    final l10n = context.l10n;
    final isArabic = context.read<SeriesProvider>().currentSeries.isRtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? _arDailyBenefit : l10n.dailyBenefit,
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
              Icon(
                Icons.format_quote_rounded,
                color: context.brandColor,
                size: 24,
              ),
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
                  // Italic only for Latin scripts — synthetic obliquing of
                  // Arabic/Urdu script renders poorly.
                  fontStyle: lang.isRtl ? FontStyle.normal : FontStyle.italic,
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
