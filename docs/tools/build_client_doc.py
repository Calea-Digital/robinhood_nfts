#!/usr/bin/env python3
"""Build the client-facing MintABear specification.

Merges docs/SPECIFICATION.md and docs/OPEN-QUESTIONS.md into one document: each question
still open is marked, by one yellow line naming its open item in §10, under the specification
section it belongs to (matched on the tag in parentheses at the end of the `## ` heading, e.g.
`(ACT)`); §10 sets it out.
A settled question gets no callout: its answer is already written into the requirements, and the
appendix lists it in one line. A requirement's `*Technical note.*` paragraph is left out: it is
there for the build, the board and the auditor, not for MINT's reader. The specification
section whose heading contains "Decisions" is hoisted to directly after the front matter, so the
agenda opens the document. The register table is appended as an appendix in three parts — open, settled, then
the questions settled outside the register; the sign-off block stays last. The output name
carries the version read from the specification's `**Version**` line, suffix included, so a
draft and the version signed after it are separate files. The merged document is written as .docx
(WordprocessingML built here, no third-party library) and saved as .pages by Pages through
AppleScript. Tables carry no fixed row heights, so Pages sizes rows to their content.

`--operational` writes the extract for a call with MINT instead: the front matter's title and
version line under a short introduction, then the decisions section with its open items, then
"Where the work stands" — everything before §1 Scope — and nothing after (no callouts, no
appendix, no sign-off). It is named `MintABear-Operational-v<version>`, beside the
full document of the same version, which it points to.

Usage (from the repository root):

    python3 docs/tools/build_client_doc.py                  # writes docs/client/*.pages
    python3 docs/tools/build_client_doc.py --docx           # also keeps docs/client/*.docx
    python3 docs/tools/build_client_doc.py --docx-only      # stops at .docx (no Pages)
    python3 docs/tools/build_client_doc.py --operational    # the call extract instead
    python3 docs/tools/build_client_doc.py --check          # only checks §10's open items

Every build first checks §10's open items against the register (`open_items_problems`) and
writes nothing if they disagree.

Markdown subset understood: ATX headings, paragraphs, `-` and `1.` lists, pipe tables,
`>` blockquotes, `---` rules, and inline **bold**, *emphasis*, `code`, [links]().
"""

from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent / "spec_tools"))
from parser_openspec import parse_openspec  # noqa: E402
SPEC = ROOT / "docs" / "SPECIFICATION.md"
QUESTIONS = ROOT / "docs" / "OPEN-QUESTIONS.md"
OUT_DIR = ROOT / "docs" / "client"
VERSION = re.compile(r"\*\*Version\*\*\s+(?P<ver>\d+\.\d+[\w.-]*)")
SETTLED = {"answered", "closed", "deferred"}  # first word of a Status; deferred = nothing left for MINT to decide

# A4 with 2.54 cm margins → 9,026 twips of text width.
PAGE_W, PAGE_H, MARGIN = 11906, 16838, 1440
TEXT_W = PAGE_W - 2 * MARGIN

SECTION_TAG = re.compile(r"^## .*\((?P<tag>[A-Z]{2,3})\)\s*$")
QUESTION_HEAD = re.compile(r"^### (?P<id>CQ-\d+) — (?P<title>.+)$")
FIELD = re.compile(r"^- \*\*(?P<key>[^*]+):\*\* (?P<value>.+)$")
INLINE = re.compile(
    r"(\*\*[^*]+?\*\*|`[^`]+`|(?<![\w*])\*[^*\n]+?\*(?![\w*])|\[[^\]]+\]\([^)]+\))"
)
LIST_ITEM = re.compile(r"^(\s*)([-*]|\d+\.) (.+)$")


# --------------------------------------------------------------------------- Markdown → blocks

