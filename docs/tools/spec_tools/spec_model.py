"""Shared data model for the YouTrack bridge, the validator, the migration
importer and the prose renderer.

Project-agnostic: nothing here assumes Solidity, NFTs, or any specific
project's family names. A requirement or decision is just an ID plus text.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

# A spec item's Kind (Session 3, Task 2; Session 6 adds `informative`). Not
# every ID under a family prefix is projectable work: a spec can carry
# acceptance standards (quality gates that define done for other work, never
# closeable themselves), commercial/process scope (no engineering content) and
# informative statements (a boundary, a rejected alternative, a fact the design
# honours — kept under a stable id because other requirements cite it, never
# work and never a gate) alongside real work items, all under the same prefix.
# Generic on purpose. Only the native calea-house `**Kind:**` field
# (parser_openspec.py) populates this; the legacy parser leaves it None on
# every requirement it parses, because the legacy prose format has no place to
# state it — a format limitation, not a per-item omission.
KIND_WORK_ITEM = "work-item"
KIND_ACCEPTANCE_STANDARD = "acceptance-standard"
KIND_COMMERCIAL = "commercial"
KIND_INFORMATIVE = "informative"
VALID_KINDS = {KIND_WORK_ITEM, KIND_ACCEPTANCE_STANDARD, KIND_COMMERCIAL, KIND_INFORMATIVE}
NON_WORK_KINDS = {KIND_ACCEPTANCE_STANDARD, KIND_COMMERCIAL, KIND_INFORMATIVE}

# Reserved Spec Ref value for a YouTrack issue that legitimately has no spec
# tie: a subtask (never authored from the spec) or a defect found during work
# that doesn't trace to a requirement (Session 3, Task 1). Chosen to never
# collide with a real id: FAMILY-n, D-n and CQ-n tokens all require a
# hyphen-digit suffix, which this deliberately lacks.
SENTINEL_SPEC_REF = "NONE"

# A decision's lifecycle (calea-house `decisions` artifact, Session 6): open →
# follow-up (answered in part; the remaining question is in the body) →
# resolved | deferred. `follow-up` was added from the evidence of a real
# register, where "answered in part" is the common state between a client's
# first reply and the call that settles it.
DECISION_STATES = ("open", "follow-up", "resolved", "deferred")
OPEN_DECISION_STATES = {"open", "follow-up"}

# The word a reader sees for each state — in the rendered register table, in
# the tracker body, in the client document's callout. One table, used by the
# bridge, the renderer and (through its first word) the client-doc builder.
# A decision may override the label (`Status label: Closed` — a question with
# no decision left, recorded so it is not re-asked).
DECISION_STATE_LABELS = {
    "open": "Open",
    "follow-up": "Follow-up",
    "resolved": "Answered",
    "deferred": "Deferred",
}
# Labels (lower-cased first word) that mean "nothing left for the client to
# decide" — green in the client document, Done in the tracker.
SETTLED_LABELS = {"answered", "closed", "deferred"}


class SpecParseError(Exception):
    """Raised for any requirement/decision the parser cannot confidently
    extract. The bridge fails loudly on this — see GATE 2 item D in
    decisions.md: a requirement that can't be parsed is a hard stop, never
    a silent skip. Always carries file + line + what was expected.
    """

    def __init__(self, path: str, line: int, expected: str, found: str):
        self.path = path
        self.line = line
        self.expected = expected
        self.found = found
        super().__init__(
            f"{path}:{line}: expected {expected}, found: {found!r}"
        )


@dataclass
class Scenario:
    """One `#### Scenario:` block: a name and its GIVEN/WHEN/THEN/AND steps,
    in order. The native format's mandatory minimal acceptance statement —
    the tracker renders it as the requirement's "Done when", the client
    document as one "Acceptance" sentence, the unit test quotes it."""
    name: str
    steps: list[tuple[str, str]] = field(default_factory=list)  # ("GIVEN", "a bear with nonce 0")

    def as_sentence(self) -> str:
        """`Given a bear with nonce 0; when it is transferred; then nonce reads 1.`"""
        parts: list[str] = []
        for keyword, text in self.steps:
            text = text.strip().rstrip(".")
            if not text:
                continue
            parts.append(f"{keyword.lower()} {text}")
        if not parts:
            return ""
        sentence = "; ".join(parts)
        return sentence[0].upper() + sentence[1:] + "."


@dataclass
class Requirement:
    family: str          # e.g. "COL"
    number: int          # e.g. 2
    name: str            # short name, e.g. "Supply"
    statement: str        # the requirement body text
    status: str = "active"  # "active" | "retired"
    retired_reason: str | None = None
    retired_pointer: list[str] = field(default_factory=list)  # replacement id(s)
    kind: str | None = None  # one of VALID_KINDS, or None (legacy format — unset by design, not an omission)
    section: str | None = None  # the spec section that carries it ("3" for `## 3. …`), for the issue footer (legacy only)
    gated_by: list[str] = field(default_factory=list)  # decision ids the statement itself points at (`→ CQ-n`)
    scenarios: list[Scenario] = field(default_factory=list)  # native format only
    source_file: str = ""
    source_line: int = 0

    @property
    def id(self) -> str:
        return f"{self.family}-{self.number}"


@dataclass
class Decision:
    id: str                # "D-12" (native default) or "CQ-18" (a project keeping its own prefix)
    statement: str         # the short question/decision text (the register table's column)
    state: str              # one of DECISION_STATES
    summary: str | None = None       # one line for a register table when Resolution is longer than a table cell
    rationale: str | None = None
    blocks: list[str] = field(default_factory=list)  # requirement ids this gates
    needed_by: str | None = None
    default_if_deferred: str | None = None
    status_label: str | None = None  # the register's own word for it when it differs from DECISION_STATE_LABELS ("Closed")
    status_note: str | None = None   # provenance for the label ("call, 21 September 2026")
    title: str | None = None         # the longer heading text, when the register keeps one distinct from the statement
    section: str | None = None       # the spec section/family the register routes it to
    resolution: str | None = None    # the register's "Resolution / default" column
    detail: str | None = None        # the decision's own prose — everything after the field block, verbatim
    source_file: str = ""
    source_line: int = 0

    @property
    def label(self) -> str:
        """The word a reader sees: the register's own label if it set one, else
        the lifecycle state's default."""
        return self.status_label or DECISION_STATE_LABELS.get(self.state, self.state)

    @property
    def label_with_note(self) -> str:
        return f"{self.label} ({self.status_note})" if self.status_note else self.label

    @property
    def heading_title(self) -> str:
        return self.title or self.statement


