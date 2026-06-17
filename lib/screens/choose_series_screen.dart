import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

// Arabic subtitle shown beneath the title, mirroring WelcomeScreen's
// bilingual title — independent of the app's UI language.
const _arChooseSeriesTitle = 'ابدأ رحلتك في التوحيد';

// Arabic title shown on the Arabic series' card, independent of the app's
// UI language — mirrors the lecture-title pattern in HomeScreen.
const _arBookTitle = 'كتاب التوحيد';

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
    // Go to WelcomeScreen (not straight to /lectures) so first-time users
    // see the series-specific splash before entering the app.
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final available = context.watch<SeriesProvider>().availableSeries;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  context.brandColor.withValues(alpha: 0.12),
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
                        const SizedBox(height: 4),
                        Text(
                          _arChooseSeriesTitle,
                          textAlign: TextAlign.center,
                          style: context.textTheme.titleMedium?.copyWith(
                            color: context.brandColor,
                            fontWeight: FontWeight.w600,
                          ),
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
                        AbsorbPointer(
                          absorbing: _switching,
                          child: Column(
                            children: [
                              for (var i = 0; i < available.length; i++) ...[
                                if (i > 0) const SizedBox(height: 16),
                                _SeriesCard(
                                  series: available[i],
                                  onTap: () => _select(available[i]),
                                ),
                              ],
                            ],
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.onTap});

  final SeriesConfig series;
  final VoidCallback onTap;

  /// Splits "Kitab at-Tawheed (Urdu)" into ("Kitab at-Tawheed", "Urdu") so
  /// the language qualifier can be shown as its own metric chip.
  static (String, String?) _splitTitle(String name) {
    final i = name.lastIndexOf(' (');
    if (i == -1 || !name.endsWith(')')) return (name, null);
    final suffix = name.substring(i + 2, name.length - 1);
    return (name.substring(0, i), suffix.isEmpty ? null : suffix);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final l10n = context.l10n;
    final displayName = lang.resolve(series.displayName);
    final speakerName = lang.resolve(series.speakerName);
    final (baseTitle, suffix) = _splitTitle(displayName);

    final titleWidget = SizedBox(
      width: double.infinity,
      child: Text(
        series.isRtl ? _arBookTitle : baseTitle,
        textAlign: series.isRtl ? TextAlign.right : null,
        style: context.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    final titleCell = series.isRtl
        ? Directionality(textDirection: TextDirection.rtl, child: titleWidget)
        : titleWidget;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LanguageThumbnail(series: series),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleCell,
                      if (suffix != null ||
                          series.hasStudyMode ||
                          series.hasBook) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (suffix != null) _MetricChip(label: suffix),
                            if (series.hasStudyMode)
                              _MetricChip(
                                icon: Icons.menu_book_rounded,
                                label: l10n.studyMode,
                              ),
                            if (series.hasBook)
                              _MetricChip(
                                icon: Icons.menu_book_rounded,
                                label: l10n.tabBook,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (speakerName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: context.groupedBorder),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: context.brandColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      speakerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: context.primaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gold square showing the series' content language in its own script — a
/// glanceable visual identifier distinguishing the Urdu and Arabic series.
class _LanguageThumbnail extends StatelessWidget {
  const _LanguageThumbnail({required this.series});

  final SeriesConfig series;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (series.language) {
      'ar' => l10n.languageArabic,
      'ur' => l10n.languageUrdu,
      _ => series.language.toUpperCase(),
    };

    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.brandColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: context.onBrandColor,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill used in a series card's metrics row — e.g. the language
/// qualifier or Study Mode availability.
class _MetricChip extends StatelessWidget {
  const _MetricChip({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: context.brandColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
