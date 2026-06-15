#!/usr/bin/env python3
"""Extract Kitab at-Tawheed (Arabic) into assets/content/book_tawheed-ar.json.

One-time extraction script. Re-run after edits to the source PDF or after
manual corrections to the heuristics below.
"""
import json
import re
import subprocess
import sys

PDF = "/Users/mohammadarif/Library/CloudStorage/Dropbox/Private/Islam/Tawheed/KAT Arabic/kitab-at-tawheed-arabic.pdf"

BIDI_RE = re.compile(r'[‎‏‪-‮⁦-⁩]')
ARDIGIT_ONLY = re.compile(r'^[٠-٩]+$')
FOOTNOTE_REF = re.compile(r'^[٠-٩]+\S')  # digit immediately followed by text
HEADING_RE = re.compile(r'^باب\s*[\)\(]\s*[\)\(]([٠-٩]+)\s*(.*)$')

# A footnote that starts on one page (caught by FOOTNOTE_REF, which matches
# its leading digit) can continue, *without* a leading digit, as the first
# line(s) of the next page -- leaking a bare hadith-collection citation
# (e.g. "Abu Dawud: Oaths and Vows (3808)") into the next chapter's body.
# These lines consist entirely of hadith-collection/topic names, "و"
# connectors, and parenthesized reference numbers.
CITATION_WORDS = {
    'البخاري', 'مسلم', 'أبو', 'داود', 'الترمذي', 'النسائي', 'ابن', 'ماجه',
    'أحمد', 'الدارمي', 'مالك',
    'الزكاة', 'الجامع', 'الرقاق', 'الوصايا', 'الطهارة', 'الطب', 'الجهاد',
    'الصلاة', 'النداء', 'للصلاة', 'الـكفارات', 'الكفارات', 'النذور',
    'الأيمان', 'الإيمان', 'الفتن', 'السير', 'الاستئذان',
}
CITATION_STRIP_RE = re.compile(r'[\(\)/,،:\.٠-٩\s]+')


def is_footnote_continuation(line):
    """True if `line` is a leaked hadith-citation fragment (see above)."""
    if re.match(r'^[\)\(,\.\/،]', line):
        return True
    words = [w for w in CITATION_STRIP_RE.split(line) if w]
    if not words:
        return False
    norm = [w[1:] if w.startswith('و') and w[1:] in CITATION_WORDS else w
            for w in words]
    return all(w in CITATION_WORDS for w in norm)


def clean(text):
    return BIDI_RE.sub('', text)


def strip_footnote_digits(text):
    """Drop inline Arabic-Indic footnote-reference numbers.

    Each Qur'an/hadith quotation in the body ends with a small reference
    number (e.g. "...ليعبدون{ .٢") pointing at a footnote that has already
    been removed by body_lines(). These references are always a single
    Arabic-Indic digit (a page rarely has more than ~9 footnotes), whereas
    real numbers in the prose (e.g. the author's death date "١٢٠٦ هـ" in the
    introduction) are multi-digit -- so single-digit runs are dropped
    unconditionally and multi-digit runs are left alone.
    """
    return re.sub(r'(?<![٠-٩])[٠-٩](?![٠-٩])', '', text)


def clean_content(text):
    """Final cleanup pass applied to intro/chapter text."""
    text = strip_footnote_digits(text)
    # '}' / '{' mark the start/end of a Qur'an quotation (pdftotext's
    # logical-order rendering of the ornate Qur'an brackets ﴿ ﴾).
    text = text.replace('}', '﴿').replace('{', '﴾')
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r' *\n *', '\n', text)
    return text.strip()


def pdftotext_pages(first, last):
    out = subprocess.run(
        ['pdftotext', '-f', str(first), '-l', str(last), PDF, '-'],
        capture_output=True, encoding='utf-8', check=True,
    ).stdout
    out = clean(out)
    pages = out.split('\f')
    if pages and pages[-1] == '':
        pages = pages[:-1]
    return pages


def strip_page_footer(lines):
    """Drop trailing 'Shamela.org' + page-number lines."""
    if lines and lines[-1] == 'Shamela.org':
        lines = lines[:-1]
    if lines and ARDIGIT_ONLY.match(lines[-1]):
        lines = lines[:-1]
    return lines


