import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/study_progress.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/study_session.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/study/class_progress_card.dart';
import 'package:myapp/widgets/study/overall_progress_summary.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Mode'),
      ),
      body: switch (catalog.status) {
        CatalogStatus.idle || CatalogStatus.loading => Center(
            child: CircularProgressIndicator(color: context.brandColor),
          ),
        CatalogStatus.error => _ErrorBody(
            message: catalog.error ?? 'Could not load classes',
            onRetry: catalog.load,
          ),
        CatalogStatus.loaded => _StudyBody(
            onClassTap: (info) => _onClassTap(context, info),
          ),
      },
    );
  }

  Future<void> _onClassTap(BuildContext context, ChapterStudyInfo info) async {
    if (info.status == ChapterStudyStatus.studied) {
      final restart = await showConfirmDialog(
        context,
        title: 'Restart ${info.chapter.title.en}?',
        message:
            'This class is already studied. Restart from the first part?',
        confirmLabel: 'Restart',
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        OverallProgressSummary(
          studiedCount: study.studiedCount,
          totalCount: study.totalChapterCount,
        ),
        const SizedBox(height: 24),
        Text(
          'Classes',
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
              'Could not load classes',
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
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
