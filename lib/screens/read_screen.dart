import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/app_overflow_menu.dart';
import 'package:myapp/widgets/compact_toggle_chip.dart';

/// The shell home for reading and studying the book — Book and Study merged
/// into one destination behind a single shared header, with an in-screen
/// toggle when an edition has both. See D1 amendment in the IA roadmap.
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
    final showingBook = hasBook && (!hasStudy || selected == 0);

    return Scaffold(
      appBar: AppBar(
        title: showingBook
            ? _BookTitle(fontFamily: series.bookFontFamily)
            : Text(l10n.studyMode),
        actions: const [AppOverflowMenu()],
        bottom: showToggle
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              )
            : null,
      ),
      body: IndexedStack(
        index: selected,
        children: [
          if (hasBook) const BookChapterListBody(),
          if (hasStudy) const StudyBody(),
        ],
      ),
    );
  }
}

class _BookTitle extends StatelessWidget {
  final String fontFamily;

  const _BookTitle({required this.fontFamily});

  @override
  Widget build(BuildContext context) {
    final book = context.watch<BookProvider>().book;
    final l10n = context.l10n;
    if (book == null) return Text(l10n.tabBook);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        book.title,
        textAlign: TextAlign.right,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
    );
  }
}
