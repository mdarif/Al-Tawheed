import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/compact_toggle_chip.dart';

/// The shell home for reading and studying the book — Book and Study merged
/// into one destination with an in-screen toggle, matching Library's
/// Saved/Downloads pattern, so an edition with both never needs a 5th bottom
/// nav destination. See D1 amendment in the IA roadmap.
///
/// This first pass embeds the existing `BookChapterListScreen`/`StudyScreen`
/// unmodified (each keeps its own app bar) below a slim toggle strip, rather
/// than merging their chrome — that keeps their scroll/immersion behavior
/// untouched while the merged-tab direction gets a look.
class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final series = context.watch<SeriesProvider>().currentSeries;
    final hasBook = series.hasBook;
    final hasStudy = series.hasStudyMode;
    final showToggle = hasBook && hasStudy;
    final selected = showToggle ? _selected : 0;

    return Column(
      children: [
        if (showToggle)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: CompactToggleChip(
                      label: l10n.tabBook,
                      selected: selected == 0,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selected = 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CompactToggleChip(
                      label: l10n.tabStudyMode,
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
        Expanded(
          child: IndexedStack(
            index: selected,
            children: [
              if (hasBook) const BookChapterListScreen(),
              if (hasStudy) const StudyScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
