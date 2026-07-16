import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/utils/l10n_extensions.dart';

enum _MenuRoute { bookmarks, about }

/// App-bar overflow (⋯) — the hub for secondary destinations, shown on every
/// shell tab. Add future routes here rather than as new bottom-nav tabs or
/// standalone app-bar icons. Settings is the exception: it has its own
/// bottom-nav tab (last), so it is deliberately NOT duplicated here. Labels
/// follow the app UI language via [BuildContext.l10nForSeries], like the nav bar.
class AppOverflowMenu extends StatelessWidget {
  const AppOverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final series = context.watch<SeriesProvider>().currentSeries;
    final l10n = context.l10nForSeries(series);

    return PopupMenuButton<_MenuRoute>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (route) {
        switch (route) {
          case _MenuRoute.bookmarks:
            context.push('/bookmarks');
          case _MenuRoute.about:
            context.push('/about');
        }
      },
      itemBuilder: (context) => [
        _item(_MenuRoute.bookmarks, Icons.bookmark_outline_rounded, l10n.saved),
        _item(_MenuRoute.about, Icons.info_outline_rounded, l10n.settingsAbout),
      ],
    );
  }

  PopupMenuItem<_MenuRoute> _item(
    _MenuRoute route,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<_MenuRoute>(
      value: route,
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
