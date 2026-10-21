import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/lecture_search.dart';
import 'package:myapp/widgets/class_grid.dart';
import 'package:myapp/widgets/lecture_tile.dart';

/// Full-screen lecture search, pushed INSIDE the Lectures branch
/// (`/lectures/search`) so the bottom nav and mini-player stay visible.
///
/// One field, five states:
///  * idle — example queries and, for an edition with classes, the "Go to
///    class" grid;
///  * results — "Classes" then "Lectures", whole-token highlights;
///  * no results — only ever for a catalogue that IS loaded;
///  * unavailable — no catalogue and none loading (offline, nothing cached);
///  * error — the catalogue failed to load.
/// plus a spinner while it loads. Matching is [searchLectures]; this screen is
/// only presentation.
///
/// A class hit or grid cell pops this route with the chosen chapter id, which
/// Lectures turns into a scroll to that chapter's header. A lecture hit plays
/// and pushes the Player on top, so Back lands here with the query intact.
class LectureSearchScreen extends StatefulWidget {
  const LectureSearchScreen({super.key});

  @override
  State<LectureSearchScreen> createState() => _LectureSearchScreenState();
}

class _LectureSearchScreenState extends State<LectureSearchScreen> {
  static const _debounce = Duration(milliseconds: 150);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _timer;

  /// The query results are shown for: [_controller]'s text after the debounce
  /// (immediately when cleared).
  String _query = '';

