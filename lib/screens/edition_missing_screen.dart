import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/centered_scroll_body.dart';

/// Shown instead of silently falling back to Urdu (BLK-06) when the saved
/// content edition isn't in the loaded manifest — either it was genuinely
/// removed remotely, or the manifest fetch failed and fell back to the
/// bundled default. The saved id is never cleared here; only choosing a
/// different edition via [ChooseSeriesScreen] changes it.
class EditionMissingScreen extends StatefulWidget {
  const EditionMissingScreen({super.key});

  @override
  State<EditionMissingScreen> createState() => _EditionMissingScreenState();
}

/// Why the last Retry did not leave the screen.
enum _RetryFailure {
  /// The server answered, but its list still lacks the saved edition.
  stillMissing,

  /// The server could not be reached (or gave nothing usable).
  unreachable,
}

class _EditionMissingScreenState extends State<EditionMissingScreen> {
  bool _retrying = false;
  _RetryFailure? _failure;

  Future<void> _retry(BuildContext context) async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _failure = null;
    });
    final series = context.read<SeriesProvider>();
    // Force the network: a fresh (1h) cached manifest that lacks the edition
    // would otherwise be re-read and make Retry look broken.
    final reached = await series.loadManifest(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _failure = !reached
          ? _RetryFailure.unreachable
          : series.hasMissingSelectedSeries
              ? _RetryFailure.stillMissing
              : null;
    });
    // Still missing: stay here. The router-level redirect (RouteGuards.
    // missingEdition) confines the app to this screen and the edition picker
    // while hasMissingSelectedSeries holds, so there is nowhere else to go —
    // and nothing to "re-check" by navigating. Only a successful retry leaves,
    // and `/` then resolves the (now present) saved edition's own welcome or
    // Lectures.
    if (!series.hasMissingSelectedSeries && context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: CenteredScrollBody(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 52,
                  color: context.mutedIconColor,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.editionMissingTitle,
                  style: context.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.editionMissingMessage,
                  style: context.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (_failure != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _failure == _RetryFailure.unreachable
                          ? l10n.editionMissingUnreachable
                          : l10n.editionMissingStillUnavailable,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _retrying ? null : () => _retry(context),
                  icon: _retrying
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: context.onBrandColor,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed:
                      _retrying ? null : () => context.push('/choose-series'),
                  child: Text(l10n.editionMissingChooseAnother),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
