import 'package:myapp/models/series.dart';

/// Pure redirect predicates for the app router (see `lib/app.dart`).
///
/// Extracted from the inline `GoRoute` `redirect:` closures so the *redirect
/// matrix* — the logic that decides whether a deep link (or a stale in-app nav)
/// into `/book` or `/study` is honoured or bounced to `/lectures` — can be
/// unit-tested without standing up the full provider tree and the `AudioService`
/// process singleton. That singleton is exactly why `MyApp` has no widget test
/// (see test-plan "Not worth doing"), which is what left this logic unguarded.
///
/// `app.dart` reads the live `SeriesProvider` state and passes it in; the
/// decision lives here, in one place, with no Flutter or provider dependency.
abstract final class RouteGuards {
  /// Where every guard sends a request it refuses — the always-present tab.
  static const lectures = '/lectures';

  /// `/book` exists only for a series that bundles a book asset. A deep link or
  /// stale nav into `/book` on a series without one is bounced to the lecture
  /// list. Returning `null` means "no redirect — allow the route".
  static String? book(SeriesConfig series) => series.hasBook ? null : lectures;

  /// `/study` likewise requires the series to offer study mode.
  static String? study(SeriesConfig series) =>
      series.hasStudyMode ? null : lectures;

  /// `/` (welcome / splash): a returning user — one who has already seen the
  /// welcome for the current edition — skips straight to the lecture list, so
  /// they never see a single frame of `WelcomeScreen`. [shouldShowWelcome] is
  /// `SeriesProvider.shouldShowWelcomeForCurrentSeries`.
  static String? welcome({required bool shouldShowWelcome}) =>
      shouldShowWelcome ? null : lectures;
}
