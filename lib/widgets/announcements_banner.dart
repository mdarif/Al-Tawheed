import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/announcement_model.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/safe_url_launcher.dart';

class AnnouncementsBanner extends StatelessWidget {
  static const _iconForType = {
    'info': Icons.info_outline_rounded,
    'warning': Icons.warning_amber_rounded,
    'success': Icons.check_circle_outline_rounded,
  };

  const AnnouncementsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<FeatureFlagsProvider>().features.announcements) {
      return const SizedBox.shrink();
    }

    final announcements = context.watch<AnnouncementsProvider>().visible;
    if (announcements.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final a in announcements) ...[
          AnnouncementCard(announcement: a),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  const AnnouncementCard({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final icon = AnnouncementsBanner._iconForType[announcement.type] ??
        Icons.info_outline_rounded;

    return Container(
      decoration: BoxDecoration(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.groupedBorder, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gold left accent bar — matches the chapter header style
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: context.brandColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: context.brandColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lang.resolve(announcement.title),
                            style: context.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context
                              .read<AnnouncementsProvider>()
                              .dismiss(announcement.id),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: context.mutedIconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lang.resolve(announcement.body),
                      style: context.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: context.secondaryTextColor,
                      ),
                    ),
                    if (announcement.ctaUrl != null &&
                        announcement.ctaLabel != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => launchExternalUrl(announcement.ctaUrl!),
                        child: Text(
                          lang.resolve(announcement.ctaLabel!),
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.brandColor,
                          ),
                        ),
                      ),
                    ],
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
