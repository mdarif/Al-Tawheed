import 'package:flutter/widgets.dart';
import 'package:myapp/l10n/app_localizations.dart';

/// Shared, stateless Arabic localisations. Still used directly by the first-run
/// Welcome screen, which renders before the active edition is definitive;
/// AppLocalizations instances hold no mutable state, so one shared instance is
/// safe to reuse.
final AppLocalizations arabicL10n = lookupAppLocalizations(const Locale('ar'));

extension L10nBuildContext on BuildContext {
  /// The one chrome locale. Never fork chrome on the content edition: the
  /// edition already steers chrome by supplying the *default* app language
  /// (see [LanguageProvider.applySeriesDefault]), so by the time a widget
  /// reads this, it is Arabic on the Arabic edition anyway — and forking here
  /// would override the user's explicit pick, which is the bug 5cc657e was
  /// written to fix. Content itself still renders per-edition via
  /// [LanguageProvider.resolveForSeries].
  AppLocalizations get l10n => AppLocalizations.of(this);
}
