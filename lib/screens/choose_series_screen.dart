import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

// Arabic title shown on the Arabic series' card, independent of the app's
// UI language — mirrors the lecture-title pattern in ContinueListeningBanner.
const _arBookTitle = 'كتاب التوحيد';

// Native script subtitles — gives each card its cultural identity.
const _urNativeTitle = 'شرح کتاب التوحید'; // Urdu ک (U+06A9) ی (U+06CC)
const _arNativeTitle = 'شرح كتاب التوحيد'; // Arabic ك (U+0643) ي (U+064A)

const _arSpeakerFallback = 'الشيخ صالح الفوزان حفظه الله';

/// Shown once to a genuinely fresh install when multi-series is enabled and
/// more than one series is on offer. Selecting a card switches to that
/// series and proceeds straight to the lectures list.
class ChooseSeriesScreen extends StatefulWidget {
  const ChooseSeriesScreen({super.key});

  @override
  State<ChooseSeriesScreen> createState() => _ChooseSeriesScreenState();
}

class _ChooseSeriesScreenState extends State<ChooseSeriesScreen> {
  // The id of the series currently being switched to, or null when idle. Used
  // to show an in-card spinner on the tapped card rather than a loose loader.
  String? _selectingId;

  Future<void> _select(SeriesConfig series) async {
    if (_selectingId != null) return;
    setState(() => _selectingId = series.id);
    final sp = context.read<SeriesProvider>();
    final previousId = sp.currentSeries.id;
    await switchSeries(context, series);
    if (!mounted) return;
    if (series.id == previousId) {
      // User confirmed the series that was already showing on the welcome
      // screen — mark it seen so the router sends them straight to lectures.
      sp.markWelcomeSeenForCurrentSeries();
    }
    // Navigate to / — router shows the new series' welcome if not yet seen,
    // or redirects to /lectures if already seen.
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
                      horizontal: 24,
                      vertical: 32,
                    ),
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
                        const SizedBox(height: 4),
                        Text(
                          'Select a series to begin learning',
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.secondaryTextColor,
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
                          absorbing: _selectingId != null,
                          child: Column(
                            children: [
                              for (var i = 0; i < available.length; i++) ...[
                                if (i > 0) const SizedBox(height: 16),
                                _SeriesCard(
                                  series: available[i],
                                  loading: _selectingId == available[i].id,
                                  onTap: () => _select(available[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
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
  const _SeriesCard({
    required this.series,
    required this.onTap,
    this.loading = false,
  });

  final SeriesConfig series;
  final VoidCallback onTap;
  final bool loading;

  /// Strips a leading honorific ("Shaikh", "Fazilat Shaikh", "الشيخ") from a
  /// speaker name so the card shows the shorter, more glanceable form — e.g.
  /// "Shaikh Abdullah Nasir Rahmani Hafizahullah" → "Abdullah Nasir Rahmani
  /// Hafizahullah".
  static String _shortenSpeaker(String name) {
    const prefixes = ['Fazilat Shaikh ', 'Shaikh ', 'Sheikh ', 'الشيخ '];
    for (final p in prefixes) {
      if (name.startsWith(p)) return name.substring(p.length).trim();
    }
    return name;
  }

  /// Drops the trailing language qualifier from "Kitab at-Tawheed (Urdu)" so
  /// the card title reads cleanly — the language is conveyed by the thumbnail
  /// and the audio chip instead.
  static String _baseTitle(String name) {
    final i = name.lastIndexOf(' (');
    if (i == -1 || !name.endsWith(')')) return name;
    return name.substring(0, i);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final l10n = context.l10n;
    final displayName = lang.resolve(series.displayName);
    final speakerName = _shortenSpeaker(lang.resolve(series.speakerName));
    final baseTitle = _baseTitle(displayName);

    final titleWidget = SizedBox(
      width: double.infinity,
      child: Text(
        series.isRtl ? _arBookTitle : baseTitle,
        textAlign: series.isRtl ? TextAlign.right : null,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFamily: series.isRtl ? 'NotoNaskhArabic' : null,
          letterSpacing: series.isRtl ? 0 : null,
        ),
      ),
    );
    final titleCell = series.isRtl
        ? Directionality(textDirection: TextDirection.rtl, child: titleWidget)
        : titleWidget;

    return Material(
      // A subtle raised surface so the card reads as tappable at rest, with the
      // InkWell ripple confirming the tap — no drastic restyle.
      color: context.groupedSurface,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.groupedBorder, width: 1),
          ),
          child: Stack(
            children: [
              Column(
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
                            if (series.language == 'ur' ||
                                series.language == 'ar') ...[
                              const SizedBox(height: 4),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    series.language == 'ar'
                                        ? _arNativeTitle
                                        : _urNativeTitle,
                                    textAlign: TextAlign.right,
                                    style:
                                        context.textTheme.bodyMedium?.copyWith(
                                      color: context.brandColor,
                                      fontFamily: 'NotoNaskhArabic',
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetricChip(
                                  icon: Icons.headphones_rounded,
                                  label: l10n.audioLabel,
                                ),
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
                        ),
                      ),
                    ],
                  ),
                  if (speakerName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: context.groupedBorder),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: context.brandColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                speakerName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.primaryTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (series.isRtl) ...[
                                const SizedBox(height: 4),
                                Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      _shortenSpeaker(
                                        (series.speakerName['ar'] as String?) ??
                                            _arSpeakerFallback,
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          context.textTheme.bodySmall?.copyWith(
                                        color: context.secondaryTextColor,
                                        fontFamily: 'NotoNaskhArabic',
                                        fontSize: 13,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              // While this card's series is being switched to, dim the content
              // and centre a spinner over the card itself — keeps the feedback
              // anchored to what the user tapped instead of a loose loader.
              if (loading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.groupedSurface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: context.brandColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.brandColor,
        borderRadius: BorderRadius.circular(14),
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
              fontSize: 18,
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
