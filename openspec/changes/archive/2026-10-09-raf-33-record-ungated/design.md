# Design

## Context

A requirement is gated in two ways:
- **by its own text:** a `→ CQ-n` pointer, which the bridge's `parser_openspec.py` `POINTER`
  reads;
- **by a decision's `Blocks:` list.**

The bridge turns each gate into a "depends on" link on the board, and `/mnt:next` treats a link
to an Open decision as a hard gate. A plain mention such as "(CQ-22)" is not a gate.

Today RAF-33 is gated twice: by `→ CQ-22` in its statement and by CQ-22's `Blocks: RAF-33`.

The bridge removes a gating link in only one case: when the decision leaves the open states
(`bridge.py`, "W6 step 3"). CQ-22 stays open here, so the link from MNT-139 (CQ-22) to MNT-137
(RAF-33) would survive the archive. MNT-137 would still look hard-gated, and the validator would
see a link the spec no longer asks for. This session's YouTrack tools can add links but not
remove them.

## Goals / Non-Goals

**Goals:**
- RAF-33 is claimable now.
- The CQ-22 gate stays on what the answer actually shapes.
- The board matches the spec, with no hand-made exception.

**Non-Goals:**
- Answering CQ-22, or changing its default.
- Changing `recordPayout`'s shape.
- Building RAF-33 (the work loop does that).
- Changing RAF-14's CQ-23 gate.

## Decisions

1. **Move the gate to RAF-18, not to DEL-6 or OPS-5.**
   - The delivery method appears in RAF-18 step 6: who sends, and a request window if MINT
     chooses (b).
   - RAF-18 is already gated by CQ-23, so the move blocks nothing that is free today.
   - DEL-6 was considered: under (b) the page would need a prize-request screen. Gating DEL-6
     would block line 3.5, the client's mystery-box calls, which don't depend on CQ-22. The page
     work under (b) is MINT's anyway (RAF-18's page paragraph).
2. **RAF-33 keeps a plain mention, "(CQ-22)".** The reader still finds the decision, but it is
   not a gate.
3. **Remove the stale link through the bridge, not by hand.**
   - The fix belongs in the ai-stack bridge: when an open decision's `Blocks` (or a
     requirement's pointer) no longer names a target, remove the bridge-made gating link, record
     it in the manifest for `--rollback`, and report it as `UNLINKED`. This mirrors the existing
     W6 removal.
   - It also clears the leftover links from IC-16 where their decisions are open.
   - **Alternative:** the person deletes the MNT-139 → MNT-137 link in YouTrack by hand. That is
     quicker, but the board then holds a hand edit in a bridge-owned area, and the next stale
     link meets the same gap.

## Risks / Trade-offs

- **RAF-33 is built before MINT answers.** If MINT later wants something the record can't carry
  (for example a payout of several transfers), RAF-33 is amended. The record takes one
  `(chainId, txHash)` per win, which fits both (a) and (b).
- **The bridge fix touches shared tooling.** It is tested in ai-stack against the MNT manifests
  and run `--dry` first, then `--check-existing`, before any write.

## Migration Plan

1. Lint, archive, and fold the decisions delta into `openspec/decisions.md`.
2. Render, and commit.
3. Bridge fix in ai-stack.
4. `board.sh --dry`: expect MNT-137 and MNT-59 refreshed, one UNLINKED, one link added.
5. `board.sh`, then the read-back.

**Rollback:** the bridge manifest's `--rollback`, and a revert of the archive commit.

## Open Questions

None.
