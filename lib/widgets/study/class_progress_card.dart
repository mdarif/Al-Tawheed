import 'package:flutter/material.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

class ClassProgressCard extends StatelessWidget {
  final ChapterStudyInfo info;
  final VoidCallback onTap;

  const ClassProgressCard({
    super.key,
    required this.info,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chapter = info.chapter;

    return Material(
      color: info.isRecommended
          ? context.semantic.brandSubtle.withValues(
              alpha: context.isDarkTheme ? 0.35 : 0.5,
            )
          : context.groupedSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: info.isRecommended
                  ? context.brandColor.withValues(alpha: 0.45)
                  : context.groupedBorder,
              width: info.isRecommended ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chapter.title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _StatusBadge(status: info.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${info.totalParts} ${info.totalParts == 1 ? 'part' : 'parts'}',
                style: context.textTheme.bodySmall,
              ),
              if (info.isRecommended) ...[
                const SizedBox(height: 6),
                Text(
                  'Recommended next',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.brandColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: info.status == ChapterStudyStatus.studied
                      ? 1.0
                      : info.fraction,
                  backgroundColor: context.progressTrackColor,
                  color: context.brandColor,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _progressLabel(info),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _progressLabel(ChapterStudyInfo info) {
    if (info.status == ChapterStudyStatus.studied) {
      return 'Studied';
    }
    if (info.completedParts == 0) return 'Not started';
    return '${info.completedParts} of ${info.totalParts} parts complete';
  }
}

class _StatusBadge extends StatelessWidget {
  final ChapterStudyStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ChapterStudyStatus.studied => ('Studied', context.brandColor),
      ChapterStudyStatus.inProgress => (
          'In progress',
          context.semantic.brandEmphasis,
        ),
      ChapterStudyStatus.notStarted => (
          'Not started',
          context.mutedIconColor,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