def runs(text: str, **flags: bool) -> list[tuple[str, dict[str, bool]]]:
    """Split inline Markdown into (text, {b, i, code}) runs."""
    out: list[tuple[str, dict[str, bool]]] = []
    pos = 0
    for m in INLINE.finditer(text):
        if m.start() > pos:
            out.append((text[pos:m.start()], dict(flags)))
        tok = m.group(0)
        if tok.startswith("**"):
            out.extend(runs(tok[2:-2], **{**flags, "b": True}))
        elif tok.startswith("`"):
            out.append((tok[1:-1], {**flags, "code": True}))
        elif tok.startswith("*"):
            out.extend(runs(tok[1:-1], **{**flags, "i": True}))
        else:
            link = re.match(r"\[([^\]]+)\]\(([^)]+)\)", tok)
            out.append((link.group(1), dict(flags)))
            out.append((f" ({link.group(2)})", dict(flags)))
        pos = m.end()
    if pos < len(text):
        out.append((text[pos:], dict(flags)))
    return out


def parse_blocks(md: str) -> list[dict]:
    """Parse the Markdown subset into a flat list of block dicts."""
    blocks: list[dict] = []
    lines = md.splitlines()
    i = 0
    para: list[str] = []

    def flush() -> None:
        if para:
            blocks.append({"kind": "para", "text": " ".join(s.strip() for s in para)})
            para.clear()

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            flush()
            i += 1
            continue
        if stripped.startswith("<!--") and stripped.endswith("-->"):
            # A whole-line HTML comment — the openspec markers and the GENERATED
            # notice — is plumbing, never content.
            flush()
            i += 1
            continue
        m = re.match(r"^(#{1,4}) (.+)$", line)
        if m:
            flush()
            blocks.append({"kind": "heading", "level": len(m.group(1)), "text": m.group(2).strip()})
            i += 1
            continue
        if stripped == "---":
            flush()
            i += 1
            continue
        if stripped.startswith("|"):
            flush()
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            header, body = rows[0], rows[1:]
            if body and all(re.fullmatch(r":?-{3,}:?", c) for c in body[0]):
                body = body[1:]
            blocks.append({"kind": "table", "header": header, "rows": body})
            continue
        if stripped.startswith(">"):
            flush()
            quote: list[str] = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:].strip())
                i += 1
            blocks.append({"kind": "quote", "text": " ".join(quote)})
            continue
        lm = LIST_ITEM.match(line)
        if lm:
            flush()
            ordered = lm.group(2)[0].isdigit()
            items: list[str] = []
            while i < len(lines):
                lm = LIST_ITEM.match(lines[i])
                if lm:
                    items.append(lm.group(3).strip())
                    i += 1
                elif lines[i].startswith("  ") and lines[i].strip() and items:
                    items[-1] += " " + lines[i].strip()
                    i += 1
                else:
                    break
            blocks.append({"kind": "list", "ordered": ordered, "items": items})
            continue
        para.append(line)
        i += 1
    flush()
    return blocks


# --------------------------------------------------------------------------- blocks → WordprocessingML

def run_xml(text: str, b: bool = False, i: bool = False, code: bool = False, size: int | None = None) -> str:
    props: list[str] = []
    if code:
        props.append('<w:rFonts w:ascii="Menlo" w:hAnsi="Menlo" w:cs="Menlo"/>')
        props.append('<w:sz w:val="19"/><w:szCs w:val="19"/>')
    if b:
        props.append("<w:b/><w:bCs/>")
    if i:
        props.append("<w:i/><w:iCs/>")
    if size and not code:
        props.append(f'<w:sz w:val="{size}"/><w:szCs w:val="{size}"/>')
    rpr = f"<w:rPr>{''.join(props)}</w:rPr>" if props else ""
    return f'<w:r>{rpr}<w:t xml:space="preserve">{escape(text)}</w:t></w:r>'


def runs_xml(text: str, size: int | None = None, **flags: bool) -> str:
    return "".join(run_xml(t, size=size, **f) for t, f in runs(text, **flags))


