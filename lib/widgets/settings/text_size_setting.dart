import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/book_typography.dart';
import 'package:myapp/utils/duration_formatter.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Stepper increment, in points, for the −/+ buttons. The bounds themselves
/// live on [ReadingProvider], which clamps every write.
const double kTextSizeStep = 2;

// Same ornate Qur'an brackets the reader swaps in for the source's `{ }` (see
// book_reader_screen.dart): the logical opener uses U+FD3F, the closer U+FD3E.
const _ornateOpen = '\u{FD3F}';
const _ornateClose = '\u{FD3E}';

/// The opening line of [chapter] exactly as the reader would paint it: the
/// first non-blank source line, with the source's `{ }` verse markers shown as
/// ornate brackets and digits in the book's script ([language]). Nothing is
/// rewritten, trimmed mid-sentence or translated — the words are the book's.
String bookPreviewText(BookChapter chapter, String language) {
  final line = chapter.text
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  return localizedDigitsInString(
    line.replaceAll('{', _ornateOpen).replaceAll('}', _ornateClose),
    language,
  );
}

/// The chapter the preview quotes: chapter 1 (falls back to the first chapter
/// when a book has no chapter numbered 1), or null for an empty book.
BookChapter? _previewChapter(BookContent? book) {
  if (book == null || book.chapters.isEmpty) return null;
  return book.chapters.firstWhere(
    (c) => c.number == 1,
    orElse: () => book.chapters.first,
  );
}

/// Book text-size control: a −/+ stepper over [ReadingProvider.bookFontSize]
/// with a live preview in the book's own font and direction.
///
/// Used by Settings › Reading and by the reader's "Aa" sheet. Both read and
/// write the same [ReadingProvider] value as the reader's pinch gesture, so a
/// change made in one place is immediately visible in the others.
class TextSizeSetting extends StatelessWidget {
  const TextSizeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reading = context.watch<ReadingProvider>();
    final size = reading.bookFontSize;
    final series = context.watch<SeriesProvider>().currentSeries;
    final bookProvider = context.watch<BookProvider>();
    // The Book may not have been opened yet (Settings is reachable first), so
    // load the active edition's bundled book for the preview. `load` is a
    // no-op for an edition without a book, and `reload()` (an edition switch)
    // returns the provider to idle, which brings us back here.
    if (bookProvider.status == BookStatus.idle && series.hasBook) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<BookProvider>().load(
              context.read<SeriesProvider>().currentSeries,
            );
      });
    }
    final chapter = _previewChapter(bookProvider.book);
    final value = context.localizedDigits('${size.round()}');

    // Read the live value, not the one captured at build: a second tap can
    // land before the first write has notified and rebuilt this widget.
    void step(double delta) {
      final current = context.read<ReadingProvider>();
      current.setBookFontSize(current.bookFontSize + delta);
    }

    return Padding(
      key: WidgetKeys.settingsTextSize,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, not a Row: at 2× text (or a long translation) the stepper
          // drops under the title instead of overflowing.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.semantic.brandSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.text_fields_rounded,
                      color: context.brandColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      l10n.settingsBookFontSize,
                      style: context.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    key: WidgetKeys.settingsTextSizeDecrease,
                    tooltip: l10n.settingsTextSizeSmaller,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: size > ReadingProvider.minBookFontSize
                        ? () => step(-kTextSizeStep)
                        : null,
                  ),
                  // The value is a live region so TalkBack / VoiceOver
                  // announce each change without the user re-focusing it.
                  Semantics(
                    key: WidgetKeys.settingsTextSizeValue,
                    liveRegion: true,
                    label: '${l10n.settingsBookFontSize} $value',
                    excludeSemantics: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 40),
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    key: WidgetKeys.settingsTextSizeIncrease,
                    tooltip: l10n.settingsTextSizeLarger,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.add_rounded),
                    onPressed: size < ReadingProvider.maxBookFontSize
                        ? () => step(kTextSizeStep)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          if (chapter != null) ...[
            const SizedBox(height: 14),
            _BookPreview(
              text: bookPreviewText(chapter, series.language),
              fontFamily: series.bookFontFamily,
              fontSize: size,
              // Nastaliq needs more leading than Naskh (same values the
              // reader uses, within the 1.8–2.1 a11y band).
              height: series.language == 'ur'
                  ? bookUrduLineHeight
                  : bookArabicLineHeight,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.settingsTextSizeHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Verse (`﴿…﴾`) and citation (`[…]`) segments are Arabic runs in the reader,
/// so they are split out before each piece's script is detected.
final RegExp _markedSegment =
    RegExp('$_ornateOpen[^$_ornateClose]*$_ornateClose|\\[[^\\]]*\\]');

/// [text] split into the runs the reader paints separately: Urdu in the book's
/// own font at [bookUrduSizeFactor], Arabic in Naskh at full size.
List<TextSpan> _scriptRuns(String text, String fontFamily, double fontSize) {
  final pieces = <String>[];
  var last = 0;
  for (final m in _markedSegment.allMatches(text)) {
    if (m.start > last) pieces.add(text.substring(last, m.start));
    pieces.add(m.group(0)!);
    last = m.end;
  }
  if (last < text.length) pieces.add(text.substring(last));
  return [
    for (final piece in pieces)
      if (bookUrduLetters.hasMatch(piece))
        TextSpan(
          text: piece,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize * bookUrduSizeFactor,
          ),
        )
      else
        TextSpan(
          text: piece,
          style: TextStyle(
            fontFamily: bookArabicFontFamily,
            fontSize: fontSize,
          ),
        ),
  ];
}

class _BookPreview extends StatelessWidget {
  final String text;
  final String fontFamily;
  final double fontSize;
  final double height;

  const _BookPreview({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Scripture is shown for its look, not announced on every size change —
    // the stepper's live region carries the feedback.
    return ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          border: Border.all(color: context.groupedBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        // The book is always RTL, whatever the chrome locale.
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text.rich(
            TextSpan(children: _scriptRuns(text, fontFamily, fontSize)),
            key: WidgetKeys.settingsTextSizePreview,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyLarge?.copyWith(
              fontFamily: fontFamily,
              fontSize: fontSize,
              height: height,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [TextSizeSetting] in a modal bottom sheet — the reader's "Aa"
/// shortcut. The sheet reads the app-wide providers, so it edits the very
/// value Settings and pinch do.
Future<void> showTextSizeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: const TextSizeSetting(),
      ),
    ),
  );
}
