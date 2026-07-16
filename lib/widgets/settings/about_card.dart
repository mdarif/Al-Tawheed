import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/safe_url_launcher.dart';

/// Two-zone About card.
///
/// Top zone — content identity: cover image, app name, Arabic title, lecturer,
/// and (when configured) the official website.
/// Bottom strip — stats: lecture count, class/duration count, offline-ready indicator.
class AboutCard extends StatelessWidget {
  final AppConfigAbout about;
  final Catalog? catalog;

  /// Official website URL (e.g. `https://kitabattawheed.com`). Rendered as a
  /// centered, tappable bare domain under the lecturer line; hidden when null
  /// or empty. This is the website's permanent home now that the Settings
  /// "App" section is feature-gated.
  final String? website;

  const AboutCard({
    super.key,
    required this.about,
    this.catalog,
    this.website,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final about = this.about;
    final catalog = this.catalog;
    final book = catalog?.book;
    final lang = context.read<LanguageProvider>();

    final appName = book != null ? lang.resolve(book.title) : about.appName;
    final arabicTitle = book?.titleArabic ?? l10n.settingsAboutArabicTitle;
    final lecturer = book != null ? lang.resolve(book.speaker) : about.lecturer;
    final lectureCount = book?.lectureCount ?? about.lectureCount;
    final hasClasses = catalog?.chapters.isNotEmpty ?? true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.groupedBorder, width: 1),
        ),
        child: Column(
          children: [
            // ── Identity zone ──────────────────────────────────────────────
            Container(
              color: context.groupedSurface,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/tawheed.png',
                      width: 72,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appName,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    arabicTitle,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      color: context.brandColor,
                      fontFamily: 'NotoNaskhArabic',
                      letterSpacing: 0,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.settingsAboutBy(lecturer),
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.secondaryTextColor,
                      height: 1.5,
                    ),
                  ),
                  if (website != null && website!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _WebsiteLink(url: website!),
                  ],
                ],
              ),
            ),

            // ── Stats strip ────────────────────────────────────────────────
            Container(
              color: context.brandColor.withValues(alpha: 0.06),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _StatColumn(
                      value: context.digitsForSeries('$lectureCount'),
                      label: l10n.statLectures,
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: context.groupedBorder,
                    ),
                    if (hasClasses)
                      _StatColumn(
                        value: context.digitsForSeries(
                          '${catalog?.chapters.length ?? about.classCount}',
                        ),
                        label: l10n.statClasses,
                      )
                    else
                      _StatColumn(
                        value: context.hoursMinutesForSeries(
                          catalog!.book.totalDurationSeconds,
                        ),
                        label: l10n.statDuration,
                      ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: context.groupedBorder,
                    ),
                    _StatColumn(
                      icon: Icons.check_circle_rounded,
                      label: l10n.statOfflineReady,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered, tappable official-website link shown in the About identity zone.
/// Displays the bare domain (scheme stripped) and opens the URL externally,
/// falling back to a snackbar if the launch is blocked. Forced LTR so the
/// domain never mirrors under an RTL (Urdu/Arabic) UI.
class _WebsiteLink extends StatelessWidget {
  final String url;

  const _WebsiteLink({required this.url});

  @override
  Widget build(BuildContext context) {
    final domain = url
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceFirst(RegExp(r'/+$'), '');
    final color = context.brandColor;

    return Semantics(
      button: true,
      label: context.l10n.settingsVisitWebsite,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final launched = await launchExternalUrl(url);
          if (!launched) {
            messenger.showSnackBar(SnackBar(content: Text(domain)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              Text(
                domain,
                style: context.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.open_in_new_rounded, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String? value;
  final IconData? icon;
  final String label;

  const _StatColumn({this.value, this.icon, required this.label})
      : assert(value != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, size: 28, color: context.brandColor)
          else
            Text(
              value!,
              style: context.textTheme.titleLarge?.copyWith(
                color: context.brandColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 3),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.mutedIconColor,
            ),
          ),
        ],
      ),
    );
  }
}