def para_xml(
    content: str,
    style: str | None = None,
    after: int = 120,
    before: int = 0,
    indent: int | None = None,
    hanging: int | None = None,
    keep_next: bool = False,
    shade: tuple[str, str] | None = None,
) -> str:
    ppr: list[str] = []
    if style:
        ppr.append(f'<w:pStyle w:val="{style}"/>')
    if keep_next:
        ppr.append("<w:keepNext/>")
    if shade:
        fill, bar = shade
        ppr.append(
            f'<w:pBdr><w:left w:val="single" w:sz="24" w:space="8" w:color="{bar}"/></w:pBdr>'
            f'<w:shd w:val="clear" w:color="auto" w:fill="{fill}"/>'
        )
    ppr.append(f'<w:spacing w:before="{before}" w:after="{after}"/>')
    if indent is not None or shade:
        left = (indent or 0) + (180 if shade else 0)
        hang = f' w:hanging="{hanging}"' if hanging else ""
        right = ' w:right="180"' if shade else ""
        ppr.append(f'<w:ind w:left="{left}"{right}{hang}/>')
    return f"<w:p><w:pPr>{''.join(ppr)}</w:pPr>{content}</w:p>"


CHAR_W, CELL_PAD = 120, 220  # twips per 10 pt character, and the two cell margins plus slack
LONG_TABLE = 8  # rows; above this a heading is not tied to the table that follows it


def column_widths(header: list[str], rows: list[list[str]]) -> list[int]:
    """Distribute the text width so that no column is narrower than its longest word.

    Each column gets at least the width of its longest word (so nothing breaks mid-word);
    whatever remains is shared in proportion to how much more each column would like,
    measured by its longest cell, clamped.
    """
    ncol = len(header)
    cells = [[header[c]] + [r[c] for r in rows if c < len(r)] for c in range(ncol)]
    plain = lambda t: t.replace("`", "").replace("*", "")
    minimum = [max(len(w) for cell in col for w in plain(cell).split() or [""]) * CHAR_W + CELL_PAD for col in cells]
    preferred = [min(max(len(plain(cell)) for cell in col), 45) * CHAR_W + CELL_PAD for col in cells]
    if sum(minimum) >= TEXT_W:
        widths = [int(TEXT_W * m / sum(minimum)) for m in minimum]
    else:
        wants = [max(pf - mn, 0) for pf, mn in zip(preferred, minimum)]
        spare = TEXT_W - sum(minimum)
        share = [spare * w / sum(wants) if sum(wants) else spare / ncol for w in wants]
        widths = [int(mn + sh) for mn, sh in zip(minimum, share)]
    widths[-1] += TEXT_W - sum(widths)
    return widths


def cell_xml(paragraphs: str, width: int, fill: str | None = None) -> str:
    shd = f'<w:shd w:val="clear" w:color="auto" w:fill="{fill}"/>' if fill else ""
    return f'<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/>{shd}</w:tcPr>{paragraphs}</w:tc>'


def table_xml(widths: list[int], rows_xml: list[str], border: str = "999999") -> str:
    borders = "".join(
        f'<w:{side} w:val="single" w:sz="4" w:space="0" w:color="{border}"/>'
        for side in ("top", "left", "bottom", "right", "insideH", "insideV")
    )
    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    return (
        "<w:tbl><w:tblPr>"
        f'<w:tblW w:w="{sum(widths)}" w:type="dxa"/>'
        f"<w:tblBorders>{borders}</w:tblBorders>"
        '<w:tblLayout w:type="fixed"/>'
        '<w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="100" w:type="dxa"/>'
        '<w:bottom w:w="60" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar>'
        f"</w:tblPr><w:tblGrid>{grid}</w:tblGrid>{''.join(rows_xml)}</w:tbl>"
        + para_xml("", after=60)
    )


def data_table_xml(header: list[str], rows: list[list[str]], widths: list[int] | None = None) -> str:
    widths = widths or column_widths(header, rows)
    header_row = "<w:tr><w:trPr><w:tblHeader/></w:trPr>" + "".join(
        cell_xml(para_xml(runs_xml(h, size=20, b=True), after=0), widths[c], fill="EEEEEE")
        for c, h in enumerate(header)
    ) + "</w:tr>"
    body_rows = []
    for r in rows:
        cells = list(r) + [""] * (len(header) - len(r))
        body_rows.append(
            "<w:tr>" + "".join(
                cell_xml(para_xml(runs_xml(cells[c], size=20), after=0), widths[c])
                for c in range(len(header))
            ) + "</w:tr>"
        )
    return table_xml(widths, [header_row] + body_rows)


