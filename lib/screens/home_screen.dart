import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_colors.dart';
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

// ── Continue Listening ────────────────────────────────────────────────────────

class _ContinueListeningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final catalog = context.watch<CatalogProvider>();

    final lastId = progress.lastLectureId;

    // Not shown if no history or catalog not loaded yet
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
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
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.surfaceContainerDark,
                width: 1,
              ),
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
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.headphones_rounded,
                        color: AppColors.gold,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${DurationFormatter.fromSeconds(savedSeconds)} listened'
                            ' · ${DurationFormatter.fromSeconds(remaining)} left',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onDarkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
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
                    backgroundColor: AppColors.surfaceContainerDark,
                    color: AppColors.gold,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(fraction * 100).round()}% complete',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onDarkSecondary,
                  ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.surfaceContainerDark,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.headphones_rounded,
                  size: 36, color: AppColors.onDarkSecondary),
              const SizedBox(height: 10),
              Text(
                'Start a lecture to resume here',
                style: TextStyle(
                  color: AppColors.onDarkSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Daily Benefit ─────────────────────────────────────────────────────────────

class _DailyBenefitCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

    if (catalog.status != CatalogStatus.loaded ||
        catalog.catalog!.dailyBenefits.isEmpty) {
      return const SizedBox.shrink();
    }

    // Rotate through benefits by day of year
    final benefits = catalog.catalog!.dailyBenefits;
    final dayIndex = DateTime.now().difference(DateTime(2026)).inDays;
    final benefit = benefits[dayIndex % benefits.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Benefit',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.15),
                AppColors.gold.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded,
                  color: AppColors.gold, size: 24),
              const SizedBox(height: 10),
              Text(
                benefit.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '— ${benefit.source}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gold,
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
