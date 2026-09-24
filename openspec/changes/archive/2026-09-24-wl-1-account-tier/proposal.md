# Proposal

## Why

WL-3 now binds a voucher's `allocationIndex` to the getminted.io account (change
`wl-3-account-allocation`, 2026-09-24): the wagering tier is the account's, and the wallet is only
where the allocation lands. WL-1 still says "a wallet at $100 holds two" and "reaching a threshold
makes a wallet eligible", which reads against WL-3 and is the reading that led to MNT-22's
finding M-1. The tranche-1 review (MNT-20, finding I-1) asked for the wording to follow; the
reviewer agreed on 2026-09-24.

## What Changes

- WL-1's statement: thresholds make an **account** eligible for the allocation they unlock; the
  claim puts it in the wallet the holder selects; an account at $100 holds two of the 1,000.
- No behaviour change; the Scenario and Kind (`work-item`) are unchanged.

## Capabilities

### Modified Capabilities

- `whitelist` (prefix `WL`): WL-1 — who reaches a threshold.

## Impact

- No code or test change. `test/WhitelistClaim.tree.md`'s WL-1 note points at the leaves that pin
  the account's tier order.
- `docs/SPECIFICATION.md` (generated block) and the MNT WL-1 Task body follow on render and
  `board.sh`.
