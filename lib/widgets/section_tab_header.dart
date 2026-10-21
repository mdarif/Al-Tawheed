import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// One tab of a [SectionTabHeader].
class SectionTab {
  /// Translated label.
  final String label;

  /// Optional count shown after the label in the secondary text colour. Shown
  /// in the chrome locale's numerals.
  final int? count;

  /// Stable key (for tests), applied to the tab itself.
  final Key? tabKey;

  const SectionTab({required this.label, this.count, this.tabKey});
}

/// The shared header of a top-level section: a plain title (optionally with a
/// quiet subtitle beside it) over an underline [TabBar].
///
/// Library uses it with "Bookmarks / Downloads" and Read with "Book / Study".
/// With no [tabs] it is just the title row, so a section that has a single
/// destination in some editions keeps the same header without a lone tab.
///
/// The header is content-sized rather than an `AppBar`: at 2.0 text scale or
/// with a tall Nastaliq title an `AppBar`'s fixed toolbar would clip, whereas
/// this grows. Tab labels instead scale down to stay inside their fixed
/// 48 dp-tall tab. Place it at the top of the screen body.
///
/// Tab selection is driven by [controller], or by an ancestor
/// [DefaultTabController] when it is null, exactly like [TabBar].
class SectionTabHeader extends StatelessWidget {
  final String title;

  /// Quiet text beside the title, e.g. the book's name on Read.
  final String? subtitle;

  /// Overrides the default secondary-colour body style of [subtitle].
  final TextStyle? subtitleStyle;

  /// Set when the subtitle is in a different script from the chrome.
  final TextDirection? subtitleDirection;

  final List<SectionTab> tabs;
  final TabController? controller;

  /// Adds a leading back button, for a header on a pushed (non-shell) route.
  final bool showBack;

  const SectionTabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    this.subtitleDirection,
    this.tabs = const [],
    this.controller,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    // Nastaliq stacks tall: a tight line height clips its ascenders/descenders.
    final nastaliq =
        locale.languageCode == 'ur' && locale.scriptCode != 'roman';
    final titleStyle = context.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: nastaliq ? 1.9 : 1.2,
    );
    final subtitleText = subtitle;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                showBack ? 4 : 16,
                8,
                16,
                8,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    if (showBack) const BackButton(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                          ),
                          if (subtitleText != null) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                subtitleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textDirection: subtitleDirection,
                                style: subtitleStyle ??
                                    context.textTheme.bodyMedium?.copyWith(
                                      color: context.secondaryTextColor,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tabs.isNotEmpty)
              TabBar(
                controller: controller,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: context.brandColor, width: 3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                  insets: const EdgeInsets.symmetric(horizontal: 24),
                ),
                dividerColor: context.dividerColor,
                dividerHeight: 1,
                labelColor: context.primaryTextColor,
                unselectedLabelColor: context.secondaryTextColor,
                labelStyle: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: nastaliq ? 1.9 : null,
                ),
                unselectedLabelStyle: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: nastaliq ? 1.9 : null,
                ),
                tabs: [for (final tab in tabs) _tab(context, tab)],
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, SectionTab tab) {
    final count = tab.count;
    return Tab(
      key: tab.tabKey,
      height: 48,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tab.label),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                context.localizedDigits('$count'),
                style: TextStyle(
                  color: context.secondaryTextColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.numeralFontFamily,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
