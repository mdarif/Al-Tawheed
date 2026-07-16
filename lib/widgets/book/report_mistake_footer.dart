import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/safe_url_launcher.dart';

/// Builds the `mailto:` for a correction report.
///
/// Hand-assembled rather than via `Uri(queryParameters: …)`, which encodes
/// spaces as `+`. That is correct for form bodies and wrong here: mail clients
/// show the `+` literally, so a prefilled body arrives full of them. Percent
/// encoding via [Uri.encodeComponent] is what `mailto:` wants (RFC 6068). The
/// address itself is left un-encoded — `%40` for `@` is legal but not every
/// client resolves it.
///
/// Returns null when there is no address to send to, so the caller can hide the
/// affordance rather than offer a button that cannot work.
String? buildMistakeReportUri({
  required String email,
  required String subject,
  required String body,
}) {
  if (!email.contains('@') || email.trim().isEmpty) return null;
  return 'mailto:${email.trim()}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
}

/// The diagnostic block appended under the reader's own words.
///
/// Deliberately **not** translated: only the maintainer reads it, and it has to
/// survive being forwarded. It is what turns "there's a typo somewhere" into a
/// page number.
String mistakeReportDetails({
  required String seriesId,
  required int chapterNumber,
  required String chapterTitle,
  required String version,
}) =>
    '————————————————\n'
    'Edition: $seriesId\n'
    'Chapter: $chapterNumber — $chapterTitle\n'
    'App: $version';

/// A quiet "report a mistake" link at the foot of every Book chapter.
///
/// The Book is a hand-transcribed draft awaiting scholarly review, and its
/// readers know this text — several of them better than we do. This is the
/// errata channel: it sits at the end of the chapter rather than in the app bar
/// (already four icons deep) so it is found at the moment of reading and never
/// competes with it.
///
/// A report, not a suggestion box. Nothing here edits anything: corrections go
/// to a human, and for scripture a confident-but-wrong "fix" applied from an
/// email would be worse than the typo it replaced.
class ReportMistakeFooter extends StatelessWidget {
  final String chapterId;

  const ReportMistakeFooter({super.key, required this.chapterId});

  Future<void> _report(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final config = context.read<AppConfigProvider>().config;
    final series = context.read<SeriesProvider>().currentSeries;
    final chapter = context
        .read<BookProvider>()
        .book
        ?.chapters
        .where((c) => c.id == chapterId)
        .firstOrNull;

    var version = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {
      // Version is a nice-to-have for triage; never block the report on it.
    }

    final body = '${l10n.bookReportIssueIntro}\n\n\n'
        '${mistakeReportDetails(
      seriesId: series.id,
      chapterNumber: chapter?.number ?? 0,
      chapterTitle: chapter?.title ?? chapterId,
      version: version,
    )}';

    final uri = buildMistakeReportUri(
      email: config.contact.email,
      subject: l10n.bookReportIssueSubject,
      body: body,
    );

    if (uri == null || !await launchExternalUrl(uri)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookReportIssueUnavailable)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // No address configured — offer nothing rather than a dead button.
    final hasContact = context.select<AppConfigProvider, bool>(
      (p) => p.config.contact.email.contains('@'),
    );
    if (!hasContact) return const SizedBox.shrink();

    return Column(
      key: const Key('book-report-mistake-footer'),
      children: [
        // A hairline, not a Divider: the masāʾil heading owns the Divider inside
        // the scripture, and reusing it here would blur a structural cue with a
        // bit of chrome — to the reader and to the tests that assert on it.
        Container(height: 1, color: context.dividerColor),
        const SizedBox(height: 8),
        Align(
          child: TextButton.icon(
            onPressed: () => _report(context),
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: Text(context.l10n.bookReportIssue),
            style: TextButton.styleFrom(
              foregroundColor: context.secondaryTextColor,
              textStyle: context.textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
  }
}
