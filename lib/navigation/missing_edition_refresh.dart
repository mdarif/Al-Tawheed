import 'package:flutter/foundation.dart';
import 'package:myapp/providers/series_provider.dart';

/// Tells the router to re-run its redirects exactly when the saved edition
/// goes missing or comes back (BLK-06) — the `refreshListenable` for
/// `createAppRouter`.
///
/// go_router only re-evaluates `redirect:` on navigation, but the manifest
/// fetch that reveals a missing edition completes well after the user already
/// reached `/lectures`. Listening to [SeriesProvider] directly would refresh
/// on every unrelated notification (welcome seen, selection, ...) and re-run
/// every route's redirect each time; this fires only when
/// `hasMissingSelectedSeries` actually flips.
class MissingEditionRefresh extends ChangeNotifier {
  final SeriesProvider _series;
  bool _missing;

  MissingEditionRefresh(this._series)
      : _missing = _series.hasMissingSelectedSeries {
    _series.addListener(_onSeriesChanged);
  }

  void _onSeriesChanged() {
    final missing = _series.hasMissingSelectedSeries;
    if (missing == _missing) return;
    _missing = missing;
    notifyListeners();
  }

  @override
  void dispose() {
    _series.removeListener(_onSeriesChanged);
    super.dispose();
  }
}
