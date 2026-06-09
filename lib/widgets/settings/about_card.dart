import 'package:flutter/material.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Two-zone About card.
///
/// Top zone — content identity: cover image, app name, Arabic title, lecturer.
/// Bottom strip — stats: lecture count, class count, offline-ready indicator.
class AboutCard extends StatelessWidget {
  final AppConfigAbout about;

  const AboutCard({super.key, required this.about});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final about = this.about;

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
                    about.appName,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.settingsAboutArabicTitle,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      color: context.brandColor,
                      letterSpacing: 0.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.settingsAboutBy(about.lecturer),
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.secondaryTextColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats strip ────────────────────────────────────────────────
            Container(
              color: context.brandColor.withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _StatColumn(
                      value: '${about.lectureCount}',
                      label: l10n.statLectures,
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: context.groupedBorder,
                    ),
                    _StatColumn(
                      value: '${about.classCount}',
                      label: l10n.statClasses,
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
