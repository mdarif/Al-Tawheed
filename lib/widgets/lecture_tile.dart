import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/duration_formatter.dart';

class LectureTile extends StatelessWidget {
  final Lecture lecture;
  final VoidCallback? onTap;

  const LectureTile({super.key, required this.lecture, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _ProgressBadge(lecture: lecture),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecture.title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DurationFormatter.fromSeconds(lecture.durationSeconds),
                    style: context.textTheme.bodySmall?.copyWith(fontSize: 12),
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
                color: isBookmarked ? context.brandColor : context.mutedIconColor,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.elevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              if (hasProgress)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.transparent,
                    color: fraction >= 0.99
                        ? context.brandColor
                        : context.brandColor.withValues(alpha: 0.6),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              Text(
                lecture.number.toString().padLeft(2, '0'),
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.brandColor,
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
