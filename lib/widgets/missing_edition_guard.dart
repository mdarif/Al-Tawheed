import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/series_provider.dart';

/// Wraps the whole app (inside `MaterialApp.router`'s `builder:`) and
/// reactively pushes `/edition-missing` whenever the saved content edition
/// stops resolving — a manifest that no longer lists it, or a fetch that
/// failed and fell back to the bundled default (BLK-06).
///
/// This can't be a `redirect:` on a single route: go_router only re-runs
/// redirects on navigation, not when a provider notifies, and the saved
/// edition can go missing well after the user already reached `/lectures`
/// (the common case — most returning users skip WelcomeScreen entirely).
/// Wrapping the router's `child` here means every route rebuilds through
/// one place that's always mounted for the life of the app.
///
/// Takes [router] directly rather than resolving it via `GoRouter.of(
/// context)`: this widget sits in `MaterialApp.router`'s `builder:`, wrapping
/// `child` from the *outside* — its own context is therefore an ancestor of
/// the Router that `child` contains, not a descendant, so `GoRouter.of`
/// cannot find it from here.
class MissingEditionGuard extends StatefulWidget {
  final GoRouter router;
  final Widget child;

  const MissingEditionGuard({
    super.key,
    required this.router,
    required this.child,
  });

  @override
  State<MissingEditionGuard> createState() => _MissingEditionGuardState();
}

class _MissingEditionGuardState extends State<MissingEditionGuard> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final missing = context.watch<SeriesProvider>().hasMissingSelectedSeries;
    if (missing && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.router.state.uri.path != '/edition-missing') {
          unawaited(widget.router.push('/edition-missing'));
        }
      });
    } else if (!missing && _showing) {
      // Resolved (retry succeeded, or the user picked another edition) —
      // allow a future recurrence to trigger this again.
      _showing = false;
    }
    return widget.child;
  }
}
