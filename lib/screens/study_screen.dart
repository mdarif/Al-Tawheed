import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/study_session.dart';
import 'package:myapp/widgets/catalog_connect_required.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/study/class_progress_card.dart';
import 'package:myapp/widgets/study/study_dashboard_card.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      if (catalog.status == CatalogStatus.idle) {
        catalog.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyMode),
      ),
      body: switch (catalog.status) {
        CatalogStatus.idle || CatalogStatus.loading => Center(
            child: CircularProgressIndicator(color: context.brandColor),
          ),
        CatalogStatus.error => catalog.needsOnlineToLoad
            ? CatalogConnectRequiredBody(provider: catalog)
            : _ErrorBody(
                message: catalog.error ?? l10n.studyCouldNotLoadClasses,
                onRetry: catalog.load,
              ),
        CatalogStatus.loaded => _StudyBody(
            onClassTap: (info) => _onClassTap(context, info),
          ),
      },
    );
  }

  Future<void> _onClassTap(BuildContext context, ChapterStudyInfo info) async {
    final l10n = context.l10n;
    final lang = context.read<LanguageProvider>();
    final title = lang.resolve(info.chapter.title);

    if (info.status == ChapterStudyStatus.studied) {
      final restart = await showConfirmDialog(
        context,
        title: l10n.studyRestartTitle(title),
        message: l10n.studyRestartMessage,
        confirmLabel: l10n.studyRestart,
        filledConfirm: true,
      );
      if (!restart || !context.mounted) return;
      startStudySession(context, info.chapter.id, restartStudied: true);
      return;
    }

    startStudySession(context, info.chapter.id);
  }
}

class _StudyBody extends StatelessWidget {
  final ValueChanged<ChapterStudyInfo> onClassTap;

  const _StudyBody({required this.onClassTap});

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProgressProvider>();
    final infos = study.chapterInfos();
    final stats = study.stats;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StudyDashboardCard(
          studiedCount: study.studiedCount,
          totalChapterCount: study.totalChapterCount,
          completedLectures: stats.completedLectures,
          totalLectures: stats.totalLectures,
          completedSeconds: stats.completedSeconds,
          totalSeconds: stats.totalSeconds,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.studyClasses,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final info in infos) ...[
          ClassProgressCard(
            info: info,
            onTap: () => onClassTap(info),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 52, color: context.mutedIconColor),
            const SizedBox(height: 20),
            Text(
              l10n.studyCouldNotLoadClasses,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
