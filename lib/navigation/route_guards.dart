import 'package:myapp/models/series.dart';
import 'package:myapp/navigation/series_navigation_policy.dart';

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

  /// `/read` exists only for a series that bundles a book and/or offers study
  /// mode. A deep link or stale nav into `/read` on a series with neither is
  /// bounced to the lecture list. Returning `null` means "no redirect — allow
  /// the route".
  static String? read(SeriesConfig series) =>
      SeriesNavigationPolicy.isAvailable(series, SeriesNavigationTab.read)
          ? null
          : lectures;

  /// `/` (welcome / splash): a returning user — one who has already seen the
  /// welcome for the current edition — skips straight to the lecture list, so
  /// they never see a single frame of `WelcomeScreen`. [shouldShowWelcome] is
  /// `SeriesProvider.shouldShowWelcomeForCurrentSeries`.
  static String? welcome({required bool shouldShowWelcome}) =>
      shouldShowWelcome ? null : lectures;

  /// Recovery screen shown when the saved edition is not in the manifest.
  static const editionMissing = '/edition-missing';

  /// The edition picker — the "choose another edition" recovery path.
  static const chooseSeries = '/choose-series';

  /// App-wide guard (BLK-06): while the saved edition is missing from the
  /// manifest, [SeriesProvider.currentSeries] silently resolves to the Urdu
  /// fallback, so *no* content route may be reachable — a deep link, Back, a
  /// failed Retry would all otherwise show Urdu under the user's saved edition.
  /// Everything except the recovery screen and the picker is sent to
  /// [editionMissing]. [isMissing] is
  /// `SeriesProvider.hasMissingSelectedSeries`; [path] is the requested
  /// location's path. `null` means "no redirect — allow the route".
  static String? missingEdition({
    required bool isMissing,
    required String path,
  }) {
    if (!isMissing) return null;
    if (path == editionMissing || path == chooseSeries) return null;
    return editionMissing;
  }
}
