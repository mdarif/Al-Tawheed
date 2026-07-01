import 'package:flutter/widgets.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';

/// Shared, stateless Arabic localisations used to force Arabic chrome on the
/// Arabic content series regardless of the app UI language. AppLocalizations
/// instances hold no mutable state, so one shared instance is safe to reuse.
final AppLocalizations arabicL10n = lookupAppLocalizations(const Locale('ar'));

extension L10nBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// AppLocalizations for chrome shown alongside [series]'s content. An
  /// Arabic-content series (`series.isRtl`) always renders Arabic chrome
  /// regardless of the app UI language; every other series follows the app UI
  /// locale. Replaces the old `isArabic ? _arXxx : l10n.xxx` hardcoding.
  AppLocalizations l10nForSeries(SeriesConfig series) =>
      series.isRtl ? arabicL10n : l10n;
}