def blocks_xml(blocks: list[dict], in_callout: bool = False, shade: tuple[str, str] | None = None) -> str:
    out: list[str] = []
    size = 21 if in_callout else None
    for n, blk in enumerate(blocks):
        kind = blk["kind"]
        if kind == "heading":
            level = blk["level"]
            if in_callout:
                out.append(para_xml(runs_xml(blk["text"], b=True), after=80, shade=shade, keep_next=True))
            else:
                # Pages keeps a heading with the *whole* following table, so a long table would
                # be pushed to a fresh page and leave the heading alone; release the tie then.
                following = blocks[n + 1] if n + 1 < len(blocks) else None
                long_table = following is not None and following["kind"] == "table" and len(following["rows"]) > LONG_TABLE
                out.append(para_xml(runs_xml(blk["text"]), style=f"Heading{level}", after=120,
                                    before=(360 if level == 2 else 240 if level == 3 else 160),
                                    keep_next=not long_table))
        elif kind == "para":
            out.append(para_xml(runs_xml(blk["text"], size=size), after=(80 if in_callout else 120), shade=shade))
        elif kind == "list":
            for n, item in enumerate(blk["items"], 1):
                marker = f"{n}. " if blk["ordered"] else "•  "
                if shade:
                    out.append(para_xml(run_xml(marker, size=size) + runs_xml(item, size=size),
                                        after=40, shade=shade))
                else:
                    out.append(para_xml(run_xml(marker, size=size) + runs_xml(item, size=size),
                                        after=40, indent=540, hanging=360))
            out.append(para_xml("", after=40, shade=shade))
        elif kind == "quote":
            out.append(para_xml(runs_xml(blk["text"], size=size, i=True), indent=(None if shade else 540),
                                after=120, shade=shade))
        elif kind == "table":
            out.append(data_table_xml(blk["header"], blk["rows"], blk.get("widths")))
    return "".join(out)


def open_line_xml(n: str, title: str, cq: str) -> str:
    """An open question under its section: one shaded line pointing to its item in §10."""
    return (para_xml(runs_xml(f"**Open — O{n} {title}** ({cq}): set out in §10, Decisions.", size=22),
                     before=120, after=120, shade=("FFF8DC", "C9A227")))


def callout_xml(title: str, body_blocks: list[dict], settled: bool = False) -> str:
    """A question as shaded paragraphs with a coloured bar: green once settled, yellow while open.

    Paragraphs, not a one-cell table: Pages does not split a table row across pages, so a callout
    taller than the space left on a page was clipped at its edge. Paragraphs flow on."""
    shade = ("E8F5E9", "5B9A5B") if settled else ("FFF8DC", "C9A227")
    return (
        para_xml(runs_xml(title, b=True, size=22), before=120, after=80, keep_next=True, shade=shade)
        + blocks_xml(body_blocks, in_callout=True, shade=shade)
        + para_xml("", after=120)
    )


def is_settled(status: str) -> bool:
    first = status.strip().strip("*").split()[0].rstrip(":").lower() if status.strip() else ""
    return first in SETTLED


# --------------------------------------------------------------------------- merge

def table_under(lines: list[str], heading: str) -> dict | None:
    """The first pipe table under a `## ` heading, as a table block."""
    rows: list[str] = []
    inside = False
    for line in lines:
        if line.startswith(heading):
            inside = True
            continue
        if inside and line.startswith("## "):
            break
        if inside and line.strip().startswith("|"):
            rows.append(line)
    return parse_blocks("\n".join(rows))[0] if rows else None


