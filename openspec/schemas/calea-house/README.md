# calea-openspec-schema

A Calea house OpenSpec schema — installed schema id: **`calea-house`** (the
repo name says what it plugs into; the schema id inside is what
`config.yaml`'s `schema:` field and `openspec/schemas/<name>/` both use).
Project-agnostic — every artifact here holds on a Python backend with no
blockchain in it, same as a Solidity protocol. Built from evidence, not
invention: extracted and classified from real Calea specs (MintABear,
Kenomic's tokenomics-smart-contracts, GGContracts) rather than designed from
scratch. See `schema-analysis.md` in
[calea-ai-stack](https://github.com/jedibojan/ai-stack) for the full
classification and reasoning behind every choice below.

**Status: pre-release, untagged.** The dry run (Phase 6) passed against a
real spec (MintABear/MNT) — 73 requirements, 19 decisions, matched by hand
against the source document. **The requirement-format question is decided**:
`prose-is-legacy-with-sunset` (option B, of three considered — full reasoning
in `calea-ai-stack`'s `decisions.md`, GATE 3 follow-up #1). This schema's
native shape (`### Requirement:` heading + one mandatory minimal Scenario) is
the format for ongoing work, on every project, going forward. A legacy
Calea-prose spec (bold-inline `**FAMILY-n Name.**`, no heading, no embedded
scenario — what MintABear's and Kenomic's real specs both use) gets migrated
into this shape once, via `calea-ai-stack/scripts/youtrack-bridge/
parser_legacy_calea.py` reframed as a one-time importer, not carried forward
as a second permanent format.

**Tagging condition**: `v0.1.0` once the first real migration (MintABear /
MNT, September 2026) is committed in its project — not merely once the format
question was decided. Confirmed against the CLI along the way: a requirement's
`#### Scenario:` block is **mandatory** for `openspec validate` to pass; a
`**Kind:**` first line survives `openspec archive` but a MODIFIED delta without
it strips Kind silently; a REMOVED delta deletes the block and writes nothing;
an extra `## Retired Requirements` section survives archive (see `schema.yaml`'s
`specs` instruction for what follows from each).

## Install

Copy this repo's contents into a consuming project as `openspec/schemas/calea-house/` —
a plain copy, not a git submodule (two repos with a git-level coupling is a
maintenance cost paid every time either moves, for no benefit at this size).

```bash
git clone https://github.com/jedibojan/calea-openspec-schema /tmp/calea-openspec-schema
mkdir -p openspec/schemas
cp -r /tmp/calea-openspec-schema openspec/schemas/calea-house
rm -rf openspec/schemas/calea-house/.git
cp openspec/schemas/calea-house/config.yaml.example openspec/config.yaml
# then edit openspec/config.yaml: fill in `context`, and the `rules.specs`
# lines that name this project's concrete acceptance-artifact convention.
```

Or, once a project already has `openspec init` run: set `schema:
calea-house` in `openspec/config.yaml` after copying the bundle in.

## What's core vs. client-engagement

Every artifact is present in one schema — there's no separate "profile" to
select. Client-only artifacts (`parties`, `calendar`, `sign_off`,
`deliverables`) carry an explicit "skip this on internal work" instruction,
the same pattern OpenSpec's own native `design.md` already uses for its own
conditional inclusion. Delete the unused template files from a project's copy
if you'd rather they not appear as options at all.

| Artifact | Always relevant | Instruction |
|---|---|---|
| `proposal` | yes | native OpenSpec, unchanged |
| `decisions` | yes | single `<PREFIX>-n` namespace (`D` by default; a project keeps the prefix its history uses), state field (`open`/`follow-up`/`resolved`/`deferred`), optional label and provenance, `blocks` links to requirements, free-text record after the fields |
| `specs` | yes | native OpenSpec + stable `FAMILY-n` requirement IDs, mandatory `Kind` (work-item / acceptance-standard / commercial / informative), `## Retired Requirements` with pointers, Given/When/Then scenarios |
| `design` | yes | native OpenSpec, unchanged |
| `tasks` | yes | native OpenSpec, unchanged |
| `parties` | client-engagement only | skip on internal work |
| `calendar` | client-engagement only | skip on internal work |
| `sign_off` | client-engagement only | skip on internal work |
| `deliverables` | client-engagement only | skip on internal work |

"Skip on internal work" is prose guidance for whoever's writing the artifacts.
`config.yaml`'s `engagement: internal | client` field is the machine-checked
counterpart — a validator can warn if `engagement: internal` but
`parties.md`/`calendar.md`/`sign-off.md`/`deliverables.md` are present and
non-empty anyway. Keep both in sync; see `config.yaml.example`.

## The one hard rule

Requirement and decision IDs are stable for the life of the project. Never
reassigned, even after retirement or resolution. A spec may split into
multiple files by family as it grows — splitting must never change an ID.

## Not everything with an ID is a work item

A requirement's `**Kind:**` field (`work-item` / `acceptance-standard` /
`commercial` / `informative`) is mandatory — no default, never guessed. A
family can mix all four: an ordinary testable requirement, a quality gate
other work is measured against (never itself closeable), contractual/process
scope with no engineering content, and a statement kept for reference because
others cite it (a boundary, a rejected alternative, a platform fact). Only
`work-item` gets projected to a tracker — with its Scenario as the definition
of done and the acceptance standards as its gates; the other three are
reported as skipped, with the Kind as the reason, whenever a bridge run would
otherwise have to decide silently. See `schema.yaml`'s `specs` instruction for
the exact field shape.

## Client artifacts are per change

`parties`, `calendar`, `sign_off` and `deliverables` are generated per change,
like every OpenSpec artifact. A project-level calendar or sign-off table (the
kind a client document carries once) lives in the project's own prose for now;
folding those into a project-level artifact is a later schema round.

## Known limitation

`openspec archive` does not auto-merge a `decisions.md` delta into a
persistent register the way it does for `specs` — that merge logic is
hardwired to the `specs` artifact specifically. This schema's convention is a
project-root `openspec/decisions.md` persistent register, updated by hand
(or by an agent following the `operations.archive.guidance` entry in
`config.yaml.example`) after each archive. See the `decisions` artifact's own
instruction in `schema.yaml` for the exact format.

## Acceptance criteria are deliberately abstract

`specs`' Given/When/Then scenario format doesn't mandate a concrete
test-artifact. Say what does in your project's `config.yaml` under
`rules.specs` — a BTT tree + Foundry `Scenario` comment for a Web3 project,
a pytest scenario for anything else. See `config.yaml.example` for both
worked examples.
