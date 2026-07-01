# Architecture Decision Records (ADRs)

One file per significant, non-obvious decision — the *why* that code and commits
don't capture. Add one when you make a choice future-you (or another LLM) would
question or try to "fix" without the context.

**Naming:** `NNNN-short-title.md` (e.g. `0001-java-21.md`), zero-padded, sequential.

**Template:**

```markdown
# NNNN — Title

- **Status:** accepted | superseded by [NNNN] | deprecated
- **Date:** YYYY-MM-DD

## Context
What forced a decision. The constraints and forces in play.

## Decision
What we chose, stated plainly.

## Consequences
What this makes easy, what it makes hard, and what to watch out for.
```

Keep them short. A quick landmine or convention belongs in
[../gotchas.md](../gotchas.md); an ADR is for a *decision with trade-offs*.

Candidate decisions worth back-filling here (not yet written):
Java 21 requirement · series-aware l10n (`l10nForSeries`) · per-entry JSON
parsing for remote lists · main-isolate JSON decode (not `compute`) ·
auto-deploy to Play internal track only.
