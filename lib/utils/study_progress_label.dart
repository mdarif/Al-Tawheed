import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/study_progress.dart';

/// Caption for a class card's progress row — e.g. "2 of 2 parts complete"
/// or "3 parts" for a class not yet started.
String studyProgressLabel(ChapterStudyInfo info, AppLocalizations l10n) {
  if (info.status == ChapterStudyStatus.studied) {
    return l10n.studyPartsComplete(info.totalParts, info.totalParts);
  }
  if (info.completedParts == 0) return l10n.partsCount(info.totalParts);
  return l10n.studyPartsComplete(info.completedParts, info.totalParts);
}
