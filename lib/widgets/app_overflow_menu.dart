import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/utils/l10n_extensions.dart';

enum _MenuItem { bookmarks, shareApp, about }

/// App-bar overflow (⋯) — the hub for secondary destinations and actions, shown
/// on every shell tab. Add future routes here rather than as new bottom-nav
/// tabs or standalone app-bar icons. Settings is the exception: it has its own
/// bottom-nav tab (last), so it is deliberately NOT duplicated here. Labels
/// follow the app UI language, like the nav bar.
class AppOverflowMenu extends StatelessWidget {
  const AppOverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // "Share app" lives here (moved out of the Settings "App" section, which is
    // gated off by default) so it is actually reachable. Gated by the same
    // shareButton flag as the per-lecture share.
    final shareEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.shareButton,
    );

    return PopupMenuButton<_MenuItem>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (item) {
        switch (item) {
          case _MenuItem.bookmarks:
            context.push('/bookmarks');
          case _MenuItem.shareApp:
            SharePlus.instance.share(
              ShareParams(
                text: context.read<AppConfigProvider>().config.share.message,
              ),
            );
          case _MenuItem.about:
            context.push('/about');
        }
      },
      itemBuilder: (context) => [
        _item(_MenuItem.bookmarks, Icons.bookmark_outline_rounded, l10n.saved),
        if (shareEnabled)
          _item(_MenuItem.shareApp, Icons.share_rounded, l10n.settingsShareApp),
        _item(_MenuItem.about, Icons.info_outline_rounded, l10n.settingsAbout),
      ],
    );
  }

  PopupMenuItem<_MenuItem> _item(
    _MenuItem item,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<_MenuItem>(
      value: item,
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          // Flexible so a long localized label ellipsizes rather than
          // overflowing the row.
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