# ── Introduction (pages 5-6: "عن الكتاب" / "عن المؤلف") ──────────────────────

def build_intro():
    pages = pdftotext_pages(5, 6)
    parts = []
    for p in pages:
        lines = [l.strip() for l in p.split('\n')]
        lines = [l for l in lines if l]
        lines = strip_page_footer(lines)
        lines = [l for l in lines if l != 'المحتو يات']
        parts.append('\n'.join(lines))
    return clean_content('\n\n'.join(parts))


# ── Body (pages 7-60: chapter 1 "كتاب التوحيد" + 66 "باب (N)" chapters) ──────

def body_lines():
    pages = pdftotext_pages(7, 60)
    all_lines = []
    for p in pages:
        lines = [l.strip() for l in p.split('\n')]
        lines = [l for l in lines if l]
        lines = strip_page_footer(lines)
        all_lines.extend(lines)

    # Drop footnote separators, footnote-reference lines that begin with a
    # digit (e.g. "١البخاري..."), and standalone chapter-number echoes.
    out = []
    for l in all_lines:
        if l == '__________':
            continue
        if ARDIGIT_ONLY.match(l):
            continue
        if FOOTNOTE_REF.match(l):
            continue
        if is_footnote_continuation(l):
            continue
        out.append(l)
    return out


def heading_title(raw):
    """Clean a 'باب ) (N <title>' heading's trailing text into a title.

    Returns (title, truncated) — truncated is True when the heading text
    embedded a Qur'an-verse bracket ("}...") that had to be cut, meaning
    the resulting title may be too generic and an echo line (the running
    header for the next chapter, captured by strip_trailing_echo) should
    be preferred if one is available.
    """
    title = raw.strip()
    truncated = '}' in title
    if truncated:
        title = title.split('}')[0].strip()
    title = title.strip(' :')
    # Drop a duplicated leading "باب" left over from extraction artifacts.
    while title.startswith('باب'):
        title = title[len('باب'):].strip(' :')
    return ('باب ' + title).strip(), truncated


def strip_trailing_echo(lines, max_strip=3):
    """Remove trailing 'باب ...' echo lines (next chapter's running header)."""
    stripped = []
    while lines and max_strip > 0 and lines[-1].startswith('باب') and len(lines[-1]) < 100:
        stripped.append(lines.pop())
        max_strip -= 1
    return lines, list(reversed(stripped))


# "الله" as rendered elsewhere by pdftotext for this PDF (with embedded
# combining dagger-alef + shadda) — reused here so hand-fixed titles match
# the spelling style of titles derived automatically from the PDF text.
ALLAH = 'الل ّٰه'

# A handful of chapter titles can't be recovered by the heading/echo
# heuristics above (no usable echo line was printed before the heading, or
# the echo itself was cut off mid-word). These were identified by manually
# inspecting the PDF text around each heading and cross-referencing the
# Qur'an verse quoted in the chapter title.
TITLE_OVERRIDES = {
    15: f'باب قول {ALLAH} تعالى :أيشركون ما لا يخلق شيئا وهم يخلقون ولا يستطيعون لهم نصرآ ولا أنفسهم ينصرون',
    31: f'باب قول {ALLAH} تعالى :ومن الناس من يتخذ من دون {ALLAH} أندادا يحبونهم كحب {ALLAH}',
    32: f'باب قول {ALLAH} تعالى :إنما ذلـكم الشيطان يخوف أولياءه فلا تخافوهم وخافون إن كنتم مؤمنين',
    # Echo line found was truncated mid-word ("...إن كنتم مؤمن"); completed
    # per Qur'an 5:23 ("...وَعَلَى اللَّهِ فَتَوَكَّلُوا إِن كُنتُم مُّؤْمِنِينَ").
    33: f'باب قول {ALLAH} تعالى :وعلى {ALLAH} فتوكلوا إن كنتم مؤمنين',
    50: f'باب قول {ALLAH} تعالى :فلما آتاهما صالحا جعلا له شركاء فيما آتاهما فتعالى {ALLAH} عما يشركون',
    # No echo available; title derived from Qur'an 3:154.
    59: f'باب قول {ALLAH} تعالى :يظنون ب{ALLAH} غير الحق ظن الجاهلية',
    # No echo available; title derived from Qur'an 39:67.
    67: f'باب ما جاء في قول {ALLAH} تعالى :وما قدروا {ALLAH} حق قدره والأرض جميعا قبضته يوم القيامة',
}


