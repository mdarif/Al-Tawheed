# 0002 — Chrome language follows the content edition, by default

- **Status:** accepted
- **Date:** 2026-07-16

## Context

The app ships two content editions: `tawheed-ur` (Urdu, aimed at India) and
`tawheed-ar` (Arabic, aimed at the Middle East). Chrome — nav labels, About,
Settings, player — comes from four complete ARB locales.

**This decision has swung twice. Read this before "fixing" it a third time.**

1. Originally `l10nForSeries(series) => series.isRtl ? arabicL10n : l10n`, which
   *forced* Arabic chrome on the Arabic edition.
2. `5cc657e` reduced it to `=> l10n`, fully decoupling chrome from the edition.
   That was not a whim: forcing chrome per-edition **discarded a user's chosen UI
   language** whenever they switched editions. Real bug, correct removal.
3. This ADR restores the edition's influence *as a default only*.

The trigger: the Arabic edition targets the Middle East but shipped nav reading
"Lectures / Book / Settings" around Arabic duroos, and an About screen reading
"91 Lectures". `app_ar.arb` had been 152/152 complete the whole time — the gap
was wiring, not translation.

The naive repair (restore the `isRtl` ternary) is the option that was already
tried and reverted. It also only reaches the ~12 call sites that route through
the helper, leaving About, Settings, and Flutter's own `MaterialLocalizations`
("Cancel", tooltips) on the other language — a split-brain UI.

## Decision

**One chrome locale, resolved once, with the edition as one input among three:**

    explicit pick  >  series default  >  device  >  English

- `LanguageProvider.language` derives from `_explicit ?? _seriesDefault ??
  _detected`. `_explicit` is the user's saved pick and doubles as the
  has-a-preference bit, since nothing but `setLanguage` writes it.
- Only Arabic opts in (`chromeDefaultFor`). **The Urdu edition deliberately does
  not default to Urdu chrome** — its largely Indian audience reads English more
  comfortably than Nastaliq. This asymmetry is intentional, not an oversight.
- `l10nForSeries` is **deleted**. A helper named "for series" that consults the
  series is now redundant (the edition already steers chrome upstream, via the
  default) *and* harmful (forking there would override an explicit pick — the
  5cc657e bug). Use `context.l10n`; never fork chrome on the edition.
- Resolution lives in `LanguageProvider`, not in `app.dart`'s `Consumer`:
  `MyApp` is never pumped in tests (`test/widget_test.dart:2-3`), so logic there
  would be untestable. `MaterialApp.locale` and `Directionality` already read
  the provider, so they needed no change at all.
- **Numbers in chrome follow the chrome locale**, exactly like the words beside
  them — a number is not more "content" than its label. Arabic chrome counts
  ٠١، ٠٢ (and writes ١٫٥, separator included); English chrome counts 01, 02.
  Since the Urdu edition ships English chrome, **it keeps Western digits and is
  untouched by all of this** — which is the whole point of the asymmetry above.
  The helpers read `Localizations.localeOf`, not `LanguageProvider`: that is the
  locale the surrounding words actually resolved from, so digits and words agree
  by construction even in a test that pins `MaterialApp.locale` directly.
- **The Book is the one exception.** Its chapter badges, position indicator and
  inline āyah numbers follow the *edition's* script via `series.language`, so
  the Urdu book reads ۰۱ under English chrome. Book numerals are set the way the
  print sets them; they are typography, not UI furniture.

  *(An earlier revision of this ADR had chrome numbers follow the edition too.
  That shipped Urdu numerals into the Urdu edition's English UI — a regression
  the owner caught immediately. "Follow the chrome" is both simpler and what was
  actually wanted.)*

Not gated on the `language` feature flag. That flag governs the manual switcher
only (the provider's own doc comment has always said so), and it is **`false` in
the live remote config** — gating here would make this a no-op exactly where it
ships.

## Consequences

- Middle East users get a fully Arabic app out of the box, with no content
  deploy and no per-call-site migration.
- An explicit pick is honoured everywhere and survives edition switches. The
  5cc657e regression cannot recur, because the pick sits *above* the default.
- **`setLanguage` must compare against `_explicit`, not the effective language.**
  Otherwise an Arabic-edition user tapping "العربية" (already effective via the
  default) persists nothing, and their chrome silently flips to English on the
  next edition switch. This is subtle; a test pins it.
- **While `language` is `false` remotely, the escape hatch is unreachable** — no
  user can express a pick. Flip it in the content repo to make it real.
- Switching editions flips chrome live for users without a pick. Nothing caches
  `AppLocalizations`, so this is safe. `arabicL10n` survives only for the
  Welcome screen, which renders before the edition is definitive.
- Chrome now depends on `currentSeries` being correct on the first frame, which
  forced `SeriesProvider` to hydrate from the cached manifest synchronously
  (previously it resolved to the Urdu fallback until the async fetch landed —
  harmless when chrome was decoupled, a visible flash of English now).
- A manifest omitting `language` degrades to device detection, not forced
  English — `chromeDefaultFor` returns null and the chain falls through. Safe by
  construction, which is why `SeriesConfig.fromJson` keeps its `'en'` fallback
  instead of throwing (throwing makes the parser skip the entry, demoting an
  Arabic reader into the Urdu edition with orphaned downloads).
