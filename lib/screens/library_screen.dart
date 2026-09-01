import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/screens/offline_library_screen.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// The shell home for content a user has explicitly kept.
///
/// The old root routes remain for Release A compatibility (notably pushes
/// initiated by Player and Settings). This branch is intentionally stateful so
/// its selected collection survives switches to other shell destinations.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloadsEnabled =
        context.watch<FeatureFlagsProvider>().features.downloads;
    final selected = downloadsEnabled ? _selected : 0;

    final destinations = <ButtonSegment<int>>[
      ButtonSegment(
        value: 0,
        label: Text(l10n.saved),
        icon: const Icon(Icons.bookmark_outline_rounded),
      ),
      if (downloadsEnabled)
        ButtonSegment(
          value: 1,
          label: Text(l10n.offlineLibrary),
          icon: const Icon(Icons.download_outlined),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabLibrary)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<int>(
              segments: destinations,
              selected: {selected},
              onSelectionChanged: (selected) =>
                  setState(() => _selected = selected.first),
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: selected,
              children: [
                const BookmarksBody(),
                if (downloadsEnabled) const OfflineLibraryBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
