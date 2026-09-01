# 0003 — Content identity mapping between audio, Study, and Book

- **Status:** accepted
- **Date:** 2026-09-01

## Context

Release C (Connected learning) needs "Listen to this chapter" from Book and
"Read/Study this chapter" from audio/Study. No shipped edition currently has a
trustworthy way to answer "which Book chapter does this lecture belong to?":

- The Arabic catalog's `Lecture.chapterId` values are empty strings.
- The Urdu catalog's `Chapter.id` values are `class-NN` — a namespace that
  does not match the bundled book's `BookChapter.id` values (`ch-NN`). These
  are coincidentally both short alphanumeric ids; nothing about their shape
  implies a relationship, and inferring one from display order or a
  translated title would silently break the moment either list is
  reordered or renamed.
- `BookChapter.id` values are **not globally unique across editions** —
  both `book_tawheed-ur.json` and `book_tawheed-ar.json` independently use
  `ch-01`, `ch-02`, .... (This is the same fact behind the B1a fix for the
  cross-edition reading-position leak — worth remembering here too: any
  code that resolves a `bookChapterId` must always do so against *one*
  edition's book, never a shared/ambient one.)

`StudyProgressProvider` already keys study state by the catalog's own
`Chapter.id`, so Study already has a stable same-edition identifier — it
just has nothing linking it (or audio) to a Book chapter.

## Decision

**One new nullable field, on the catalog chapter, not the lecture:**
`Chapter.bookChapterId`. A hand-off is naturally chapter-granular ("Listen to
this chapter", "Read this chapter") and Study is already chapter-scoped, so
putting the field on `Chapter` lets one mapping serve both the audio→Book and
Study→Book direction — no separate Study-specific field.

- Sourced from the remote `catalog.json` (the same place `Chapter` already
  comes from), **not** the bundled book asset — the book ships with the app
  binary and is versioned independently; the mapping is content-owner data
  that can be corrected without an app release.
- **Absence is not an error.** A chapter with no `bookChapterId` (or a
  catalog predating this field entirely) is simply unmapped — C2 omits the
  hand-off control. Every catalog in production today is exactly this case,
  and must keep parsing and working unchanged.
- **Validation is a separate, explicit step from parsing.** `Chapter.fromJson`
  stays lenient (an unknown-shaped or absent field never fails the parse —
  same contract as every other optional field here). A dedicated validator
  (`lib/services/content_mapping_validator.dart`) checks a *loaded* `Catalog`
  against *that same edition's* `BookContent` and reports:
  - **valid** — resolves to a real `BookChapter.id` in this edition's book.
  - **unmapped** — no `bookChapterId` set. Expected, not a problem.
  - **dangling** — set, but no such chapter exists in this edition's book
    (typo, removed chapter, or the edition has no book at all).
  - **duplicate** — two catalog chapters map to the same `bookChapterId`,
    which breaks the reverse (Book → audio) lookup.
  - **wrong-edition** — a mapping is only ever checked against its own
    edition's book. Because `ch-NN` ids repeat across editions, a mapping
    that would resolve against the *other* edition's book must still fail
    here — the validator is never handed a mismatched pair by construction,
    and a fixture test locks in that a same-shaped id from the wrong book
    doesn't accidentally validate.
- A CLI wrapper, `tool/validate_content_mapping.dart`, runs the same
  validator against local fixtures or a downloaded production sample, so the
  content owner has a repeatable pre-publish gate — not a manual read of the
  JSON.

**Explicitly out of scope for this ADR:** actually populating production
`catalog.json` with real `bookChapterId` values. That is Release C's named
external gate — content curation, review, and a rollback path, owned by
Mohammad Arif — not a code change. C2 (the UI hand-off) cannot start until
production samples for every supported edition pass this validator with zero
hard errors (dangling/duplicate).

## Consequences

- Existing catalogues (no `bookChapterId` anywhere) parse and validate
  cleanly as 100% unmapped — zero migration risk to what's live today.
- The mapping degrades safely: a dangling or duplicate id never crashes the
  app, only omits or flags a hand-off control in C2.
- Because the field lives in the remote catalog, a content-side correction
  ships without an app release — consistent with how `series.json` already
  lets `catalogUrl` and edition metadata self-heal.
- The validator's edition-scoping rule directly reuses the lesson from B1a's
  reading-position bug: shared, non-globally-unique chapter ids across
  editions are a recurring hazard in this codebase, not a one-off — treat any
  future cross-content-type id lookup with the same suspicion.
