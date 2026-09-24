# Proposal

## Why

The tranche-end `solidity-auditor` passes of the tranche-1 review (2026-09-24) found two statements
the system does not keep as written. WL-4 says the allowlist's per-wallet limit enforces "one or
two", but SeaDrop compares that limit with every bear minted to the wallet in any stage, so a
claimant who minted earlier loses allocations silently (T-1). COL-7 says a sale settles only
through OpenSea or a Payment Processor venue, but at level 0 a holder's own transfers always
pass, so an escrow-mediated sale pays no creator earnings (T-3). The reviewer agreed to state both.

## What Changes

- WL-4: the limit counts every mint to the wallet; the whitelist stage is the first in which any
  wallet but the team's can mint, with no overlapping stage; later stages' limits count whitelist
  mints.
- COL-7: marketplace-operated sales settle only through allowed venues; sales arranged outside a
  marketplace pay no creator earnings, inherent to any level that lets holders move their bears.
- No code change; Kinds and Scenarios unchanged.

## Capabilities

### Modified Capabilities

- `whitelist` (prefix `WL`): WL-4 — stage order.
- `collection` (prefix `COL`): COL-7 — what enforcement covers.

## Impact

- `docs/SPECIFICATION.md` re-rendered; the MNT WL-4 and COL-7 Task bodies refresh through
  `board.sh`. The runbook, rehearsal prompt, NatSpec and `CLAUDE.md` follow in Defect work.
- MINT: the stage order joins CQ-18's items to confirm.
