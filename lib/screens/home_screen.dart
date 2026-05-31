import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Home'),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ContinueListeningCard(),
                const SizedBox(height: 24),
                _DailyBenefitCard(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Listening',
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
                            lecture.title,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${DurationFormatter.fromSeconds(savedSeconds)} listened'
                            ' · ${DurationFormatter.fromSeconds(remaining)} left',
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
                  '${(fraction * 100).round()}% complete',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Listening',
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
                'Start a lecture to resume here',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Benefit',
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
                benefit.text,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: context.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '— ${benefit.source}',
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
