import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/study_session.dart';
import 'package:myapp/widgets/study/class_progress_card.dart';
import 'package:myapp/widgets/study/overall_progress_summary.dart';

class StudyClassCompleteScreen extends StatelessWidget {
  final String chapterId;

  const StudyClassCompleteScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>().catalog;
    final study = context.watch<StudyProgressProvider>();
    final lang = context.read<LanguageProvider>();
    final l10n = context.l10n;

    Chapter? chapter;
    if (catalog != null) {
      try {
        chapter = catalog.chapterById(chapterId);
      } catch (_) {
        chapter = null;
      }
    }
    final title = chapter != null ? lang.resolve(chapter.title) : null;

    final nextChapter = study.recommendedChapter;
    final isSeriesComplete = nextChapter == null &&
        study.totalChapterCount > 0 &&
        study.studiedCount == study.totalChapterCount;
    ChapterStudyInfo? nextInfo;
    if (nextChapter != null) {
      for (final info in study.chapterInfos()) {
        if (info.chapter.id == nextChapter.id) {
          nextInfo = info;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          isSeriesComplete ? l10n.studySeriesComplete : l10n.studyClassComplete,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CelebrationCard(
            title: title,
            isSeriesComplete: isSeriesComplete,
          ),
          const SizedBox(height: 24),
          OverallProgressSummary(
            studiedCount: study.studiedCount,
            totalCount: study.totalChapterCount,
          ),
          if (nextInfo != null) ...[
            const SizedBox(height: 24),
            Text(
              l10n.studyNextUp,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClassProgressCard(
              info: nextInfo,
              onTap: () => _continueToNext(context, nextInfo!.chapter.id),
            ),
          ],
          const SizedBox(height: 24),
          if (nextChapter != null) ...[
            FilledButton.icon(
              onPressed: () => _continueToNext(context, nextChapter.id),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                l10n.studyContinueToNext(lang.resolve(nextChapter.title)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/study'),
              child: Text(l10n.studyBackToOverview),
            ),
          ] else
            FilledButton(
              onPressed: () => context.go('/study'),
              child: Text(l10n.studyBackToOverview),
            ),
        ],
      ),
    );
  }

  void _continueToNext(BuildContext context, String chapterId) {
    startStudySession(context, chapterId, replaceRoute: true);
  }
}

/// Celebratory header — completion ring, two-tone title, and a short dua.
/// When [isSeriesComplete] is true the card switches to a richer "all done"
/// variant with a different headline and a longer celebratory message.
class _CelebrationCard extends StatelessWidget {
  final String? title;
  final bool isSeriesComplete;

  const _CelebrationCard({
    required this.title,
    this.isSeriesComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [semantic.accentGradientStart, semantic.accentGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.brandColor.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: context.brandColor.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const _CompletionBadge(),
          const SizedBox(height: 18),
          if (isSeriesComplete) ...[
            Text(
              l10n.studySeriesCompleteTitle,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.brandColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.studySeriesCompleteCelebration,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text.rich(
              TextSpan(
                style: context.textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                children: title != null
                    ? [
                        TextSpan(text: '$title '),
                        TextSpan(
                          text: l10n.studyCompletedLabel,
                          style: TextStyle(color: context.brandColor),
                        ),
                      ]
                    : [TextSpan(text: l10n.studyClassCompleteFallback)],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.studyCelebrationMessage,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          const _StepIndicator(),
        ],
      ),
    );
  }
}

/// Gold ring with a checkmark, decorated with a few sparkle accents.
class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge();

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColor;
    final sparkle = context.colorScheme.secondary;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -10,
          left: -8,
          child: _Sparkle(color: sparkle, size: 11, opacity: 0.65),
        ),
        Positioned(
          top: -14,
          right: 6,
          child: _Sparkle(color: sparkle, size: 7, opacity: 0.4),
        ),
        Positioned(
          bottom: 4,
          left: -16,
          child: _Sparkle(color: sparkle, size: 6, opacity: 0.35),
        ),
        Positioned(
          bottom: -10,
          right: -10,
          child: _Sparkle(color: sparkle, size: 9, opacity: 0.55),
        ),
        Positioned(
          top: 30,
          right: -16,
          child: _Sparkle(color: sparkle, size: 5, opacity: 0.3),
        ),
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: brand, width: 3),
            gradient: RadialGradient(
              colors: [
                brand.withValues(alpha: 0.15),
                brand.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.72],
            ),
          ),
          child: Icon(Icons.check_rounded, size: 44, color: brand),
        ),
      ],
    );
  }
}

class _Sparkle extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Sparkle({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// Decorative dash–diamond–dash marking progress through the class sequence.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: context.brandColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: context.brandColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: context.dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
