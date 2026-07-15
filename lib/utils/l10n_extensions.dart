import 'package:flutter/widgets.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/series.dart';

/// Shared, stateless Arabic localisations. Still used directly by the first-run
/// Welcome screen for its Arabic-edition branding; AppLocalizations instances
/// hold no mutable state, so one shared instance is safe to reuse.
final AppLocalizations arabicL10n = lookupAppLocalizations(const Locale('ar'));

extension L10nBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// AppLocalizations for chrome shown alongside [series]'s content.
  ///
  /// Chrome/UI language is intentionally **independent** of the content edition:
  /// this returns the app UI localizations for every series, so switching to the
  /// Arabic edition keeps the user's chosen (or device-detected) chrome instead
  /// of forcing Arabic. Content itself still renders per-edition — see
  /// [LanguageProvider.resolveForSeries]. Kept as the single chokepoint all
  /// series-adjacent chrome flows through, rather than inlining `l10n` at ~13
  /// call sites.
  AppLocalizations l10nForSeries(SeriesConfig series) => l10n;
}