def parse_questions(md: str) -> tuple[dict[str, list[tuple[str, list[dict], bool]]], dict | None, dict | None]:
    """Return {section tag: [(title, body blocks, settled)]}, the register table and the closed table."""
    lines = md.splitlines()
    register = table_under(lines, "## Register")
    closed = table_under(lines, "## Closed")

    by_section: dict[str, list[tuple[str, list[dict], bool]]] = {}
    i = 0
    while i < len(lines):
        head = QUESTION_HEAD.match(lines[i])
        if not head:
            i += 1
            continue
        i += 1
        body: list[str] = []
        while i < len(lines) and not lines[i].startswith("### ") and not lines[i].startswith("## "):
            body.append(lines[i])
            i += 1
        section, status = "OTHER", "Open"
        for b in body:
            f = FIELD.match(b.strip())
            if f and f.group("key") == "Section":
                section = f.group("value").strip()
            elif f and f.group("key") == "Status":
                status = f.group("value").strip()
        settled = is_settled(status)
        label = "Confirmed" if settled else "Decision for MINT"
        title = f"{label} · {head.group('id')} — {head.group('title')}"
        by_section.setdefault(section, []).append((title, parse_blocks("\n".join(body)), settled))
    return by_section, register, closed


OPEN_STATES = {"open", "follow-up"}
TECH_NOTE = "*Technical note.*"
RETIRED = "**Retired identifiers.**"
RETIRED_ITEM = re.compile(r"(?P<id>[A-Z]{2,3}-\d+) \((?P<what>[^)]*(?:\([^)]*\)[^)]*)*)\) → (?P<by>[^;.]+)")


def retired_rows(text: str) -> list[list[str]]:
    """The rows of the retired-requirements appendix, from the rendered `**Retired identifiers.**` line."""
    return [[m.group("id"), m.group("what"), m.group("by").strip()] for m in RETIRED_ITEM.finditer(text)]
REQ_LEAD = re.compile(r"^\*\*(?P<id>[A-Z]{2,3}-\d+) ")
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def short_date(needed_by: str | None) -> tuple[str, str]:
    """(sort key, display) for a `Needed by`: its ISO date when it starts with one, else the phrase."""
    if not needed_by:
        return ("9999", "—")
    m = re.match(r"^(\d{4})-(\d{2})-(\d{2})\b", needed_by.strip())
    if not m:
        return ("9998", needed_by.strip())
    y, mo, d = m.groups()
    return (f"{y}{mo}{d}", f"{int(d)} {MONTHS[int(mo) - 1]} {y}")


def question_links(parsed) -> tuple[list, dict[str, list], dict[str, list[str]]]:
    """The questions still open, which requirements each holds up, and the reverse.

    A question holds up a requirement when the register's `Blocks` names it or the requirement's
    own statement points at the question (`→ CQ-n`) — the same links the board carries."""
    open_q = [d for d in parsed.decisions if d.state in OPEN_STATES]
    ids = {d.id for d in open_q}
    holds: dict[str, list[str]] = {d.id: [] for d in open_q}
    for d in open_q:
        for r in d.blocks:
            if parsed.requirement_by_id(r) and r not in holds[d.id]:
                holds[d.id].append(r)
    for req in parsed.requirements:
        if req.status != "active":
            continue
        for q in req.gated_by:
            if q in ids and req.id not in holds[q]:
                holds[q].append(req.id)
    waits: dict[str, list] = {}
    for d in open_q:
        for r in holds[d.id]:
            waits.setdefault(r, []).append(d)
    return open_q, waits, holds


def with_waits(blocks: list[dict], waits: dict[str, list]) -> list[dict]:
    """After each requirement's acceptance line, the open questions that requirement waits on."""
    out: list[dict] = []
    current: str | None = None
    for blk in blocks:
        out.append(blk)
        if blk["kind"] != "para":
            continue
        lead = REQ_LEAD.match(blk["text"])
        if lead:
            current = lead.group("id")
        elif blk["text"].startswith("*Acceptance.*") and current in waits:
            def when(d) -> str:
                key, shown = short_date(d.needed_by)
                return f"needed by {shown}" if not key.startswith("999") else shown
            items = "; ".join(f"**{d.id}** {d.statement} ({when(d)})" for d in waits[current])
            out.append({"kind": "para", "text": f"**Waits on** {items}."})
            current = None
    return out


OPEN_ITEM = re.compile(r"^\*\*O(?P<n>\d+) — (?P<title>.+) \((?P<cq>CQ-\d+)\)\*\* · (?P<when>.+)$", re.M)
LONG_MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
               "October", "November", "December"]