  // Last computed result, reused while neither the query nor the catalogue
  // changes (every progress tick rebuilds this screen).
  Catalog? _resultCatalog;
  String? _resultQuery;
  LectureSearchResult? _result;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _timer = Timer(_debounce, () {
      if (mounted) setState(() => _query = text);
    });
  }

  /// Puts [text] in the field and searches for it right away.
  void _setQuery(String text) {
    _timer?.cancel();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _query = text);
    _focus.requestFocus();
  }

  LectureSearchResult _resultFor(Catalog catalog) {
    if (!identical(catalog, _resultCatalog) || _query != _resultQuery) {
      _resultCatalog = catalog;
      _resultQuery = _query;
      _result = searchLectures(
        _query,
        chapters: catalog.chapters,
        lectures: catalog.lectures,
      );
    }
    return _result!;
  }

  void _goToClass(Chapter chapter) => context.pop<String>(chapter.id);

  void _playLecture(Lecture lecture, Catalog catalog) {
    // Back from Player returns to the results, not to a raised keyboard.
    FocusScope.of(context).unfocus();
    context.read<PlayerNotifier>().loadAndPlay(lecture, catalog.lectures);
    context.push('/player');
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final series = context.watch<SeriesProvider>().currentSeries;
    // Titles are resolved per chrome language: refresh when it changes.
    context.watch<LanguageProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SearchBar(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              onClear: () => _setQuery(''),
            ),
            Expanded(child: _buildBody(catalogProvider, series)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CatalogProvider provider, SeriesConfig series) {
    final catalog = provider.catalog;
    return switch (provider.status) {
      CatalogStatus.loaded when catalog != null =>
        _buildLoaded(catalog, series),
      CatalogStatus.loading => Center(
          child: CircularProgressIndicator(
            key: WidgetKeys.searchLoading,
            color: context.brandColor,
          ),
        ),
      // A failed reload may leave an older catalogue behind: never search it.
      CatalogStatus.error when !provider.needsOnlineToLoad => _buildError(
          provider,
        ),
      // Nothing loaded and nothing on the way (never loaded, or offline with
      // no cache). Never "no matches": we have not looked at anything.
      _ => _buildUnavailable(provider),
    };
  }

  Widget _buildLoaded(Catalog catalog, SeriesConfig series) {
    final result = _resultFor(catalog);
    if (result.isEmptyQuery) return _buildIdle(catalog, series);
    if (result.length == 0) return _buildNoResults(catalog);
    return _buildResults(result, catalog, series);
  }

  // ── Idle ───────────────────────────────────────────────────────────────

  Widget _buildIdle(Catalog catalog, SeriesConfig series) {
    final l10n = context.l10n;
    final hasClasses = catalog.chapters.isNotEmpty;
    final labelStyle = context.textTheme.labelMedium?.copyWith(
      color: context.secondaryTextColor,
      fontWeight: FontWeight.w700,
      height: _isNastaliq(context) ? 1.9 : null,
    );

    return ListView(
      key: WidgetKeys.searchIdle,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(l10n.searchTry, style: labelStyle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in _exampleQueries(series))
              _ExampleChip(query: query, onTap: () => _setQuery(query)),
          ],
        ),
        if (hasClasses) ...[
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(l10n.searchGoToClass, style: labelStyle)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  context.localizedDigits(
                    '${l10n.searchClassesCount(catalog.chapters.length)} · '
                    '${l10n.partsCount(catalog.lectures.length)}',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.secondaryTextColor,
                    height: _isNastaliq(context) ? 1.9 : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClassGrid(catalog: catalog, onSelect: _goToClass),
          const SizedBox(height: 14),
          const ClassGridLegend(),
        ] else ...[
          const SizedBox(height: 20),
          Text(
            l10n.searchIdleHint,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.secondaryTextColor,
              height: _isNastaliq(context) ? 1.9 : null,
            ),
          ),
        ],
      ],
    );
  }

  /// Literal queries that work in this edition's catalogue (the matcher is
  /// documented against them), so a tap always lands on results.
  List<String> _exampleQueries(SeriesConfig series) => series.isRtl
      ? const ['3', 'الثالث']
      : const ['12', 'Part 03', 'Hissa 2', 'درس ۰۵'];

  // ── Results ────────────────────────────────────────────────────────────

  Widget _buildResults(
    LectureSearchResult result,
    Catalog catalog,
    SeriesConfig series,
  ) {
    final l10n = context.l10n;
    final lang = context.read<LanguageProvider>();
    final items = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
        child: Semantics(
          key: WidgetKeys.searchResultCount,
          liveRegion: true,
          child: Text(
            context.localizedDigits(l10n.searchResultsCount(result.length)),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.secondaryTextColor,
              height: _isNastaliq(context) ? 1.9 : null,
            ),
          ),
        ),
      ),
    ];

    if (result.chapters.isNotEmpty) {
      items.add(
        _SectionHeader(
          key: WidgetKeys.searchSectionClasses,
          label: l10n.statClasses,
        ),
      );
      for (final hit in result.chapters) {
        items.add(
          _ClassRow(
            hit: hit,
            lectures: catalog.lecturesForChapter(hit.item.id),
            title: lang.resolve(hit.item.title),
            onTap: () => _goToClass(hit.item),
          ),
        );
      }
    }

    if (result.lectures.isNotEmpty) {
      items.add(
        _SectionHeader(
          key: WidgetKeys.searchSectionLectures,
          label: l10n.statLectures,
        ),
      );
      for (var i = 0; i < result.lectures.length; i++) {
        final hit = result.lectures[i];
        items.add(
          _LectureRow(
            hit: hit,
            title: lang.resolveForSeries(hit.item.title, series),
            rtlContent: series.isRtl,
            onTap: () => _playLecture(hit.item, catalog),
          ),
        );
        if (i < result.lectures.length - 1) {
          items.add(
            Divider(
              height: 1,
              indent: 70,
              endIndent: 16,
              color: context.dividerColor,
            ),
          );
        }
      }
    }

    return ListView.builder(
      key: WidgetKeys.searchResults,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding:
          EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
      itemCount: items.length,
      itemBuilder: (_, index) => items[index],
    );
  }

  // ── Statuses ───────────────────────────────────────────────────────────

  Widget _buildNoResults(Catalog catalog) {
    final l10n = context.l10n;
    final hasClasses = catalog.chapters.isNotEmpty;
    final totals = hasClasses
        ? l10n.searchNoMatchesBody(
            context.localizedDigits(
              l10n.searchClassesCount(catalog.chapters.length),
            ),
            context.localizedDigits(l10n.partsCount(catalog.lectures.length)),
          )
        : l10n.searchNoMatchesBodyFlat(
            context.localizedDigits(
              l10n.searchLecturesCount(catalog.lectures.length),
            ),
          );

    return _StatusBody(
      key: WidgetKeys.searchNoResults,
      icon: Icons.search_off_rounded,
      title: l10n.searchNoMatchesTitle(_query.trim()),
      message: context.localizedDigits(totals),
      actions: [
        OutlinedButton(
          key: WidgetKeys.searchClearAction,
          style: _buttonStyle,
          onPressed: () => _setQuery(''),
          child: _ButtonLabel(l10n.searchClear),
        ),
        if (hasClasses)
          TextButton(
            key: WidgetKeys.searchBrowseClasses,
            style: _buttonStyle,
            onPressed: () {
              _setQuery('');
              _focus.unfocus();
            },
            child: _ButtonLabel(l10n.searchBrowseClasses),
          ),
      ],
    );
  }

  Widget _buildUnavailable(CatalogProvider provider) {
    final l10n = context.l10n;
    final downloads = context.select<FeatureFlagsProvider, bool>(
      (f) => f.features.downloads,
    );
    return _StatusBody(
      key: WidgetKeys.searchUnavailable,
      icon: Icons.wifi_off_rounded,
      title: l10n.searchUnavailableTitle,
      message: l10n.searchUnavailableMessage,
      actions: [
        _retryButton(provider),
        // The Downloads tab only exists with the downloads feature on.
        if (downloads)
          OutlinedButton(
            key: WidgetKeys.searchOpenDownloads,
            style: _buttonStyle,
            onPressed: () => context.go('/library?tab=downloads'),
            child: _ButtonLabel(l10n.searchOpenDownloads),
          ),
      ],
    );
  }

  Widget _buildError(CatalogProvider provider) {
    return _StatusBody(
      key: WidgetKeys.searchError,
      icon: Icons.error_outline_rounded,
      title: context.l10n.couldNotLoadLectures,
      message: provider.error ?? '',
      actions: [_retryButton(provider)],
    );
  }

  Widget _retryButton(CatalogProvider provider) {
    // The brand gold takes a DARK glyph: the light theme's own onPrimary is
    // white, which fails contrast on #D4AF37.
    final scheme = context.colorScheme;
    return FilledButton(
      key: WidgetKeys.searchRetry,
      style: _buttonStyle.copyWith(
        foregroundColor: WidgetStatePropertyAll(
          context.isDarkTheme ? scheme.onPrimary : scheme.onSurface,
        ),
        backgroundColor: WidgetStatePropertyAll(context.brandColor),
      ),
      onPressed: provider.load,
      child: _ButtonLabel(context.l10n.retry),
    );
  }
}

