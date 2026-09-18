#!/usr/bin/env python3
"""Build the client-facing MintABear specification.

Merges docs/SPECIFICATION.md and docs/OPEN-QUESTIONS.md into one document: each question
is appended, as a shaded callout, to the specification section it belongs to (matched on
the tag in parentheses at the end of the `## ` heading, e.g. `(ACT)`). A question whose
Status is Answered or Closed renders as a green "Confirmed" callout; any other status as a
yellow "Decision for MINT" callout. The specification section whose heading contains
"Decisions for the" is hoisted to directly after the front matter, so the agenda opens the
document. The register table is appended as an appendix in two parts (open, then settled);
the sign-off block stays last. The output name carries the version read from the
specification's `**Version** X.Y` line. The merged document is written as .docx
(WordprocessingML built here, no third-party library) and saved as .pages by Pages through
AppleScript. Tables carry no fixed row heights, so Pages sizes rows to their content.

Usage (from the repository root):

    python3 docs/tools/build_client_doc.py              # writes docs/client/*.pages
    python3 docs/tools/build_client_doc.py --docx       # also keeps docs/client/*.docx
    python3 docs/tools/build_client_doc.py --docx-only  # stops at .docx (no Pages)

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
SPEC = ROOT / "docs" / "SPECIFICATION.md"
QUESTIONS = ROOT / "docs" / "OPEN-QUESTIONS.md"
OUT_DIR = ROOT / "docs" / "client"
VERSION = re.compile(r"\*\*Version\*\*\s+(?P<ver>\d+\.\d+)")
SETTLED = {"answered", "closed"}

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
) -> str:
    ppr: list[str] = []
    if style:
        ppr.append(f'<w:pStyle w:val="{style}"/>')
    if keep_next:
        ppr.append("<w:keepNext/>")
    ppr.append(f'<w:spacing w:before="{before}" w:after="{after}"/>')
    if indent is not None:
        hang = f' w:hanging="{hanging}"' if hanging else ""
        ppr.append(f'<w:ind w:left="{indent}"{hang}/>')
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


def data_table_xml(header: list[str], rows: list[list[str]]) -> str:
    widths = column_widths(header, rows)
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


def blocks_xml(blocks: list[dict], in_callout: bool = False) -> str:
    out: list[str] = []
    size = 21 if in_callout else None
    for n, blk in enumerate(blocks):
        kind = blk["kind"]
        if kind == "heading":
            level = blk["level"]
            if in_callout:
                out.append(para_xml(runs_xml(blk["text"], b=True), after=80))
            else:
                # Pages keeps a heading with the *whole* following table, so a long table would
                # be pushed to a fresh page and leave the heading alone; release the tie then.
                following = blocks[n + 1] if n + 1 < len(blocks) else None
                long_table = following is not None and following["kind"] == "table" and len(following["rows"]) > LONG_TABLE
                out.append(para_xml(runs_xml(blk["text"]), style=f"Heading{level}", after=120,
                                    before=(360 if level == 2 else 240 if level == 3 else 160),
                                    keep_next=not long_table))
        elif kind == "para":
            out.append(para_xml(runs_xml(blk["text"], size=size), after=(80 if in_callout else 120)))
        elif kind == "list":
            for n, item in enumerate(blk["items"], 1):
                marker = f"{n}. " if blk["ordered"] else "•  "
                out.append(para_xml(run_xml(marker, size=size) + runs_xml(item, size=size),
                                    after=40, indent=540, hanging=360))
            out.append(para_xml("", after=40))
        elif kind == "quote":
            out.append(para_xml(runs_xml(blk["text"], size=size, i=True), indent=540, after=120))
        elif kind == "table":
            out.append(data_table_xml(blk["header"], blk["rows"]))
    return "".join(out)


def callout_xml(title: str, body_blocks: list[dict], settled: bool = False) -> str:
    """One shaded, bordered cell holding a question: green once settled, yellow while open."""
    fill, border = ("E8F5E9", "5B9A5B") if settled else ("FFF8DC", "C9A227")
    inner = para_xml(runs_xml(title, b=True, size=22), after=80, keep_next=True) + blocks_xml(body_blocks, in_callout=True)
    row = "<w:tr>" + cell_xml(inner, TEXT_W, fill=fill) + "</w:tr>"
    return table_xml([TEXT_W], [row], border=border)


def is_settled(status: str) -> bool:
    first = status.strip().strip("*").split()[0].rstrip(":").lower() if status.strip() else ""
    return first in SETTLED


# --------------------------------------------------------------------------- merge

def parse_questions(md: str) -> tuple[dict[str, list[tuple[str, list[dict], bool]]], list[dict] | None]:
    """Return {section tag: [(title, body blocks, settled)]} and the register table block."""
    lines = md.splitlines()
    register: list[dict] | None = None
    in_register = False
    reg_lines: list[str] = []
    for line in lines:
        if line.startswith("## Register"):
            in_register = True
            continue
        if in_register and line.startswith("## "):
            break
        if in_register and line.strip().startswith("|"):
            reg_lines.append(line)
    if reg_lines:
        register = parse_blocks("\n".join(reg_lines))[0]

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
    return by_section, register


def merge(spec_md: str, by_section: dict, register: list[dict] | None) -> str:
    """Body XML: spec sections with their questions appended; register appendix; sign-off last."""
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
    agenda = [c for c in rest if c[0] and "Decisions for the" in c[0]]
    rest = [c for c in rest if c not in agenda]
    chunks = [front] + agenda + rest

    used: set[str] = set()
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
        part = blocks_xml(parse_blocks(heading + "\n" + body_md))
        tag_match = SECTION_TAG.match(heading)
        if tag_match:
            tag = tag_match.group("tag")
            for title, qblocks, settled in by_section.get(tag, []):
                part += callout_xml(title, qblocks, settled)
            used.add(tag)
        parts.append(part)

    leftovers = [q for tag, qs in by_section.items() if tag not in used for q in qs]
    if leftovers:
        parts.append(blocks_xml([{"kind": "heading", "level": 2, "text": "Other questions for MINT"}]))
        parts.extend(callout_xml(t, b, s) for t, b, s in leftovers)

    parts.append(blocks_xml([
        {"kind": "heading", "level": 2, "text": "Appendix — Register of questions"},
        {"kind": "para", "text": "One line per question. Open items first, for deciding in one place; "
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
            parts.append(blocks_xml([{"kind": "heading", "level": 3, "text": "Open for the call"}]))
            parts.append(data_table_xml(header, open_rows))
            parts.append(blocks_xml([{"kind": "heading", "level": 3, "text": "Settled"}]))
            parts.append(data_table_xml(header, settled_rows))
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
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    spec_md = SPEC.read_text(encoding="utf-8")
    by_section, register = parse_questions(QUESTIONS.read_text(encoding="utf-8"))
    body = merge(spec_md, by_section, register)

    version = VERSION.search(spec_md)
    out_name = f"MintABear-Specification-v{version.group('ver') if version else 'draft'}"
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
