import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/series_provider.dart';
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
/// affordance rather than offer an action that cannot work.
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

/// The report as plain text for the clipboard fallback, when no mail app can be
/// opened. Carries the address and subject inline so a report pasted into any
/// app — chat, notes, a webmail tab — still says where it needs to go.
String mistakeReportPlaintext({
  required String email,
  required String subject,
  required String body,
}) =>
    'To: $email\n'
    'Subject: $subject\n\n'
    '$body';

/// Whether a contact address is configured. The report action is only offered
/// when a report has somewhere to go — a menu row that can't send anywhere is
/// worse than none.
bool hasBookContact(BuildContext context) =>
    context.read<AppConfigProvider>().config.contact.email.contains('@');

/// Opens a prefilled correction report for a Book chapter.
///
/// The Book is a hand-transcribed draft awaiting scholarly review, and its
/// readers know this text — several of them better than we do. This is the
/// errata channel. A report, not a suggestion box: nothing here edits anything,
/// corrections go to a human, and for scripture a confident-but-wrong "fix"
/// applied from an email would be worse than the typo it replaced.
///
/// Tries the mail app first; if none can open (common on a phone with no email
/// account), copies the whole report — address included — to the clipboard so
/// it is never lost.
Future<void> reportBookMistake(
  BuildContext context, {
  required int chapterNumber,
  required String chapterTitle,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final config = context.read<AppConfigProvider>().config;
  final series = context.read<SeriesProvider>().currentSeries;

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
    chapterNumber: chapterNumber,
    chapterTitle: chapterTitle,
    version: version,
  )}';

  final email = config.contact.email;
  final subject = l10n.bookReportIssueSubject;

  final uri = buildMistakeReportUri(email: email, subject: subject, body: body);
  if (uri != null && await launchExternalUrl(uri)) return;

  await Clipboard.setData(
    ClipboardData(
      text: mistakeReportPlaintext(email: email, subject: subject, body: body),
    ),
  );
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.bookReportIssueCopied(email))),
  );
}
