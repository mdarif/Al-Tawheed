import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/utils/duration_formatter.dart';


class LectureTile extends StatelessWidget {
  final Lecture lecture;
  final VoidCallback? onTap;

  const LectureTile({super.key, required this.lecture, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Lecture number badge with progress ring
            _ProgressBadge(lecture: lecture),
            const SizedBox(width: 14),
            // Title + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecture.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DurationFormatter.fromSeconds(lecture.durationSeconds),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Selector<ProgressProvider, bool>(
              selector: (_, p) => p.isBookmarked(lecture.id),
              builder: (_, isBookmarked, __) => Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.play_circle_outline_rounded,
                color:
                    isBookmarked ? AppColors.gold : AppColors.onDarkSecondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Number badge that doubles as a circular progress indicator.
class _ProgressBadge extends StatelessWidget {
  final Lecture lecture;
  const _ProgressBadge({required this.lecture});

  @override
  Widget build(BuildContext context) {
    return Selector<ProgressProvider, double>(
      selector: (_, p) => p.getFraction(lecture.id, lecture.durationSeconds),
      builder: (_, fraction, __) {
        final hasProgress = fraction > 0.01;
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerDark,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Circular progress overlay
              if (hasProgress)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.transparent,
                    color: fraction >= 0.99
                        ? AppColors.gold
                        : AppColors.gold.withValues(alpha: 0.6),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              // Number label
              Text(
                lecture.number.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: hasProgress ? AppColors.gold : AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
