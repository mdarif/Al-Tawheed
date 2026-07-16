import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/utils/duration_formatter.dart';

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

/// Numbers shown to the reader follow the **content edition**, while the words
/// around them follow the chrome locale. The two axes are genuinely separate:
/// an Urdu reader with English chrome still reads `۰۱`, because the numerals
/// belong to the text they sit beside, not to the app's furniture.
extension SeriesNumerals on BuildContext {
  /// Re-renders every Western digit in [text] in the active edition's numerals.
  ///
  /// Idempotent — it only matches `[0-9]`, so it is safe on a string that is
  /// already part-converted (e.g. a count interpolated into an already-Arabic
  /// duration). Display text only: never URLs, version strings, or anything
  /// bound for the clipboard.
  String digitsForSeries(String text) => localizedDigitsInString(
        text,
        watch<SeriesProvider>().currentSeries.language,
      );

  /// A position/length time: "35:57" → "٣٥:٥٧" / "۳۵:۵۷".
  String timeForSeries(int seconds) =>
      digitsForSeries(DurationFormatter.fromSeconds(seconds));

  /// A total listening time: "27h 6m" / "٢٣ س ١٩ د" / "۲۳ گھنٹے ۱۹ منٹ".
  /// Digits from the edition, words from the chrome locale.
  String hoursMinutesForSeries(int seconds) {
    final (hours, minutes) = DurationFormatter.toHoursAndMinutes(seconds);
    return hours > 0
        ? l10n.durationHoursMinutes(
            digitsForSeries('$hours'),
            digitsForSeries('$minutes'),
          )
        : l10n.durationMinutes(digitsForSeries('$minutes'));
  }
}
