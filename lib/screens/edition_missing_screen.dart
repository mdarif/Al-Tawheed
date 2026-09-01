import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

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

class _EditionMissingScreenState extends State<EditionMissingScreen> {
  bool _retrying = false;

  Future<void> _retry(BuildContext context) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await context.read<SeriesProvider>().loadManifest();
    if (!mounted) return;
    setState(() => _retrying = false);
    if (!context.mounted) return;
    // Router redirect re-checks hasMissingSelectedSeries on the next
    // navigation; going to / re-triggers it whether or not this retry fixed
    // things.
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
