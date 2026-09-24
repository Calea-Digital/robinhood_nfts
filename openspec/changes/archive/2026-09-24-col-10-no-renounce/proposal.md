# Proposal

## Why

`MintABear` inherits `TwoStepOwnable.renounceOwnership`: one owner call, irreversible, after which
every owner setting is frozen for good — Studio's drop configuration, `baseURI`, royalties,
`maxSupply`, the allowed-SeaDrop list and the transfer-validator lift and restore that OPS-6 relies
on. It also leaves a pending ownership offer standing, so an offer made before renouncing can later
be accepted and revive an owner on a collection believed renounced. The tranche-1 review
(MNT-16, finding L-1) found no reason for the collection ever to be ownerless; the reviewer chose on
2026-09-24 to refuse it in code.

## What Changes

- COL-10's statement: the collection always has an owner; `renounceOwnership` reverts for every
  caller, the owner included.
- COL-10's Scenario gains the clause that `renounceOwnership` reverts. Kind stays `work-item`.
- **BREAKING** for the admin only: the inherited `renounceOwnership` no longer succeeds. No other
  caller could call it before.

## Capabilities

### Modified Capabilities

- `collection` (prefix `COL`): COL-10 — ownership can be handed over but never renounced.

## Impact

- `src/MintABear.sol`: an override of `renounceOwnership` that reverts, with its own error.
- `test/MintABear.t.sol` (`MintABearOwnershipTest`) and `test/MintABear.tree.md`: the refusal, for
  the owner and for anyone else, with a pending offer standing.
- `CLAUDE.md` "Ownership (COL-10)" and `docs/RUNBOOK.md` follow; `docs/SPECIFICATION.md` (generated
  block) and the MNT COL-10 Task body follow on render and `board.sh`.
