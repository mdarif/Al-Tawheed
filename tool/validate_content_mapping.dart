// A repeatable pre-publish gate for ADR-0003's content-identity mapping —
// run this against a downloaded production catalog.json (or a local
// fixture) and its matching bundled book before publishing a
// bookChapterId change to the CDN. Exits non-zero on any hard error
// (dangling/duplicate), so it can gate a real CDN publish.
//
// Usage:
//   dart run tool/validate_content_mapping.dart \
//       --catalog=path/to/catalog.json \
//       --book=path/to/book_<seriesId>.json
//
// The --book path is the edition's OWN bundled book asset — never mix
// editions (see ADR-0003: BookChapter.id values like "ch-01" repeat across
// editions, so validating against the wrong book produces meaningless
// results).

import 'dart:convert';
import 'dart:io';

import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/services/content_mapping_validator.dart';

Future<void> main(List<String> args) async {
  final catalogPath = _option(args, '--catalog');
  final bookPath = _option(args, '--book');
  if (catalogPath == null) {
    stderr.writeln(
      'Usage: dart run tool/validate_content_mapping.dart '
      '--catalog=<path> [--book=<path>]\n'
      '(omit --book to validate an edition that ships no book — every '
      'mapped chapter will report dangling, exactly as it should)',
    );
    exitCode = 2;
    return;
  }

  final catalogJson = jsonDecode(await File(catalogPath).readAsString())
      as Map<String, dynamic>;
  final catalog = Catalog.fromJson(catalogJson);

  BookContent? book;
  if (bookPath != null) {
    final bookJson =
        jsonDecode(await File(bookPath).readAsString()) as Map<String, dynamic>;
    book = BookContent.fromJson(bookJson);
  }

  final report = validateContentMapping(catalog, book);

  stdout.writeln('Content mapping report for $catalogPath');
  if (book != null) stdout.writeln('  against book: $bookPath');
  stdout.writeln('  ${catalog.chapters.length} chapters total');
  stdout.writeln('  valid:     ${report.valid.length}');
  stdout.writeln('  unmapped:  ${report.unmapped.length}');
  stdout.writeln('  dangling:  ${report.dangling.length}');
  stdout.writeln('  duplicate: ${report.duplicate.length}');

  for (final r in report.dangling) {
    stdout.writeln(
      '    DANGLING  chapter "${r.chapter.id}" -> "${r.chapter.bookChapterId}" '
      '(no such Book chapter in this edition)',
    );
  }
  for (final r in report.duplicate) {
    stdout.writeln(
      '    DUPLICATE chapter "${r.chapter.id}" -> "${r.chapter.bookChapterId}" '
      '(claimed by more than one catalog chapter)',
    );
  }

  if (report.hasHardErrors) {
    stderr.writeln(
      '\nFAILED: ${report.dangling.length + report.duplicate.length} '
      'hard error(s) — fix before publishing.',
    );
    exitCode = 1;
  } else {
    stdout.writeln('\nOK — no hard errors.');
  }
}

String? _option(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}
