#!/usr/bin/env python3
"""Extract Kitab at-Tawheed (Arabic) into assets/content/book_tawheed-ar.json.

Source: ~/Library/CloudStorage/Dropbox/Private/Islam/Tawheed/IslamHouse/
        kitab-at-tawheed-arabaic-islam-house-gs.docx  (edited islamhouse edition)

Run once, then commit the generated JSON:
  python3 tool/extract_book.py

Requires: macOS textutil (built-in) for the .docx → .txt conversion step.

Text markers preserved in JSON (Flutter reader detects these for coloring):
  {verse text}       → Quranic verse (green)
  ((hadith text))    → Prophetic narration (amber)
  regular text       → default colour
"""
import json
import re
import subprocess
import sys
from pathlib import Path

DOCX = (
    Path.home()
    / "Library/CloudStorage/Dropbox/Private/Islam/Tawheed/IslamHouse"
    / "kitab-at-tawheed-arabaic-islam-house-gs.docx"
)
TXT_CACHE = Path("/tmp/kt-gs.txt")

# Chapter headings: "باب ..." or "باب: ..." (ch-59 uses colon variant)
CHAPTER_RE = re.compile(r"^باب[:\s]\s*.+")
# No TOC in this file — pattern intentionally never matches; toc_start = len(lines)
TOC_RE = re.compile(r"^(?:بَابُ|بابُ).*\t\d+\s*$")
# Leading bullet dashes (present in preamble lines)
BULLET_RE = re.compile(r"^-\s+")
# Inline citation references: [Surah: Ayah] — strip for clean reading
CITE_RE = re.compile(r"\[[^\[\]]+\]")


def get_lines() -> list[str]:
    if not TXT_CACHE.exists():
        if not DOCX.exists():
            sys.exit(f"ERROR: Word document not found:\n  {DOCX}")
        subprocess.run(
            [
                "textutil", "-convert", "txt", "-encoding", "UTF-8",
                "-output", str(TXT_CACHE), str(DOCX),
            ],
            check=True,
        )
    return TXT_CACHE.read_text(encoding="utf-8").split("\n")


def clean_block(lines: list[str]) -> str:
    """Strip bullets and citations; preserve blank lines; collapse runs of 3+.
    {verse} and ((hadith)) markers are left untouched for Flutter coloring."""
    filtered: list[str] = []
    for line in lines:
        original = line.strip()
        if not original:
            filtered.append("")
            continue
        s = BULLET_RE.sub("", original).strip()
        if s:
            filtered.append(s)

    text = "\n".join(filtered)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def find_toc_start(lines: list[str]) -> int:
    for i, line in enumerate(lines):
        if TOC_RE.match(line.strip()):
            return i
    return len(lines)


def find_chapter_positions(lines: list[str], limit: int) -> list[int]:
    return [
        i for i, line in enumerate(lines[:limit])
        if CHAPTER_RE.match(line.strip()) and not TOC_RE.match(line.strip())
    ]


def main() -> None:
    lines = get_lines()

    toc_start = find_toc_start(lines)
    chapter_positions = find_chapter_positions(lines, toc_start)

    if not chapter_positions:
        sys.exit("ERROR: No chapter headings (باب ...) found.")

    print(f"TOC starts at line {toc_start + 1}", file=sys.stderr)
    print(f"Found {len(chapter_positions)} chapter headings", file=sys.stderr)

    # ── Preamble (ch-00) ──────────────────────────────────────────────────────
    # The doc has a duplicate title block at lines 1-11 (author name, book name).
    # The actual content starts at the second "كتاب التوحيد" heading (line 12).
    first_ch_pos = chapter_positions[0]
    preamble_start = 0
    for i, line in enumerate(lines[:first_ch_pos]):
        if "كتاب التوحيد" in line:
            preamble_start = i + 1  # start content after the heading line

    preamble_text = clean_block(lines[preamble_start:first_ch_pos])

    chapters = [
        {
            "id": "ch-00",
            "number": 0,
            "title": "كتاب التوحيد",
            "text": preamble_text,
        }
    ]

    # ── Numbered chapters (ch-01 … ch-66) ────────────────────────────────────
    for idx, pos in enumerate(chapter_positions):
        title = lines[pos].strip()

        content_start = pos + 1
        content_end = (
            chapter_positions[idx + 1]
            if idx + 1 < len(chapter_positions)
            else toc_start
        )

        text = clean_block(lines[content_start:content_end])
        chapters.append(
            {
                "id": f"ch-{idx + 1:02d}",
                "number": idx + 1,
                "title": title,
                "text": text,
            }
        )

    book = {
        "book": {
            "title": "كتاب التوحيد",
            "author": "الشيخ محمد بن عبد الوهاب",
        },
        "chapters": chapters,
    }

    out_path = (
        sys.argv[1] if len(sys.argv) > 1 else "assets/content/book_tawheed-ar.json"
    )
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(book, f, ensure_ascii=False, indent=2)

    print(f"Wrote {out_path}: {len(book['chapters'])} chapters")
    for c in book["chapters"]:
        print(
            f"  {c['id']:6s}  #{c['number']:2d}  "
            f"{c['title'][:55]:58s}  ({len(c['text'])} chars)"
        )

    empty = [c for c in book["chapters"] if not c["text"]]
    if empty:
        print(f"\nWARNING: {len(empty)} chapters have empty text:")
        for c in empty:
            print(f"  {c['id']}  {c['title'][:60]}")


if __name__ == "__main__":
    main()
