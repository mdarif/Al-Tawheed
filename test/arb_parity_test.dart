import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the raw ARB source files, NOT the generated `AppLocalizations`.
///
/// AGENTS.md rule #1 — *every user-facing string exists in all 4 ARB locales* —
/// is enforced today by discipline alone: `l10n.yaml` sets no
/// `untranslated-messages-file`, gen-l10n silently falls back to English for a
/// missing key, and nothing else reads these files. This is that missing guard.
///
/// Deliberately locale-symmetric: `ur_roman` is a first-class locale here, not a
/// variant of `ur`. It ships its own ARB and drifts on its own.
void main() {
  const arbDir = 'lib/l10n';
  const template = 'en'; // matches l10n.yaml's template-arb-file
  const locales = ['en', 'ar', 'ur', 'ur_roman'];

  /// The translatable entries of an ARB: everything except `@@`-prefixed config
  /// (`@@locale`) and `@`-prefixed metadata (`@key` placeholder declarations).
  Map<String, String> messages(String locale) {
    final raw = File('$arbDir/app_$locale.arb').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };
  }

  /// The full ARB, metadata included — needed to read `@key.placeholders`.
  Map<String, dynamic> rawArb(String locale) =>
      jsonDecode(File('$arbDir/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  final byLocale = {for (final l in locales) l: messages(l)};

  // 2.1 — the parity rule itself, mechanically.
  test('all 4 locales define exactly the same key set', () {
    final expected = byLocale[template]!.keys.toSet();
    for (final locale in locales) {
      final actual = byLocale[locale]!.keys.toSet();
      expect(
        actual.difference(expected),
        isEmpty,
        reason: '$locale has keys not in the $template template: '
            '${actual.difference(expected)}',
      );
      expect(
        expected.difference(actual),
        isEmpty,
        reason: '$locale is MISSING keys (gen-l10n would silently serve '
            'English): ${expected.difference(actual)}',
      );
    }
  });

  // 2.3 — a blank value renders as an empty label at runtime; gen-l10n does not
  // complain. Whitespace-only counts as blank.
  test('no locale has an empty or whitespace-only value', () {
    final blanks = <String>[];
    for (final locale in locales) {
      byLocale[locale]!.forEach((key, value) {
        if (value.trim().isEmpty) blanks.add('$locale:$key');
      });
    }
    expect(blanks, isEmpty, reason: 'blank values: $blanks');
  });

  // 2.2 — every placeholder DECLARED in the template (`@key.placeholders`) must
  // appear in every locale's translation, or that locale silently drops the
  // interpolated value. Checked against the declared names (not by extracting
  // `{...}` tokens) so ICU sub-message bodies — `one{lecture}` — never read as
  // placeholders.
  test('every declared placeholder is present in all 4 locales', () {
    final templateArb = rawArb(template);
    final missing = <String>[];

    for (final entry in templateArb.entries) {
      if (!entry.key.startsWith('@') || entry.key.startsWith('@@')) continue;
      final meta = entry.value;
      if (meta is! Map || meta['placeholders'] is! Map) continue;

      final key = entry.key.substring(1); // strip the leading '@'
      final names = (meta['placeholders'] as Map).keys.cast<String>();

      for (final locale in locales) {
        final value = byLocale[locale]![key];
        if (value == null) continue; // a missing key is 2.1's failure, not this
        for (final name in names) {
          // A reference is `{name}` (simple) or `{name,` (ICU argument head).
          if (!RegExp('\\{$name[},]').hasMatch(value)) {
            missing.add('$locale:$key drops {$name}');
          }
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  // 2.4 — malformed ICU (a dropped `}` in a plural) ships either a crash or the
  // literal `{count, plural…}` string to the user. A full ICU parse is
  // overkill; unbalanced braces catch the realistic corruption. NOTE: we do NOT
  // assert that a plural in `en`/`ar` is mirrored by a plural in `ur`/`ur_roman`
  // — the Urdu editions legitimately use flat forms (`{count} حصے`), so that
  // would be a false failure.
  test('braces are balanced in every value', () {
    final unbalanced = <String>[];
    for (final locale in locales) {
      byLocale[locale]!.forEach((key, value) {
        var depth = 0;
        for (final unit in value.codeUnits) {
          if (unit == 0x7B) depth++; // {
          if (unit == 0x7D) depth--; // }
          if (depth < 0) break; // a '}' before its '{'
        }
        if (depth != 0) unbalanced.add('$locale:$key ("$value")');
      });
    }
    expect(unbalanced, isEmpty, reason: 'unbalanced { }: $unbalanced');
  });
}
