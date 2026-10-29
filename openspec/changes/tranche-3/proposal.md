# Proposal

## Why

Tranche 3 builds `BearDrop`: holders' $MNTD, claimed per bear on Robinhood Chain. MINT asked for it on
29 October 2026 (change `dst-bear-drop`). The specification is DST-1 to DST-6 with OPS-2 and DEL-6.
MINT settled CQ-25 to CQ-28 on 29 October: 500 $MNTD per bear, rounds left open, a 90-day window and
no external review. The contract is live by 15 November.

## What Changes

- `BearDrop` is new: rounds and per-bear amounts, the owner-only claim, reads for an id checker,
  leftovers and withdrawal, ownership and pause, with a tree and deterministic tests.
- `script/BearDropList.s.sol` loads and checks MINT's list. `Deploy.s.sol` gains `runBearDrop`.
- The client gains a `drop` module.

## Capabilities

### Modified Capabilities

None at the specification level. This change implements requirements that already stand in
`openspec/specs/` (`skip_specs: true`).

## Impact

`packages/contracts` and `packages/contracts-client` in mintdotio/NFT, on `mnt/DST-n` branches off
`feat/contracts`.
