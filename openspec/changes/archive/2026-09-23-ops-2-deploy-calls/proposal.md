# Proposal

## Why

OPS-2's Scenario says only `setCrediter` and `setSigner` are called after construction, but the
order OPS-2 itself lists calls `setMaxSupply`, `setTransferValidator`, `setPaused(true)` and the
ownership transfers after construction, and `setSigner` is never needed at deploy — the first
signer is a constructor argument. `WhitelistClaim` also takes MINT's admin as its constructor
`owner` (reviewer-approved, WL-3), so there is no ownership step after it. The Scenario as
written cannot pass; the reviewer chose on 2026-09-23 to fix the wording before the deploy
script is written.

## What Changes

- OPS-2's statement: the crediter is the one address set after construction; `setSigner` is the
  rotation path, not a deploy step; the other post-construction calls are named as settings and
  hand-overs in the listed order. `WhitelistClaim(owner, signer, openAt, closeAt)` with no
  ownership step.
- OPS-2's Scenario says the same. Nothing else changes; Kind stays `work-item`.

## Capabilities

### Modified Capabilities

- `operations` (prefix `OPS`): OPS-2 — which calls follow construction, and `WhitelistClaim`'s
  constructor.

## Impact

- No contract code change: `WhitelistClaim` already takes `(owner, signer, openAt, closeAt)`.
- `script/Deploy.s.sol` (OPS-2's own Task) is written against the amended wording.
- `docs/SPECIFICATION.md` (generated block) and the MNT OPS-2 Task body follow on render and
  `board.sh`.