def open_items_problems(spec_md: str, parsed) -> list[str]:
    """What is wrong with §10's open items against the register.

    Every question still open has exactly one item, numbered O1, O2, … in the order of its
    `Needed by`, and an item whose question is needed by a date names that date."""
    open_q = {d.id: d for d in question_links(parsed)[0]}
    items = list(OPEN_ITEM.finditer(spec_md))
    problems = []
    for want, m in enumerate(items, 1):
        if int(m.group("n")) != want:
            problems.append(f"O{m.group('n')} is item {want}: number the items O1, O2, … in order")
    named = [m.group("cq") for m in items]
    for cq in sorted(set(named)):
        if named.count(cq) > 1:
            problems.append(f"{cq} has {named.count(cq)} items")
    for cq in sorted(set(open_q) - set(named)):
        problems.append(f"{cq} is open in the register but has no item")
    for cq in sorted(set(named) - set(open_q)):
        problems.append(f"{cq} has an item but is not open in the register")
    keys = [short_date(open_q[m.group("cq")].needed_by)[0] for m in items if m.group("cq") in open_q]
    if keys != sorted(keys):
        problems.append("the items are not in the order of their questions' Needed by")
    for m in items:
        d = open_q.get(m.group("cq"))
        iso = re.match(r"^(\d{4})-(\d{2})-(\d{2})\b", (d.needed_by or "").strip()) if d else None
        if iso:
            shown = f"{int(iso.group(3))} {LONG_MONTHS[int(iso.group(2)) - 1]}"
            if not re.search(rf"\b{shown}\b", m.group("when")):
                problems.append(f"O{m.group('n')} ({m.group('cq')}) says '{m.group('when')}'; "
                                f"the register needs it by {d.needed_by}")
    return problems


def operational_front(front_md: str, version: str) -> str:
    """The extract's front matter: the title and version line, then what the extract is."""
    lines = front_md.splitlines()
    end = next(i for i, line in enumerate(lines) if line.strip() == "<!-- openspec:end -->")
    head = [line.replace("# MintABear — Specification", "# MintABear — Operational summary") for line in lines[:end + 1]]
    intro = (
        f"The part of specification v{version} to work from on a call: what MINT is asked to decide or "
        "supply, soonest first, and where the work stands. Everything else — the requirements, "
        "each question set out in full, the register and the sign-off — is in "
        f"*MintABear-Specification-v{version}*, which this summary follows exactly."
    )
    return "\n".join(head + ["", intro, ""])


