import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Shown once to a genuinely fresh install when multi-series is enabled and
/// more than one series is on offer. Selecting a card switches to that
/// series and proceeds straight to the lectures list.
class ChooseSeriesScreen extends StatefulWidget {
  const ChooseSeriesScreen({super.key});

  @override
  State<ChooseSeriesScreen> createState() => _ChooseSeriesScreenState();
}

class _ChooseSeriesScreenState extends State<ChooseSeriesScreen> {
  bool _switching = false;

  Future<void> _select(SeriesConfig series) async {
    if (_switching) return;
    setState(() => _switching = true);
    await switchSeries(context, series);
    if (!mounted) return;
    context.go('/lectures');
  }

  @override
  Widget build(BuildContext context) {
    final available = context.watch<SeriesProvider>().availableSeries;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseSeriesTitle,
                style: context.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.chooseSeriesSubtitle,
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: context.secondaryTextColor),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _switching,
                  child: ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final series = available[index];
                      return _SeriesCard(
                        series: series,
                        onTap: () => _select(series),
                      );
                    },
                  ),
                ),
              ),
              if (_switching) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.onTap});

  final SeriesConfig series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final displayName = lang.resolve(series.displayName);
    final speakerName = lang.resolve(series.speakerName);
    final nativeName =
        series.displayName['ar'] as String? ?? series.displayName['ur'] as String?;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.groupedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.groupedBorder, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (nativeName != null) ...[
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        nativeName,
                        textAlign: TextAlign.right,
                        style: context.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                  if (speakerName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      speakerName,
                      style: context.textTheme.bodyMedium
                          ?.copyWith(color: context.secondaryTextColor),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: context.brandColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
