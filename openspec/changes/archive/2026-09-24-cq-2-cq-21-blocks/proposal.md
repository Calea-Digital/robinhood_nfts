# Proposal

## Why

The board's read-back (check 3) refuses an open decision whose every blocked requirement is Done.
After the tranche-1 review closed ACT-7 (MNT-32) and ACT-9 (MNT-34), CQ-2 and CQ-21 each gate
only finished work — yet neither holds up the code: CQ-2 holds up deploying `Activation` and the
burn rehearsal, CQ-21 holds up MINT's off-chain Status and the portal's link prompts. The
reviewer agreed on 2026-09-24 to name what each actually gates.

## What Changes

- CQ-2 **Blocks**: `ACT-7` → `ACT-7, OPS-2, OPS-4`.
- CQ-21 **Blocks**: `ACT-9` → `ACT-9, DEL-6`.
- No requirement changes; no decision changes state.

## Capabilities

None — register fields only (`skip_specs: true`).

## Impact

- `openspec/decisions.md` (two `Blocks` lines, folded by hand at archive); `docs/OPEN-QUESTIONS.md`
  re-rendered if it shows the field.
- Board: gating links from MNT-73 (CQ-2) to MNT-62 and MNT-64, and from MNT-119 (CQ-21) to DEL-6's
  Task, through `board.sh`; check 3 then passes.
