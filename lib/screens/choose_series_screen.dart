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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.brandColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: context.brandColor,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.chooseSeriesTitle,
                textAlign: TextAlign.center,
                style: context.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: context.brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _switching,
                  child: ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
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

  /// Splits "Kitab at-Tawheed (Urdu)" into ("Kitab at-Tawheed", "(Urdu)") so
  /// the language qualifier can be highlighted in the brand color.
  static (String, String?) _splitTitle(String name) {
    final i = name.lastIndexOf(' (');
    if (i == -1) return (name, null);
    return (name.substring(0, i), name.substring(i + 1));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final displayName = lang.resolve(series.displayName);
    final speakerName = lang.resolve(series.speakerName);
    final (baseTitle, suffix) = _splitTitle(displayName);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.groupedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.groupedBorder, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: context.brandColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baseTitle,
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (suffix != null)
                    Text(
                      suffix,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: context.brandColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (speakerName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: context.groupedBorder),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: context.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            speakerName,
                            style: context.textTheme.bodySmall?.copyWith(
                                color: context.secondaryTextColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.elevatedSurface,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.brandColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
