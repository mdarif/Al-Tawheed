import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Study Mode dashboard card — progress ring, headline, and a
/// Lectures / Classes / Duration stats row.
class StudyDashboardCard extends StatelessWidget {
  final int studiedCount;
  final int totalChapterCount;
  final int completedLectures;
  final int totalLectures;
  final int completedSeconds;
  final int totalSeconds;

  const StudyDashboardCard({
    super.key,
    required this.studiedCount,
    required this.totalChapterCount,
    required this.completedLectures,
    required this.totalLectures,
    required this.completedSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        totalChapterCount == 0 ? 0.0 : studiedCount / totalChapterCount;
    final percent = (fraction * 100).round();
    final complete =
        totalChapterCount > 0 && studiedCount == totalChapterCount;
    final durationFraction =
        totalSeconds == 0 ? 0.0 : completedSeconds / totalSeconds;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.groupedBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: context.surfaceTintColor,
                        color: context.brandColor,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.studyYourProgress.toUpperCase(),
                      style: context.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: context.brandColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.studyModeSubtitle(studiedCount, totalChapterCount),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      complete
                          ? l10n.studyOverallComplete
                          : l10n.studyOverallInProgress,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
            child: Divider(height: 1, color: context.dividerColor),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DashboardStat(
                    icon: Icons.headphones_rounded,
                    value: '$completedLectures / $totalLectures',
                    label: l10n.statLectures,
                  ),
                ),
                _StatDivider(color: context.dividerColor),
                Expanded(
                  child: _DashboardStat(
                    icon: Icons.menu_book_rounded,
                    value: '$studiedCount / $totalChapterCount',
                    label: l10n.statClasses,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
            child: Divider(height: 1, color: context.dividerColor),
          ),
          _DurationRow(
            label: l10n.statDuration,
            completed: DurationFormatter.toHoursMinutes(completedSeconds),
            total: DurationFormatter.toHoursMinutes(totalSeconds),
          ),
          const SizedBox(height: 8),
          _DurationProgressBar(fraction: durationFraction),
        ],
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DashboardStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: context.brandColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: context.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: context.secondaryTextColor,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;

  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: color,
    );
  }
}

class _DurationRow extends StatelessWidget {
  final String label;
  final String completed;
  final String total;

  const _DurationRow({
    required this.label,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 17, color: context.brandColor),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: context.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.secondaryTextColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        Text.rich(
          TextSpan(
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            children: [
              TextSpan(text: completed),
              TextSpan(
                text: ' / $total',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
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

class _DurationProgressBar extends StatelessWidget {
  final double fraction;

  const _DurationProgressBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: context.surfaceTintColor,
        valueColor: AlwaysStoppedAnimation<Color>(context.brandColor),
      ),
    );
  }
}
