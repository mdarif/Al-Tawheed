import 'package:flutter/material.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Rich About card for Settings — cover, titles, stats, and app version.
class AboutCard extends StatefulWidget {
  final AppConfigAbout about;

  const AboutCard({super.key, required this.about});

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final about = widget.about;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.groupedBorder, width: 1),
      ),
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
          const SizedBox(height: 16),
          Text(
            l10n.settingsAboutStats(
              about.lectureCount,
              about.classCount,
              about.totalDuration,
            ),
            textAlign: TextAlign.center,
            style: context.textTheme.labelLarge?.copyWith(
              color: context.brandColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.settingsAboutDescriptionLine1,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.secondaryTextColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsAboutDescriptionLine2,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.secondaryTextColor,
              height: 1.45,
            ),
          ),
          if (_packageInfo != null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.settingsAboutVersion(_packageInfo!.version),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.mutedIconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