def build_chapters():
    lines = body_lines()

    # Locate the 66 "باب (N) ..." heading lines, in document order.
    headings = []  # (line_index, raw_title_text)
    for i, l in enumerate(lines):
        m = HEADING_RE.match(l)
        if m:
            headings.append((i, m.group(2)))

    if len(headings) != 66:
        print(f"WARNING: expected 66 'باب (N)' headings, found {len(headings)}",
              file=sys.stderr)

    # Chapter 1: "كتاب التوحيد" — from the doubled opening marker to the
    # first heading. The opening marker is the doubled 'كتاب التوحيد' line.
    first_heading_idx = headings[0][0]
    ch1_lines = lines[:first_heading_idx]
    while len(ch1_lines) >= 2 and ch1_lines[0] == ch1_lines[1] == 'كتاب التوحيد':
        ch1_lines = ch1_lines[2:]
        break

    # Build content ranges for chapters 1-67, stripping trailing "باب ..."
    # echo lines (the running header for the *next* chapter, which leaks
    # into the end of the current chapter's text). The stripped echo for
    # chapter i is the fuller, un-truncated form of chapter (i+1)'s title.
    ranges = [ch1_lines]
    for idx in range(66):
        start = headings[idx][0] + 1
        end = headings[idx + 1][0] if idx + 1 < 66 else len(lines)
        ranges.append(lines[start:end])

    contents = []
    echoes = [None]  # echoes[i] = echo title for chapter i+1, captured from chapter i
    for r in ranges:
        content, echo = strip_trailing_echo(r)
        # Drop any remaining "باب ..." running-header echoes (this chapter's
        # own title, or an adjacent chapter's, repeated on a page break that
        # falls in the *middle* of this chapter's content rather than at its
        # very start/end) -- and likewise for chapter 1, whose title is the
        # book's own title "كتاب التوحيد" repeated as a running header.
        content = [l for l in content
                   if not (l.startswith('باب') and not HEADING_RE.match(l))
                   and l != 'كتاب التوحيد']
        contents.append(content)
        echoes.append(max(echo, key=len) if echo else None)

    chapters = [{
        'id': 'ch-01',
        'number': 1,
        'title': 'كتاب التوحيد',
        'text': clean_content('\n'.join(contents[0])),
    }]

    for idx in range(66):
        chapter_num = idx + 2
        heading_derived, truncated = heading_title(headings[idx][1])
        echo = echoes[chapter_num - 1]
        if chapter_num in TITLE_OVERRIDES:
            title = TITLE_OVERRIDES[chapter_num]
        elif truncated and echo:
            title = echo.strip(' :')
        else:
            title = heading_derived
        chapters.append({
            'id': f'ch-{chapter_num:02d}',
            'number': chapter_num,
            'title': title,
            'text': clean_content('\n'.join(contents[idx + 1])),
        })

    return chapters


def main():
    intro_text = build_intro()
    chapters = build_chapters()

    book = {
        'book': {
            'title': 'كتاب التوحيد',
            'author': 'الشيخ محمد بن عبد الوهاب',
        },
        'chapters': [
            {'id': 'intro', 'number': 0, 'title': 'مقدمة', 'text': intro_text},
            *chapters,
        ],
    }

    out_path = sys.argv[1] if len(sys.argv) > 1 else 'assets/content/book_tawheed-ar.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(book, f, ensure_ascii=False, indent=2)

    print(f"Wrote {out_path}: {len(book['chapters'])} chapters")
    for c in book['chapters']:
        print(f"  {c['id']:6s} #{c['number']:2d} {c['title'][:60]!r:65s} ({len(c['text'])} chars)")


if __name__ == '__main__':
    main()
