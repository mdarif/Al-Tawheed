import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/utils/l10n_extensions.dart';

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
    final l10n = context.l10n;

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
                      context.read<LanguageProvider>().resolve(chapter.title),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _StatusBadge(status: info.status, l10n: l10n),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.partsCount(info.totalParts),
                style: context.textTheme.bodySmall,
              ),
              if (info.isRecommended) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.studyRecommendedNext,
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
                _progressLabel(info, l10n),
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

  static String _progressLabel(ChapterStudyInfo info, AppLocalizations l10n) {
    if (info.status == ChapterStudyStatus.studied) {
      return l10n.studyStatusStudied;
    }
    if (info.completedParts == 0) return l10n.studyStatusNotStarted;
    return l10n.studyPartsComplete(info.completedParts, info.totalParts);
  }
}

class _StatusBadge extends StatelessWidget {
  final ChapterStudyStatus status;
  final AppLocalizations l10n;

  const _StatusBadge({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ChapterStudyStatus.studied => (l10n.studyStatusStudied, context.brandColor),
      ChapterStudyStatus.inProgress => (
          l10n.studyStatusInProgress,
          context.semantic.brandEmphasis,
        ),
      ChapterStudyStatus.notStarted => (
          l10n.studyStatusNotStarted,
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
