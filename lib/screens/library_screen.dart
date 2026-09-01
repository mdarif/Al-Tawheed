import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/screens/offline_library_screen.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
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
    final savedCount = context.watch<ProgressProvider>().bookmarkedIds.length;
    final downloadedCount = context.watch<DownloadsProvider>().downloadedCount;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _LibraryHero(
            savedCount: savedCount,
            downloadedCount: downloadsEnabled ? downloadedCount : 0,
          ),
          if (downloadsEnabled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _LibraryToggleChip(
                        label: l10n.saved,
                        selected: selected == 0,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LibraryToggleChip(
                        label: l10n.offlineLibrary,
                        selected: selected == 1,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = 1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverFillRemaining(
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

/// Saved/Downloads toggle chip. Like [SelectionChip] visually, but bounds its
/// label to a fixed height and scales it down to fit — long Arabic/Urdu
/// labels at narrow width + 2x text otherwise overflow the chip.
class _LibraryToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? context.brandColor : context.chipUnselectedBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: SizedBox(
          height: 24,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: selected
                    ? context.onBrandColor
                    : context.chipUnselectedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Library's hero, matching the Lectures tab's pinned-hero language (icon
/// badge + title + stats chip) instead of a bare default AppBar — Library is
/// a peer top-level destination now, not a pushed utility screen.
class _LibraryHero extends StatelessWidget {
  final int savedCount;
  final int downloadedCount;

  const _LibraryHero({required this.savedCount, required this.downloadedCount});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      expandedHeight: 130,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final collapsed = constraints.maxHeight <=
              (settings?.minExtent ?? kToolbarHeight) + 12;

          final flexTitle = collapsed
              ? Text(
                  l10n.tabLibrary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                )
              : null;

          return FlexibleSpaceBar(
            centerTitle: false,
            titlePadding:
                const EdgeInsetsDirectional.only(start: 16, bottom: 14),
            title: flexTitle,
            background: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LibraryBadge(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tabLibrary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _StatsChip(
                                label: l10n.libraryHeroSubtitle(
                                  savedCount,
                                  downloadedCount,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Icon-badge stand-in for the Lectures hero's teacher portrait — Library has
/// no single teacher/book to depict, so a brand-colored icon fills that slot.
class _LibraryBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.brandColor.withValues(alpha: 0.12),
        border: Border.all(color: context.brandColor.withValues(alpha: 0.55)),
      ),
      child: Icon(
        Icons.collections_bookmark_rounded,
        color: context.brandColor,
        size: 26,
      ),
    );
  }
}

class _StatsChip extends StatelessWidget {
  final String label;

  const _StatsChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall
            ?.copyWith(color: context.secondaryTextColor),
      ),
    );
  }
}