def merge(spec_md: str, by_section: dict, register: dict | None, closed: dict | None = None,
          parsed=None, operational: bool = False) -> str:
    """Body XML: spec sections with their questions appended; register appendix; sign-off last.

    With `operational`, only the front matter, the decisions section and the sections before §1."""
    waits = question_links(parsed)[1] if parsed else {}
    items = {m.group("cq"): (m.group("n"), m.group("title")) for m in OPEN_ITEM.finditer(spec_md)}

    def question_xml(title: str, qblocks: list[dict], settled: bool) -> str:
        if settled:
            return ""
        cq = re.search(r"CQ-\d+", title)
        if cq and cq.group(0) in items:
            return open_line_xml(*items[cq.group(0)], cq.group(0))
        return callout_xml(title, qblocks, settled)
    lines = spec_md.splitlines()
    chunks: list[tuple[str | None, list[str]]] = []
    current: tuple[str | None, list[str]] = (None, [])
    for line in lines:
        if line.startswith("## "):
            chunks.append(current)
            current = (line, [])
        else:
            current[1].append(line)
    chunks.append(current)

    # The agenda opens the client document: hoist the decisions section behind the front matter.
    front, rest = chunks[0], chunks[1:]
    agenda = [c for c in rest if c[0] and "Decisions" in c[0]]
    rest = [c for c in rest if c not in agenda]
    if operational:
        # Stop at the first numbered section (§1 Scope): the extract is what comes before it.
        first_numbered = next(i for i, c in enumerate(rest) if c[0] and re.match(r"^## \d+\.", c[0]))
        version = VERSION.search(spec_md)
        front = (None, operational_front("\n".join(front[1]), version.group("ver") if version else "draft").splitlines())
        chunks = [front] + agenda + rest[:first_numbered]
    else:
        chunks = [front] + agenda + rest

    used: set[str] = set()
    retired: list[list[str]] = []
    parts: list[str] = []
    signoff: str | None = None
    for heading, body in chunks:
        body_md = "\n".join(body)
        if heading is None:
            parts.append(blocks_xml(parse_blocks(body_md)))
            continue
        if "Sign-off" in heading:
            signoff = blocks_xml(parse_blocks(heading + "\n" + body_md))
            continue
        section_blocks = []
        for blk in parse_blocks(heading + "\n" + body_md):
            if blk["kind"] == "para" and blk["text"].startswith(TECH_NOTE):
                continue
            if blk["kind"] == "para" and blk["text"].startswith(RETIRED):
                retired.extend(retired_rows(blk["text"]))
                continue
            section_blocks.append(blk)
        section_blocks = with_waits(section_blocks, waits)
        part = blocks_xml(section_blocks)
        tag_match = SECTION_TAG.match(heading)
        if tag_match and not operational:
            tag = tag_match.group("tag")
            for title, qblocks, settled in by_section.get(tag, []):
                part += question_xml(title, qblocks, settled)
            used.add(tag)
        parts.append(part)

    if operational:
        return "".join(parts)

    leftovers = [q for tag, qs in by_section.items() if tag not in used for q in qs if not q[2]]
    if leftovers:
        parts.append(blocks_xml([{"kind": "heading", "level": 2, "text": "Other questions for MINT"}]))
        parts.extend(question_xml(t, b, s) for t, b, s in leftovers)

    # The appendix starts on a fresh page: its first table is longer than the
    # space left under the last callout, and Pages moves a table whole, which
    # would strand the heading and its intro on an otherwise empty page.
    parts.append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
    parts.append(blocks_xml([
        {"kind": "heading", "level": 2, "text": "Appendix — Register of questions"},
        {"kind": "para", "text": ("One line per settled question. The open ones are §10's open items, "
                                  "with what each holds up and when it is needed.")
                                 if parsed else
                                 "One line per question. Open items first, for deciding in one place; "
                                 "then the settled ones. Each question also appears in full under the "
                                 "section it affects."},
    ]))
    if register:
        header = register["header"]
        status_col = next((c for c, h in enumerate(header) if h.strip().lower() == "status"), None)
        if status_col is None:
            parts.append(data_table_xml(header, register["rows"]))
        else:
            open_rows = [r for r in register["rows"] if not is_settled(r[status_col])]
            settled_rows = [r for r in register["rows"] if is_settled(r[status_col])]
            if not parsed:
                parts.append(blocks_xml([{"kind": "heading", "level": 3, "text": "Open for the call"}]))
                parts.append(data_table_xml(header, open_rows))
            # Tied to its table even when the table is long: the table fills most of a page, so an
            # untied heading is stranded alone on the page before it.
            parts.append(para_xml(runs_xml("Settled"), style="Heading3", after=120, before=240, keep_next=True))
            # A settled question is needed by nothing any more, so its "Needed by" column is dropped.
            keep = [c for c, h in enumerate(header) if h.strip().lower() != "needed by"]
            parts.append(data_table_xml([header[c] for c in keep], [[r[c] for c in keep] for r in settled_rows]))
    if closed:
        parts.append(blocks_xml([
            {"kind": "heading", "level": 3, "text": "Settled outside the register"},
            {"kind": "para", "text": "Decided in the statement of work, the meeting of 15 September "
                                     "2026 or MINT's written answers, and recorded here so that they "
                                     "are not re-opened."},
        ]))
        parts.append(data_table_xml(closed["header"], closed["rows"]))
    if retired:
        parts.append(blocks_xml([
            {"kind": "heading", "level": 2, "text": "Appendix — Retired requirements"},
            {"kind": "para", "text": "Requirements retired in earlier versions, each with what replaced it. "
                                     "An identifier is never reused."},
        ]))
        parts.append(data_table_xml(["Retired", "What it was", "Replaced by"], retired))
    if signoff:
        parts.append(signoff)
    return "".join(parts)


