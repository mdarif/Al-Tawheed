import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Overall study progress — e.g. "3 of 15 classes studied" plus an
/// overall-progress bar.
class OverallProgressSummary extends StatelessWidget {
  final int studiedCount;
  final int totalCount;

  const OverallProgressSummary({
    super.key,
    required this.studiedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = totalCount == 0 ? 0.0 : studiedCount / totalCount;
    final percent = (fraction * 100).round();
    final complete = totalCount > 0 && studiedCount == totalCount;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.groupedBorder, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: context.progressTrackColor,
                        color: context.brandColor,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
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
                      l10n.studyModeSubtitle(studiedCount, totalCount),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (complete) ...[
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 16,
                            color: context.brandColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            complete
                                ? l10n.studyOverallComplete
                                : l10n.studyOverallInProgress,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.adjust_rounded,
                    size: 17,
                    color: context.brandColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.studyOverallProgress.toUpperCase(),
                    style: context.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.secondaryTextColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '$percent%',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: context.surfaceTintColor,
              valueColor: AlwaysStoppedAnimation<Color>(context.brandColor),
            ),
          ),
        ],
      ),
    );
  }
}
