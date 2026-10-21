import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// "Go to class": every class of the edition as a numbered cell, five to a row,
/// with its part count. A finished class (every part listened to) is filled
/// with the brand tint and carries a check; the class the listener is in — the
/// one holding the loaded or last-played lecture — gets a 2 dp brand border.
///
/// Renders nothing for an edition without chapters (the Arabic duroos are a
/// flat list), so callers need no special case.
class ClassGrid extends StatelessWidget {
  final Catalog catalog;

  /// Called with the tapped class.
  final ValueChanged<Chapter> onSelect;

  const ClassGrid({super.key, required this.catalog, required this.onSelect});

  static const int columns = 5;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final chapters = catalog.chapters;
    if (chapters.isEmpty) return const SizedBox.shrink();

    final progress = context.watch<ProgressProvider>();
    final playingId = context.select<PlayerNotifier, String?>(
      (p) => p.current?.id,
    );
    final currentId = playingId ?? progress.lastLectureId;
    final currentChapterId =
        currentId == null ? null : catalog.lectureById(currentId)?.chapterId;

    Widget cell(Chapter chapter) {
      final lectures = catalog.lecturesForChapter(chapter.id);
      return _ClassCell(
        chapter: chapter,
        partCount: lectures.length,
        finished: progress.allComplete(lectures),
        current: chapter.id == currentChapterId,
        onTap: () => onSelect(chapter),
      );
    }

    final rowCount = (chapters.length / columns).ceil();
    return Column(
      key: WidgetKeys.searchClassGrid,
      children: [
        for (var row = 0; row < rowCount; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
            // Cells of a row share the tallest cell's height, so a 2x text
            // scale lengthens the row instead of overflowing a fixed cell.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: row * columns + col < chapters.length
                          ? cell(chapters[row * columns + col])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ClassCell extends StatelessWidget {
  final Chapter chapter;
  final int partCount;
  final bool finished;
  final bool current;
  final VoidCallback onTap;

  const _ClassCell({
    required this.chapter,
    required this.partCount,
    required this.finished,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    // Nastaliq stacks tall: a tight line height clips its marks.
    final nastaliq =
        locale.languageCode == 'ur' && locale.scriptCode != 'roman';
    final number =
        context.localizedDigits(chapter.number.toString().padLeft(2, '0'));
    final parts = context.localizedDigits(context.l10n.partsCount(partCount));
    final state = finished
        ? 'finished'
        : current
            ? 'current'
            : 'other';
    final semantic = context.semantic;
    // The check sits on the brand tint, not on solid gold: brandEmphasis keeps
    // it readable on the light tint, the plain brand colour on the dark one.
    final checkColor =
        context.isDarkTheme ? context.brandColor : semantic.brandEmphasis;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: current
          ? BorderSide(color: context.brandColor, width: 2)
          : BorderSide(
              color: finished ? semantic.brandSubtle : context.groupedBorder,
            ),
    );

    return Semantics(
      key: WidgetKeys.searchClassCell(chapter.id),
      button: true,
      label: context.l10n.searchClassCell(state, number, parts),
      excludeSemantics: true,
      child: Material(
        color: finished ? semantic.brandSubtle : context.groupedSurface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        number,
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: context.numeralFontFamily,
                          height: nastaliq ? 1.9 : null,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          parts,
                          maxLines: 1,
                          style: context.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: context.secondaryTextColor,
                            height: nastaliq ? 1.9 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (finished)
                  PositionedDirectional(
                    top: 5,
                    end: 6,
                    child: Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: checkColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The key to the grid's two highlighted states: "Finished" (tinted, checked)
/// and "Continue here" (gold border).
class ClassGridLegend extends StatelessWidget {
  const ClassGridLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final nastaliq =
        locale.languageCode == 'ur' && locale.scriptCode != 'roman';
    final style = context.textTheme.bodySmall?.copyWith(
      color: context.secondaryTextColor,
      height: nastaliq ? 1.9 : null,
    );
    final semantic = context.semantic;

    Widget swatch(Color fill, BorderSide side) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.fromBorderSide(side),
          ),
        );

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(
              semantic.brandSubtle,
              BorderSide(color: context.dividerColor),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(l10n.searchLegendFinished, style: style)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(
              Colors.transparent,
              BorderSide(color: context.brandColor, width: 2),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(l10n.searchLegendContinue, style: style)),
          ],
        ),
      ],
    );
  }
}