# --------------------------------------------------------------------------- package

CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>"""

ROOT_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"""

DOC_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>"""

W_NS = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'


def heading_style(name: str, size: int, outline: int) -> str:
    return (
        f'<w:style w:type="paragraph" w:styleId="{name}"><w:name w:val="{name.replace("Heading", "heading ")}"/>'
        '<w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
        f'<w:pPr><w:keepNext/><w:outlineLvl w:val="{outline}"/></w:pPr>'
        f'<w:rPr><w:b/><w:bCs/><w:sz w:val="{size}"/><w:szCs w:val="{size}"/></w:rPr></w:style>'
    )


STYLES = (
    f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles {W_NS}>'
    "<w:docDefaults><w:rPrDefault><w:rPr>"
    '<w:rFonts w:ascii="Helvetica Neue" w:hAnsi="Helvetica Neue" w:cs="Helvetica Neue"/>'
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-GB"/>'
    "</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr>"
    '<w:spacing w:after="120" w:line="276" w:lineRule="auto"/>'
    "</w:pPr></w:pPrDefault></w:docDefaults>"
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
    + heading_style("Heading1", 44, 0)
    + heading_style("Heading2", 32, 1)
    + heading_style("Heading3", 26, 2)
    + heading_style("Heading4", 23, 3)
    + "</w:styles>"
)


def document_xml(body: str) -> str:
    sect = (
        f'<w:sectPr><w:pgSz w:w="{PAGE_W}" w:h="{PAGE_H}"/>'
        f'<w:pgMar w:top="{MARGIN}" w:right="{MARGIN}" w:bottom="{MARGIN}" w:left="{MARGIN}" '
        'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>'
    )
    return (
        f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document {W_NS}>'
        f"<w:body>{body}{sect}</w:body></w:document>"
    )


def write_docx(path: Path, body: str) -> None:
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", CONTENT_TYPES)
        z.writestr("_rels/.rels", ROOT_RELS)
        z.writestr("word/_rels/document.xml.rels", DOC_RELS)
        z.writestr("word/styles.xml", STYLES)
        z.writestr("word/document.xml", document_xml(body))


# --------------------------------------------------------------------------- pipeline

def main(argv: list[str]) -> int:
    docx_only = "--docx-only" in argv
    keep_docx = docx_only or "--docx" in argv
    operational = "--operational" in argv
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    spec_md = SPEC.read_text(encoding="utf-8")
    by_section, register, closed = parse_questions(QUESTIONS.read_text(encoding="utf-8"))
    openspec = ROOT / "openspec"
    parsed = parse_openspec(openspec / "specs", openspec / "decisions.md", openspec / "config.yaml", ROOT)
    problems = open_items_problems(spec_md, parsed)
    if problems:
        print("§10's open items disagree with openspec/decisions.md:", *problems, sep="\n  ", file=sys.stderr)
        return 1
    if "--check" in argv:
        print("§10's open items match the register")
        return 0
    body = merge(spec_md, by_section, register, closed, parsed, operational)

    version = VERSION.search(spec_md)
    kind = "Operational" if operational else "Specification"
    out_name = f"MintABear-{kind}-v{version.group('ver') if version else 'draft'}"
    docx_path = OUT_DIR / f"{out_name}.docx"
    pages_path = OUT_DIR / f"{out_name}.pages"
    write_docx(docx_path, body)
    if docx_only:
        print(f"wrote {docx_path}")
        return 0

    if pages_path.exists():
        pages_path.unlink()
    script = f'''
        tell application "Pages"
            set theDoc to open POSIX file "{docx_path}"
            save theDoc in POSIX file "{pages_path}"
            close theDoc saving no
        end tell
    '''
    try:
        subprocess.run(["osascript", "-e", script], check=True)
    except subprocess.CalledProcessError as exc:
        print(f"Pages export failed ({exc}); {docx_path} is the deliverable instead", file=sys.stderr)
        return 1
    if not keep_docx:
        docx_path.unlink()
    print(f"wrote {pages_path}" + (f" and {docx_path}" if keep_docx else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
