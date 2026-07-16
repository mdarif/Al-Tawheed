import 'package:flutter/widgets.dart';
import 'package:myapp/l10n/app_localizations.dart';
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

/// Numbers in the app's chrome follow the **chrome locale**, exactly like the
/// words beside them — Arabic chrome counts ٠١، ٠٢, English chrome counts 01,
/// 02. A number is not more "content" than the label next to it.
///
/// The Book is the deliberate exception and does NOT use these: its chapter
/// badges, position indicator and inline āyah numbers key off
/// `series.language` via [localizedDigitsInString], because they are set in the
/// book's own script the way the print sets them — the Urdu book reads ۰۱ even
/// under English chrome. See ADR-0002.
extension ChromeNumerals on BuildContext {
  /// The language the chrome is *actually rendering in*.
  ///
  /// Read from [Localizations], not [LanguageProvider]: this is the locale the
  /// surrounding words resolved from, so digits and words agree by
  /// construction. (The two agree in production — `MaterialApp.locale` is fed
  /// by the provider — but only this one is true of the widget in front of the
  /// user.)
  String get _chromeLanguage {
    final locale = Localizations.localeOf(this);
    // Roman Urdu is `ur` + script `roman`, but it is written in Latin script —
    // Western digits, not ۰۱.
    return locale.scriptCode == 'roman' ? 'en' : locale.languageCode;
  }

  /// Re-renders every Western digit in [text] in the chrome locale's numerals.
  ///
  /// Idempotent — it only matches `[0-9]`, so it is safe on a string that is
  /// already part-converted (e.g. a count interpolated into an already-Arabic
  /// duration). Display text only: never URLs, version strings, or anything
  /// bound for the clipboard.
  String localizedDigits(String text) =>
      localizedDigitsInString(text, _chromeLanguage);

  /// A decimal number for the chrome locale. Arabic writes 1.5 as ١٫٥ — the
  /// separator (U+066B) differs, not just the digits, and ١.٥ reads as a
  /// half-translated string. Urdu is left with '.', which is what it uses in
  /// practice.
  String localizedDecimal(String text) {
    final localized = localizedDigits(text);
    return _chromeLanguage == 'ar'
        ? localized.replaceAll('.', '٫')
        : localized;
  }

  /// Face for the chrome locale's numerals, or null when Western digits are
  /// fine in the UI font. Urdu and Persian share U+06F0–06F9 but draw 4/5/6/7
  /// differently, and the UI font carries neither set — so without this the
  /// platform picks a Persian-style fallback.
  String? get numeralFontFamily => switch (_chromeLanguage) {
        'ur' => 'NotoNastaliqUrdu',
        'ar' => 'NotoNaskhArabic',
        _ => null,
      };

  /// A position/length time: "35:57" → "٣٥:٥٧".
  String localizedTime(int seconds) =>
      localizedDigits(DurationFormatter.fromSeconds(seconds));

  /// A total listening time: "27h 6m" / "٢٣ س ١٩ د" / "۲۳ گھنٹے ۱۹ منٹ".
  String localizedHoursMinutes(int seconds) {
    final (hours, minutes) = DurationFormatter.toHoursAndMinutes(seconds);
    return hours > 0
        ? l10n.durationHoursMinutes(
            localizedDigits('$hours'),
            localizedDigits('$minutes'),
          )
        : l10n.durationMinutes(localizedDigits('$minutes'));
  }
}
