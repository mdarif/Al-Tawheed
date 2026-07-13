import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/widgets/announcements_banner.dart' show AnnouncementCard;

/// A bell + badge in the app bar that surfaces announcements without taking up
/// layout space. Hidden entirely when the feature is off or there are no
/// undismissed announcements; otherwise a dot-badged bell opens a bottom sheet
/// of the announcement cards. (Replaces the old inline banner that lived on the
/// retired Home tab.)
class AnnouncementsBell extends StatelessWidget {
  const AnnouncementsBell({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<FeatureFlagsProvider>().features.announcements) {
      return const SizedBox.shrink();
    }
    if (context.watch<AnnouncementsProvider>().visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: () => _openSheet(context),
      icon: Badge(
        backgroundColor: context.brandColor,
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        // Rebuild the list as cards are dismissed; close once the last one goes.
        child: Consumer<AnnouncementsProvider>(
          builder: (context, provider, _) {
            final items = provider.visible;
            if (items.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final nav = Navigator.of(sheetContext);
                if (nav.canPop()) nav.pop();
              });
              return const SizedBox.shrink();
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in items) ...[
                    AnnouncementCard(announcement: a),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