/// Full-width, at least 48 dp tall; grows with the text.
final ButtonStyle _buttonStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  ),
);

/// A button caption: centred, wrapping, with Nastaliq leading when needed.
class _ButtonLabel extends StatelessWidget {
  final String text;

  const _ButtonLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: _isNastaliq(context) ? const TextStyle(height: 1.9) : null,
    );
  }
}

/// Urdu-script chrome (Nastaliq). Its marks stack tall, so every line needs
/// generous leading; Roman Urdu is Latin and does not.
bool _isNastaliq(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return locale.languageCode == 'ur' && locale.scriptCode != 'roman';
}

final RegExp _arabicScript = RegExp(r'[؀-ۿ]');

// ── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            key: WidgetKeys.searchBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([focusNode, controller]),
              builder: (context, _) => Container(
                padding: const EdgeInsetsDirectional.only(start: 14),
                decoration: ShapeDecoration(
                  color: context.groupedSurface,
                  shape: StadiumBorder(
                    side: focusNode.hasFocus
                        ? BorderSide(color: context.brandColor, width: 2)
                        : BorderSide(color: context.groupedBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: context.mutedIconColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        label: l10n.searchLectures,
                        child: TextField(
                          key: WidgetKeys.searchField,
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onChanged: onChanged,
                          style: context.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: l10n.searchHint,
                            hintStyle: context.textTheme.bodyLarge?.copyWith(
                              color: context.secondaryTextColor,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isCollapsed: true,
                            constraints: const BoxConstraints(minHeight: 48),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (controller.text.isNotEmpty)
                      IconButton(
                        key: WidgetKeys.searchClear,
                        tooltip: l10n.searchClear,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: onClear,
                      )
                    else
                      const SizedBox(width: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const _ExampleChip({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final arabicScript = _arabicScript.hasMatch(query);
    final text = Text(
      query,
      style: context.textTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.primaryTextColor,
        // Urdu/Arabic script stacks tall: generous leading, inside the 1.8-2.1
        // band, keeps its marks from clipping.
        height: arabicScript || _isNastaliq(context) ? 1.9 : null,
      ),
    );
    return Semantics(
      button: true,
      child: Material(
        key: WidgetKeys.searchChip(query),
        color: context.groupedSurface,
        shape: StadiumBorder(side: BorderSide(color: context.groupedBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: arabicScript
                    ? Directionality(
                        textDirection: TextDirection.rtl,
                        child: text,
                      )
                    : text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Result rows ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
        child: Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.secondaryTextColor,
            fontWeight: FontWeight.w700,
            height: _isNastaliq(context) ? 1.9 : null,
          ),
        ),
      ),
    );
  }
}

/// Paints [text] with its [spans] (whole tokens, in this exact string)
/// highlighted: brand-tint background, bold, brand underline.
class _HighlightedText extends StatelessWidget {
  final String text;
  final List<MatchSpan> spans;
  final TextStyle? style;

  const _HighlightedText({
    required this.text,
    required this.spans,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: style, children: highlightSpans(context, text, spans)),
    );
  }
}

/// [text] cut at [spans] into plain and highlighted runs. Out-of-range or
/// overlapping spans are skipped rather than trusted.
List<InlineSpan> highlightSpans(
  BuildContext context,
  String text,
  List<MatchSpan> spans,
) {
  final highlight = TextStyle(
    backgroundColor: context.semantic.brandSubtle,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    decorationColor: context.brandColor,
    decorationThickness: 2,
  );
  final out = <InlineSpan>[];
  var cursor = 0;
  for (final span in spans) {
    if (span.start < cursor ||
        span.end > text.length ||
        span.end <= span.start) {
      continue;
    }
    if (span.start > cursor) {
      out.add(TextSpan(text: text.substring(cursor, span.start)));
    }
    out.add(TextSpan(text: span.of(text), style: highlight));
    cursor = span.end;
  }
  if (cursor < text.length) out.add(TextSpan(text: text.substring(cursor)));
  return out;
}

/// The spans of the title field the row actually shows. A hit that matched
/// only through another language (or only on a lecture number) has none for
/// it, and shows a plain title.
List<MatchSpan> _spansForShown(
  Map<String, List<MatchSpan>> titleSpans,
  Map<String, dynamic> field,
  String shown,
) {
  for (final entry in titleSpans.entries) {
    if (field[entry.key] == shown) return entry.value;
  }
  return const [];
}

class _RowShell extends StatelessWidget {
  final Key rowKey;
  final VoidCallback onTap;
  final Widget child;

  const _RowShell({
    required this.rowKey,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rowKey,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final SearchHit<Chapter> hit;
  final List<Lecture> lectures;
  final String title;
  final VoidCallback onTap;

  const _ClassRow({
    required this.hit,
    required this.lectures,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chapter = hit.item;
    final progress = context.watch<ProgressProvider>();
    final finished = progress.allComplete(lectures);
    final started = lectures.any((l) => progress.hasProgress(l.id));
    final totalSeconds =
        lectures.fold<int>(0, (sum, l) => sum + l.durationSeconds);
    final nastaliq = _isNastaliq(context);

    final summary = [
      context.localizedDigits(l10n.partsCount(lectures.length)),
      if (totalSeconds > 0) context.localizedHoursMinutes(totalSeconds),
      if (finished)
        l10n.searchLegendFinished
      else if (started)
        l10n.searchInProgress,
    ].join(' · ');

    return _RowShell(
      rowKey: WidgetKeys.searchClassRow(chapter.id),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.semantic.brandSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.format_list_numbered_rounded,
              size: 22,
              color: context.isDarkTheme
                  ? context.brandColor
                  : context.semantic.brandEmphasis,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HighlightedText(
                  text: title,
                  spans: _spansForShown(hit.titleSpans, chapter.title, title),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: nastaliq ? 1.9 : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: context.secondaryTextColor,
                    height: nastaliq ? 1.9 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    l10n.searchGoToClass,
                    textAlign: TextAlign.end,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: nastaliq ? 1.9 : null,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LectureRow extends StatelessWidget {
  final SearchHit<Lecture> hit;
  final String title;
  final bool rtlContent;
  final VoidCallback onTap;

  const _LectureRow({
    required this.hit,
    required this.title,
    required this.rtlContent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lecture = hit.item;
    final nastaliq = _isNastaliq(context);
    final downloadsEnabled = context.select<FeatureFlagsProvider, bool>(
      (f) => f.features.downloads,
    );
    final isOffline = context.select<ConnectivityProvider, bool>(
      (c) => c.isOffline,
    );
    final isDownloaded = context.select<DownloadsProvider, bool>(
      (d) => d.isDownloaded(lecture.id),
    );
    // Same offline guard as a Lectures row: an undownloaded lecture cannot
    // stream without a connection.
    final blocked = downloadsEnabled && isOffline && !isDownloaded;

    final titleStyle = context.textTheme.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: nastaliq ? 1.9 : (rtlContent ? 1.5 : null),
    );
    final titleText = _HighlightedText(
      text: title,
      spans: _spansForShown(hit.titleSpans, lecture.title, title),
      style: titleStyle,
    );

    return _RowShell(
      rowKey: WidgetKeys.searchLectureRow(lecture.id),
      onTap: blocked ? () => _showOfflineSnackBar(context) : onTap,
      child: Row(
        children: [
          LectureProgressBadge(lecture: lecture),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rtlContent)
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: SizedBox(width: double.infinity, child: titleText),
                  )
                else
                  titleText,
                const SizedBox(height: 2),
                _Subtitle(hit: hit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.offlineNotDownloaded),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// "Lecture 12 · 32:28 · Finished": the "Lecture n" part only for a hit that
/// matched solely on the lecture number (the title carries nothing to
/// highlight), with the number highlighted.
class _Subtitle extends StatelessWidget {
  final SearchHit<Lecture> hit;

  const _Subtitle({required this.hit});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lecture = hit.item;
    final nastaliq = _isNastaliq(context);
    final progress = context.watch<ProgressProvider>();
    final fraction = progress.getFraction(lecture.id, lecture.durationSeconds);

    final status = fraction >= 0.99
        ? l10n.searchLegendFinished
        : fraction > 0.01
            ? l10n.searchTimeLeft(
                context.localizedTime(
                  lecture.durationSeconds -
                      progress.getPositionSeconds(lecture.id),
                ),
              )
            : null;

    final spans = <InlineSpan>[];
    if (hit.titleSpans.isEmpty) {
      final number = context.localizedDigits('${lecture.number}');
      final label = l10n.searchLectureNumber(number);
      final at = label.indexOf(number);
      if (at < 0) {
        spans.add(TextSpan(text: label));
      } else {
        spans.addAll(
          highlightSpans(context, label, [MatchSpan(at, at + number.length)]),
        );
      }
      spans.add(const TextSpan(text: ' · '));
    }
    spans.add(TextSpan(text: context.localizedTime(lecture.durationSeconds)));
    if (status != null) spans.add(TextSpan(text: ' · $status'));

    return Text.rich(
      TextSpan(children: spans),
      style: context.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: context.secondaryTextColor,
        height: nastaliq ? 1.9 : null,
      ),
    );
  }
}

// ── Statuses ─────────────────────────────────────────────────────────────────

/// Centered icon, title, message and stacked full-width actions. A live region
/// so a screen reader announces the new state when typing flips into it.
class _StatusBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  const _StatusBody({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final nastaliq = _isNastaliq(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          36,
          24,
          36,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.elevatedSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: context.mutedIconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: nastaliq ? 1.9 : null,
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.secondaryTextColor,
                    height: nastaliq ? 1.9 : 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              for (final action in actions) ...[
                SizedBox(width: double.infinity, child: action),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