@dataclass
class ParsedSpec:
    requirements: list[Requirement] = field(default_factory=list)
    decisions: list[Decision] = field(default_factory=list)
    version: str | None = None                  # the spec's own version line, cited in every issue footer
    source_name: str = ""                       # spec file name (legacy) or specs directory (native), cited in footers
    decisions_source_name: str = ""             # register file name, cited in decision footers
    base_dir: str | None = None                 # project root; when set, footers cite paths relative to it
    family_titles: dict[str, str] = field(default_factory=dict)    # "COL" -> "Collection contract — MintABear"
    family_sections: dict[str, str] = field(default_factory=dict)  # "COL" -> "3" (legacy only)
    family_intros: dict[str, str] = field(default_factory=dict)    # "RAF" -> the prose between the heading and the first requirement / the Purpose
    family_files: dict[str, str] = field(default_factory=dict)     # "COL" -> path of the spec file that carries the family (native)

    def families(self) -> list[str]:
        seen: list[str] = []
        for r in self.requirements:
            if r.family not in seen:
                seen.append(r.family)
        return seen

    def requirement_by_id(self, req_id: str) -> Requirement | None:
        for r in self.requirements:
            if r.id == req_id:
                return r
        return None

    def decision_by_id(self, decision_id: str) -> Decision | None:
        for d in self.decisions:
            if d.id == decision_id:
                return d
        return None

    def acceptance_standards(self) -> list[Requirement]:
        return [r for r in self.requirements if r.status == "active" and r.kind == KIND_ACCEPTANCE_STANDARD]


# How a decision's register status projects onto the tracker's State field.
# The one deliberate exception to "the bridge never writes State": the
# register owns a decision's status the way the spec owns a requirement's
# existence, so projecting it is still one-way truth (spec → tracker), not the
# tracker owning status. Requirement Tasks and Milestones are never touched.
# Keyed on the legacy register's own labels first, then on the lifecycle
# states; a project whose State bundle uses other names overrides this through
# `--overrides` ("decision_states"). Values are YouTrack's stock names on MNT.
DEFAULT_DECISION_STATES = {
    "open": "Open",
    "follow-up": "In Progress",
    "answered": "Done",
    "closed": "Done",
    "resolved": "Done",
    "deferred": "On hold",
}


def decision_state_for(decision: "Decision", states: dict[str, str] | None = None) -> str | None:
    """The tracker State a decision should carry, or None when its status has
    no mapping (reported by the caller, never guessed)."""
    table = dict(DEFAULT_DECISION_STATES)
    table.update({k.lower(): v for k, v in (states or {}).items()})
    label = (decision.status_label or "").strip().lower()
    if label and label in table:
        return table[label]
    return table.get((decision.state or "").strip().lower())


# `key: value` / `key: "value"` on its own line — enough to read the few
# non-OpenSpec scalars this stack keeps in openspec/config.yaml
# (`spec_version`, `engagement`) without a YAML dependency. Dry runs stay
# stdlib-only, and the same reader serves the bridge and the renderer.
def read_config_value(config_path: Path, key: str) -> str | None:
    if not config_path.exists():
        return None
    pattern = re.compile(rf"^\s*{re.escape(key)}\s*:\s*(.+?)\s*$", re.MULTILINE)
    m = pattern.search(config_path.read_text(encoding="utf-8"))
    if not m:
        return None
    value = m.group(1).split(" #", 1)[0].strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1]
    return value or None


def display_path(path: str, base_dir: str | None) -> str:
    """A path as an issue footer should cite it: relative to the project root
    when one is known, else the file name alone."""
    if not path:
        return ""
    p = Path(path)
    if base_dir:
        try:
            return str(p.resolve().relative_to(Path(base_dir).resolve()))
        except ValueError:
            pass
    return p.name
